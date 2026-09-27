"""HDR PNG에 원본 메타데이터 정책을 적용하는 경로를 검증합니다."""

from PIL import Image

from heic_converter.core import _copy_hdr_png_with_metadata


def test_hdr_png_metadata_keeps_profile_and_obeys_policy(tmp_path):
    native = tmp_path / "native.png"
    original_exif = Image.Exif()
    original_exif[306] = "2026:01:02 03:04:05"
    original_exif[34853] = {1: "N", 2: (37, 1)}
    Image.new("RGB", (2, 2), (12, 34, 56)).save(
        native, icc_profile=b"test-profile", exif=original_exif.tobytes()
    )

    safe_exif = Image.Exif()
    safe_exif[306] = "2026:01:02 03:04:05"
    safe = tmp_path / "safe.png"
    _copy_hdr_png_with_metadata(native, safe, {"exif": safe_exif.tobytes()})
    with Image.open(safe) as image:
        assert image.info["icc_profile"] == b"test-profile"
        assert image.getexif().get(306) == "2026:01:02 03:04:05"
        assert not image.getexif().get(34853)
        assert not image.info.get("xmp")
        assert image.getpixel((0, 0)) == (12, 34, 56)

    preserved = tmp_path / "preserved.png"
    _copy_hdr_png_with_metadata(
        native,
        preserved,
        {"exif": original_exif.tobytes(), "xmp": b"<x:xmpmeta />"},
    )
    with Image.open(preserved) as image:
        assert image.getexif().get(34853)
        assert image.info["xmp"] == b"<x:xmpmeta />"

    stripped = tmp_path / "stripped.png"
    _copy_hdr_png_with_metadata(native, stripped, {})
    with Image.open(stripped) as image:
        assert image.info["icc_profile"] == b"test-profile"
        assert not image.getexif()
        assert not image.info.get("xmp")
