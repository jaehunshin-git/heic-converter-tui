"""한국어 명령줄 인터페이스입니다."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import cast

import typer
from rich.console import Console

from .core import (
    ConflictMode,
    MetadataMode,
    OutputFormat,
    choose_destination,
    convert_image,
    discover_heic_files,
    is_relative_to,
    plan_output_path,
)
from .tui import TuiConfig, collect_tui_config

app = typer.Typer(
    add_completion=False,
    help="HEIC 이미지를 JPEG 또는 PNG로 일괄 변환합니다.",
    no_args_is_help=False,
    context_settings={"help_option_names": []},
)
console = Console()
error_console = Console(stderr=True)


def _show_help(context: typer.Context, _: typer.CallbackParam, value: bool) -> None:
    """한국어 설명을 포함한 도움말을 표시합니다."""

    if value:
        typer.echo(context.get_help())
        context.exit()


def _invalid(message: str) -> None:
    """사용자 입력 오류를 표시하고 종료 코드 2로 끝냅니다."""

    error_console.print(f"[red]오류:[/red] {message}")
    raise typer.Exit(code=2)


def _resolve_format(value: str | None) -> OutputFormat:
    """출력 형식을 검증합니다."""

    if value is None:
        _invalid("비대화형 실행에서는 --format jpeg 또는 --format png가 필요합니다.")
    normalized = value.casefold()
    if normalized not in {"jpeg", "png"}:
        _invalid("--format 값은 jpeg 또는 png여야 합니다.")
    return cast(OutputFormat, normalized)


def _terminal_supports_tui() -> bool:
    """입력과 출력이 모두 실제 터미널에 연결되었는지 확인합니다."""

    return sys.stdin.isatty() and sys.stdout.isatty()


def _validate_option_values(
    *,
    jpeg_quality: int,
    png_compression: int,
    metadata: str,
    on_conflict: str,
) -> tuple[str, str]:
    """공통 옵션을 검증하고 정규화된 정책 값을 반환합니다."""

    metadata_value = metadata.casefold()
    conflict_value = on_conflict.casefold()
    if metadata_value not in {"safe", "preserve", "strip"}:
        _invalid("--metadata 값은 safe, preserve, strip 중 하나여야 합니다.")
    if conflict_value not in {"rename", "skip", "overwrite", "error"}:
        _invalid("--on-conflict 값은 rename, skip, overwrite, error 중 하나여야 합니다.")
    if not 1 <= jpeg_quality <= 100:
        _invalid("--jpeg-quality 값은 1에서 100 사이여야 합니다.")
    if not 0 <= png_compression <= 9:
        _invalid("--png-compression 값은 0에서 9 사이여야 합니다.")
    return metadata_value, conflict_value


def _open_tui(
    *,
    input_path: Path,
    output_path: Path,
    output_format: str | None,
    jpeg_quality: int,
    png_compression: int,
    recursive: bool,
    metadata: str,
    on_conflict: str,
) -> TuiConfig:
    """대화형 TUI를 열고 취소 시 종료 코드 130으로 끝냅니다."""

    config = collect_tui_config(
        input_path=input_path,
        output_path=output_path,
        output_format=cast(OutputFormat | None, output_format),
        jpeg_quality=jpeg_quality,
        png_compression=png_compression,
        recursive=recursive,
        metadata=cast(MetadataMode, metadata.casefold()),
        on_conflict=cast(ConflictMode, on_conflict.casefold()),
    )
    if config is None:
        console.print("변환을 취소했습니다.")
        raise typer.Exit(code=130)
    return config


@app.command()
def main(
    input_path: Path = typer.Option(
        Path("./input"), "--input", "-i", help="입력 HEIC 디렉터리"
    ),
    output_path: Path = typer.Option(
        Path("./output"), "--output", "-o", help="출력 디렉터리"
    ),
    output_format: str | None = typer.Option(
        None, "--format", "-f", help="출력 형식: jpeg 또는 png"
    ),
    jpeg_quality: int = typer.Option(
        90, "--jpeg-quality", help="JPEG 품질(1~100)"
    ),
    png_compression: int = typer.Option(
        6, "--png-compression", help="PNG 압축 수준(0~9)"
    ),
    recursive: bool = typer.Option(False, "--recursive", help="하위 디렉터리를 포함"
    ),
    metadata: str = typer.Option(
        "safe", "--metadata", help="메타데이터: safe, preserve, strip"
    ),
    on_conflict: str = typer.Option(
        "rename", "--on-conflict", help="충돌 처리: rename, skip, overwrite, error"
    ),
    help_: bool = typer.Option(
        False,
        "--help",
        "-h",
        is_eager=True,
        callback=_show_help,
        help="도움말을 표시하고 종료합니다.",
    ),
) -> None:
    """입력 경로의 HEIC 파일을 변환합니다."""

    metadata_value, conflict_value = _validate_option_values(
        jpeg_quality=jpeg_quality,
        png_compression=png_compression,
        metadata=metadata,
        on_conflict=on_conflict,
    )
    if output_format is None and _terminal_supports_tui():
        tui_config = _open_tui(
            input_path=input_path,
            output_path=output_path,
            output_format=output_format,
            jpeg_quality=jpeg_quality,
            png_compression=png_compression,
            recursive=recursive,
            metadata=metadata,
            on_conflict=on_conflict,
        )
        input_path = tui_config.input_path
        output_path = tui_config.output_path
        output_format = tui_config.output_format
        jpeg_quality = tui_config.jpeg_quality
        png_compression = tui_config.png_compression
        recursive = tui_config.recursive
        metadata = tui_config.metadata
        on_conflict = tui_config.on_conflict

    output_format = _resolve_format(output_format)
    metadata_value = metadata.casefold()
    conflict_value = on_conflict.casefold()

    source_root = input_path.expanduser().resolve()
    destination_root = output_path.expanduser().resolve()
    if not source_root.exists():
        _invalid(f"입력 경로를 찾을 수 없습니다: {input_path}")
    if not source_root.is_dir():
        _invalid(f"입력 경로는 디렉터리여야 합니다: {input_path}")
    if destination_root.exists() and not destination_root.is_dir():
        _invalid(f"출력 경로는 디렉터리여야 합니다: {output_path}")
    if source_root == destination_root:
        _invalid("출력 디렉터리는 입력 디렉터리와 달라야 합니다.")

    excluded = destination_root if is_relative_to(destination_root, source_root) else None
    files = discover_heic_files(source_root, recursive=recursive, excluded_directory=excluded)
    if not files:
        _invalid(f"입력 디렉터리에서 .heic 파일을 찾지 못했습니다: {input_path}")
    console.print(f"발견한 HEIC 파일: {len(files)}개")

    succeeded = skipped = failed = 0
    reserved: set[Path] = set()
    for source in files:
        proposed = plan_output_path(source, source_root, destination_root, output_format)
        try:
            while True:
                destination = choose_destination(
                    proposed,
                    cast(ConflictMode, conflict_value),
                    reserved=reserved,
                )
                if destination is None:
                    skipped += 1
                    console.print(f"건너뜀: {source}")
                    break
                try:
                    convert_image(
                        source,
                        destination,
                        output_format=output_format,
                        jpeg_quality=jpeg_quality,
                        png_compression=png_compression,
                        metadata=cast(MetadataMode, metadata_value),
                        overwrite=conflict_value == "overwrite",
                    )
                except FileExistsError:
                    # 계획 뒤 다른 프로세스가 파일을 만들었을 때도 덮어쓰지 않는다.
                    if conflict_value == "rename":
                        continue
                    if conflict_value == "skip":
                        skipped += 1
                        console.print(f"건너뜀: {source}")
                        break
                    raise
                succeeded += 1
                console.print(f"변환: {source} → {destination}")
                break
        except Exception as exc:  # noqa: BLE001 - 파일 단위 오류 후에도 계속 처리해야 합니다.
            failed += 1
            error_console.print(f"[red]실패:[/red] {source} — {exc}")

    console.print(f"요약: 성공 {succeeded}개, 건너뜀 {skipped}개, 실패 {failed}개")
    if failed:
        raise typer.Exit(code=1)


def run() -> None:
    """설치형 콘솔 스크립트의 진입점입니다."""

    app()
