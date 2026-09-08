"""HEIC 파일 탐색, 출력 경로 계획, 변환을 담당하는 순수에 가까운 기능입니다."""

from __future__ import annotations

import ctypes
import errno
import os
import re
import sys
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from PIL import Image, ImageOps, PngImagePlugin
from pillow_heif import register_heif_opener

OutputFormat = Literal["jpeg", "png"]
MetadataMode = Literal["safe", "preserve", "strip"]
ConflictMode = Literal["rename", "skip", "overwrite", "error"]

_NUMBER_PARTS = re.compile(r"(\d+)")
_EXIF_ORIENTATION = 274
_EXIF_GPS_INFO = 34853
_EXIF_XMP = 700
_RENAME_EXCL = 0x00000004
_UNSUPPORTED_ATOMIC_ERRORS = {errno.EINVAL, errno.ENOSYS, errno.ENOTSUP}


@dataclass(frozen=True)
class ConversionResult:
    """파일 하나의 변환 결과입니다."""

    source: Path
    destination: Path


def natural_sort_key(
    path: Path | str,
) -> tuple[tuple[tuple[int, object], ...], str]:
    """숫자가 포함된 이름을 사람이 읽는 순서로 정렬하기 위한 키를 반환합니다."""

    original = unicodedata.normalize("NFC", Path(path).as_posix())
    text = original.casefold()
    parts = tuple(
        (1, int(part)) if part.isdigit() else (0, part)
        for part in _NUMBER_PARTS.split(text)
    )
    # 대소문자를 무시한 키가 같아도 파일 시스템 열거 순서에 의존하지 않게 한다.
    return parts, original


def is_relative_to(path: Path, parent: Path) -> bool:
    """경로가 상위 경로 안에 있는지 확인합니다."""

    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def discover_heic_files(
    input_path: Path,
    *,
    recursive: bool = False,
    excluded_directory: Path | None = None,
) -> list[Path]:
    """입력 디렉터리에서 HEIC 파일을 안정적인 자연 정렬 순서로 찾습니다.

    ``excluded_directory``가 입력 디렉터리 안에 있으면 그 하위 파일은 제외합니다.
    """

    input_path = input_path.resolve()
    excluded = excluded_directory.resolve() if excluded_directory else None

    if not input_path.is_dir():
        return []

    iterator = input_path.rglob("*") if recursive else input_path.glob("*")
    found = [
        item
        for item in iterator
        if item.is_file()
        and not item.is_symlink()
        and item.suffix.casefold() == ".heic"
        and not (excluded and is_relative_to(item.resolve(), excluded))
    ]
    return sorted(found, key=lambda item: natural_sort_key(item.relative_to(input_path)))


def output_suffix(output_format: OutputFormat) -> str:
    """출력 형식에 해당하는 표준 확장자를 반환합니다."""

    return ".jpeg" if output_format == "jpeg" else ".png"


def plan_output_path(
    source: Path,
    input_path: Path,
    output_directory: Path,
    output_format: OutputFormat,
) -> Path:
    """입력 디렉터리 구조를 유지한 기본 출력 경로를 계산합니다."""

    source = source.resolve()
    input_path = input_path.resolve()
    relative = source.relative_to(input_path)
    return output_directory / relative.with_suffix(output_suffix(output_format))


def choose_destination(
    proposed: Path,
    on_conflict: ConflictMode,
    *,
    reserved: set[Path] | None = None,
) -> Path | None:
    """충돌 정책에 따라 저장할 경로를 고릅니다.

    ``None``은 건너뛰기를 뜻하며, ``FileExistsError``는 오류 정책의 충돌입니다.
    """

    reserved = reserved if reserved is not None else set()
    if not proposed.exists() and proposed not in reserved:
        reserved.add(proposed)
        return proposed
    if on_conflict == "skip":
        return None
    if on_conflict == "error":
        raise FileExistsError(f"이미 출력 파일이 있습니다: {proposed}")
    if on_conflict == "overwrite":
        reserved.add(proposed)
        return proposed

    number = 2
    while True:
        candidate = proposed.with_name(f"{proposed.stem}-{number}{proposed.suffix}")
        if not candidate.exists() and candidate not in reserved:
            reserved.add(candidate)
            return candidate
        number += 1


def _metadata_kwargs(image: Image.Image, mode: MetadataMode) -> dict[str, object]:
    """저장에 넘길 허용된 메타데이터만 준비합니다."""

    if mode == "strip":
        return {}

    values: dict[str, object] = {}
    exif = image.getexif()
    # 픽셀 회전이 끝났으므로 기존 Orientation 값은 어떤 모드에서도 보관하지 않습니다.
    exif[_EXIF_ORIENTATION] = 1
    if mode == "safe":
        exif.pop(_EXIF_GPS_INFO, None)
        exif.pop(_EXIF_XMP, None)
    if len(exif):
        values["exif"] = exif.tobytes()

    icc_profile = image.info.get("icc_profile")
    if icc_profile:
        values["icc_profile"] = icc_profile
    if mode == "preserve":
        xmp = image.info.get("xmp") or image.info.get("XML:com.adobe.xmp")
        if xmp:
            values["xmp"] = xmp
    return values


def _prepare_for_output(image: Image.Image, output_format: OutputFormat) -> Image.Image:
    """출력 형식이 요구하는 색상 모드와 알파 처리를 적용합니다."""

    has_alpha = image.mode in {"LA", "PA", "RGBA"} or "transparency" in image.info
    if output_format == "jpeg":
        if has_alpha:
            rgba = image.convert("RGBA")
            background = Image.new("RGB", rgba.size, "white")
            background.paste(rgba, mask=rgba.getchannel("A"))
            return background
        return image.convert("RGB")
    if has_alpha:
        return image.convert("RGBA")
    return image.convert("RGB")


def _fsync_directory(directory: Path) -> None:
    """파일명 변경까지 디스크에 반영되도록 상위 디렉터리를 동기화합니다."""

    descriptor = os.open(directory, os.O_RDONLY)
    try:
        try:
            os.fsync(descriptor)
        except OSError as error:
            if error.errno not in _UNSUPPORTED_ATOMIC_ERRORS:
                raise
    finally:
        os.close(descriptor)


def _try_macos_exclusive_rename(source: str, destination: Path) -> bool:
    """macOS가 지원하면 완성 파일을 덮어쓰기 없이 원자적으로 이동합니다."""

    if sys.platform != "darwin":
        return False
    libc = ctypes.CDLL(None, use_errno=True)
    renamex = libc.renamex_np
    renamex.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    renamex.restype = ctypes.c_int
    result = renamex(os.fsencode(source), os.fsencode(destination), _RENAME_EXCL)
    if result == 0:
        return True
    error_number = ctypes.get_errno()
    if error_number == errno.EEXIST:
        raise FileExistsError(error_number, os.strerror(error_number), destination)
    if error_number in _UNSUPPORTED_ATOMIC_ERRORS:
        return False
    raise OSError(error_number, os.strerror(error_number), destination)


def _commit_without_overwrite(source: str, destination: Path) -> None:
    """지원되는 가장 강한 방식으로 기존 파일을 보존하며 결과를 커밋합니다."""

    if _try_macos_exclusive_rename(source, destination):
        return
    try:
        os.link(source, destination)
    except OSError as error:
        if error.errno not in _UNSUPPORTED_ATOMIC_ERRORS | {errno.EPERM}:
            raise
        # hard link가 없는 exFAT·일부 네트워크 볼륨에서는 목적지를 독점
        # 예약한 직후 완성된 임시 파일로 교체해 비의도 덮어쓰기를 막는다.
        descriptor = os.open(
            destination,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            0o666,
        )
        os.close(descriptor)
        try:
            os.replace(source, destination)
        except BaseException:
            destination.unlink(missing_ok=True)
            raise
    else:
        Path(source).unlink()


def _atomic_save(
    image: Image.Image,
    destination: Path,
    *,
    overwrite: bool,
    **save_kwargs: object,
) -> None:
    """완성된 파일만 목적지에 나타나도록 같은 디렉터리의 임시 파일로 저장합니다."""

    destination.parent.mkdir(parents=True, exist_ok=True)
    temp_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=destination.parent,
            prefix=f".{destination.stem}.",
            suffix=destination.suffix,
            delete=False,
        ) as temporary:
            temp_name = temporary.name
        image.save(temp_name, **save_kwargs)
        with open(temp_name, "rb") as temporary_file:
            os.fsync(temporary_file.fileno())
        if overwrite:
            os.replace(temp_name, destination)
            temp_name = None
        else:
            _commit_without_overwrite(temp_name, destination)
            temp_name = None
        _fsync_directory(destination.parent)
    finally:
        if temp_name:
            Path(temp_name).unlink(missing_ok=True)


def convert_image(
    source: Path,
    destination: Path,
    *,
    output_format: OutputFormat,
    jpeg_quality: int = 90,
    png_compression: int = 6,
    metadata: MetadataMode = "safe",
    overwrite: bool = False,
) -> ConversionResult:
    """HEIC 첫 이미지를 지정 형식으로 변환하고 원자적으로 저장합니다."""

    register_heif_opener()
    with Image.open(source) as opened:
        # pillow-heif는 파일을 열 때 primary image를 현재 프레임으로 선택한다.
        # seek(0)을 호출하면 primary가 아닌 첫 프레임으로 바뀔 수 있다.
        image = ImageOps.exif_transpose(opened)
        # exif_transpose 결과에서 메타데이터를 읽어 EXIF/XMP 방향도 픽셀과 맞춘다.
        metadata_kwargs = _metadata_kwargs(image, metadata)
        converted = _prepare_for_output(image, output_format)
        xmp = metadata_kwargs.pop("xmp", None)
        save_kwargs: dict[str, object] = {
            "format": "JPEG" if output_format == "jpeg" else "PNG",
            **metadata_kwargs,
        }
        if output_format == "jpeg":
            save_kwargs["quality"] = jpeg_quality
            if xmp:
                save_kwargs["xmp"] = xmp
        else:
            save_kwargs["compress_level"] = png_compression
            if xmp:
                xmp_text = xmp.decode("utf-8", errors="replace") if isinstance(xmp, bytes) else str(xmp)
                png_info = PngImagePlugin.PngInfo()
                png_info.add_itxt("XML:com.adobe.xmp", xmp_text)
                save_kwargs["pnginfo"] = png_info
        _atomic_save(converted, destination, overwrite=overwrite, **save_kwargs)
    return ConversionResult(source=source, destination=destination)
