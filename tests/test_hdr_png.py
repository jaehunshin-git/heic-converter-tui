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


def test_conversion_reports_sdr_reason_for_jpeg_and_missing_gain_map(tmp_path, heic_factory):
    from heic_converter.core import convert_image

    source = heic_factory(tmp_path / "sdr.heic")
    jpeg = convert_image(source, tmp_path / "sdr.jpeg", output_format="jpeg")
    png = convert_image(source, tmp_path / "sdr.png", output_format="png")
    assert not jpeg.hdr_applied and "JPEG" in jpeg.sdr_reason
    assert not png.hdr_applied and "게인 맵" in png.sdr_reason


def test_hdr_branch_reports_application_and_sdr_fallback_conditions(tmp_path, heic_factory, monkeypatch):
    from heic_converter import core

    source = heic_factory(tmp_path / "gain-map.heic")
    original_open = core.Image.open
    orientation = 1
    supported = True
    native_calls = []

    def open_with_gain_map(*args, **kwargs):
        opened = original_open(*args, **kwargs)
        opened.info["aux"] = {core._APPLE_HDR_GAIN_MAP: [1]}
        opened.getexif()[274] = orientation
        return opened

    def save_native(_source, destination, metadata):
        native_calls.append(metadata)
        Image.new("RGB", (2, 2)).save(destination, format="PNG", icc_profile=b"hdr-profile")

    monkeypatch.setattr(core.Image, "open", open_with_gain_map)
    monkeypatch.setattr(core, "_supports_hdr_png", lambda: supported)
    monkeypatch.setattr(core, "_save_hdr_png", save_native)
    hdr = core.convert_image(source, tmp_path / "hdr.png", output_format="png", metadata="strip")
    assert hdr.hdr_applied and hdr.sdr_reason is None
    assert native_calls == [{}]
    with original_open(tmp_path / "hdr.png") as image:
        assert image.info["icc_profile"] == b"hdr-profile"
    orientation = 6
    rotated = core.convert_image(source, tmp_path / "rotated.png", output_format="png")
    assert not rotated.hdr_applied and "방향" in rotated.sdr_reason
    orientation = 1
    supported = False
    unsupported = core.convert_image(source, tmp_path / "unsupported.png", output_format="png")
    assert not unsupported.hdr_applied and "macOS 15" in unsupported.sdr_reason
    assert len(native_calls) == 1
