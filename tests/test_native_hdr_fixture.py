"""개인 사진 없이 합성 Apple 게인 맵으로 실제 ImageIO HDR 출력을 검증합니다."""

import io
import sys

import pytest
from PIL import Image, ImageCms

from heic_converter.core import _supports_hdr_png, convert_image

pytestmark = pytest.mark.skipif(
    sys.platform != "darwin" or not _supports_hdr_png(),
    reason="네이티브 HDR 인코더는 macOS 15 이상에서 검증합니다.",
)


@pytest.fixture
def synthetic_hdr_heic(tmp_path):
    import Quartz as quartz
    from Foundation import NSURL

    # SDR 기본 이미지와 8x8 단일 채널 게인 맵 모두 테스트 중 생성합니다.
    base = tmp_path / "기본 이미지.png"
    exif = Image.Exif()
    exif[34853] = {1: "N", 2: (37, 1)}
    profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    Image.new("RGB", (16, 16), (60, 100, 180)).save(
        base, exif=exif.tobytes(), icc_profile=profile
    )
    source = quartz.CGImageSourceCreateWithURL(
        NSURL.fileURLWithPath_(str(base)), None
    )
    path = tmp_path / "합성 HDR 사진.heic"
    destination = quartz.CGImageDestinationCreateWithURL(
        NSURL.fileURLWithPath_(str(path)), "public.heic", 1, None
    )
    assert destination is not None
    quartz.CGImageDestinationAddImageFromSource(destination, source, 0, None)
    metadata = quartz.CGImageMetadataCreateMutable()
    registered, error = quartz.CGImageMetadataRegisterNamespaceForPrefix(
        metadata, "http://ns.apple.com/HDRGainMap/1.0/", "HDRGainMap", None
    )
    assert registered and error is None
    assert quartz.CGImageMetadataSetValueWithPath(
        metadata, None, "HDRGainMap:HDRGainMapVersion", "65536"
    )
    assert quartz.CGImageMetadataSetValueWithPath(
        metadata, None, "HDRGainMap:HDRGainMapHeadroom", "2.0"
    )
    quartz.CGImageDestinationAddAuxiliaryDataInfo(
        destination,
        quartz.kCGImageAuxiliaryDataTypeHDRGainMap,
        {
            quartz.kCGImageAuxiliaryDataInfoData: bytes([128] * 64),
            quartz.kCGImageAuxiliaryDataInfoDataDescription: {
                "Width": 8,
                "Height": 8,
                "BytesPerRow": 8,
                "PixelFormat": 0x4C303038,  # kCVPixelFormatType_OneComponent8
            },
            quartz.kCGImageAuxiliaryDataInfoMetadata: metadata,
        },
    )
    assert quartz.CGImageDestinationFinalize(destination)
    return path


@pytest.mark.parametrize("metadata", ["safe", "preserve", "strip"])
def test_actual_hdr_png_preserves_profile_and_metadata_policy(
    synthetic_hdr_heic, tmp_path, metadata
):
    original = synthetic_hdr_heic.read_bytes()
    output = tmp_path / f"{metadata}.png"
    result = convert_image(
        synthetic_hdr_heic, output, output_format="png", metadata=metadata
    )
    assert result.hdr_applied and result.sdr_reason is None
    assert synthetic_hdr_heic.read_bytes() == original
    assert output.read_bytes()[24] == 16  # IHDR bit depth
    with Image.open(output) as image:
        image.load()
        assert image.size == (16, 16)
        profile = ImageCms.ImageCmsProfile(io.BytesIO(image.info["icc_profile"]))
        assert "PQ" in ImageCms.getProfileDescription(profile)
        assert bool(image.getexif().get(34853)) == (metadata == "preserve")
        if metadata == "strip":
            assert not image.getexif() and not image.info.get("xmp")
    assert not list(tmp_path.glob("*.native.png"))


def test_actual_hdr_source_jpeg_reports_sdr(synthetic_hdr_heic, tmp_path):
    result = convert_image(
        synthetic_hdr_heic, tmp_path / "result.jpeg", output_format="jpeg"
    )
    assert not result.hdr_applied
    assert "JPEG" in result.sdr_reason
