"""배포 메타데이터 언어와 고정 wheel의 코덱 소스 고지를 검증합니다."""

import importlib.util
import io
import sys
import tarfile
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def load_script(name):
    path = ROOT / "packaging" / "macos" / f"{name}.py"
    if not path.is_file():
        pytest.skip(
            "sdist에는 macOS 앱 빌드 스크립트가 포함되지 않습니다.",
            allow_module_level=True,
        )
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load_script("validate_python_dist")
licenses = load_script("collect_licenses")


def package_metadata(body, *, newline="\n", summary="Local HEIC converter"):
    return (
        f"Metadata-Version: 2.4{newline}"
        f"Version: 0.3.0{newline}"
        f"Summary: {summary}{newline}"
        f"Description-Content-Type: text/markdown{newline}{newline}{body}"
    ).encode()


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_current_english_readme_passes_with_exact_ui_quotes(newline):
    validator.metadata(
        package_metadata((ROOT / "README.md").read_text(), newline=newline)
    )


@pytest.mark.parametrize(
    "body",
    [
        "HEIC install\n한국어로 작성한 설명입니다.",
        "HEIC install\n[README.ko.md](README.ko.md) 한국어 설명",
        "HEIC install\n```text\n한국어 설명\n```",
        "HEIC install\nChoose `한국어` 먼저 선택하세요.",
        "HEIC install\n“클립보드 감지 켜짐” 한국어 설명",
        "HEIC install\n? Language / 언어 English 추가 설명",
        "HEIC install\n한글",
        "HEIC install\nㅎㅏㄴㄱㅡㄹ",
    ],
)
def test_korean_prose_cannot_hide_in_links_quotes_or_code(body):
    with pytest.raises(AssertionError):
        validator.metadata(package_metadata(body))


def test_encoded_korean_summary_is_rejected():
    with pytest.raises(AssertionError):
        validator.metadata(
            package_metadata("HEIC install", summary="=?utf-8?b?7ZWc6riA?=")
        )


def test_invalid_utf8_is_rejected_without_replacement():
    with pytest.raises(UnicodeDecodeError):
        validator.metadata(package_metadata("HEIC install") + b"\xff")


@pytest.mark.parametrize("bad_archive", ["wheel", "sdist"])
def test_archive_entrypoint_rejects_korean_description(
    tmp_path, monkeypatch, bad_archive
):
    english = package_metadata("HEIC install instructions")
    korean = package_metadata("HEIC install\n한국어 설명")
    wheel = tmp_path / "heic_converter_tui-0.3.0-py3-none-any.whl"
    with zipfile.ZipFile(wheel, "w") as archive:
        archive.writestr(
            "heic_converter_tui-0.3.0.dist-info/METADATA",
            korean if bad_archive == "wheel" else english,
        )
    with tarfile.open(tmp_path / "heic_converter_tui-0.3.0.tar.gz", "w:gz") as archive:
        contents = korean if bad_archive == "sdist" else english
        info = tarfile.TarInfo("heic_converter_tui-0.3.0/PKG-INFO")
        info.size = len(contents)
        archive.addfile(info, io.BytesIO(contents))
    monkeypatch.setattr(sys, "argv", ["validate_python_dist.py", str(tmp_path)])
    with pytest.raises(AssertionError):
        validator.main()


CODEC_INFO = {
    "libheif": "1.20.2",
    "HEIF": "x265 HEVC encoder (4.1+1-1d117be)",
    "AVIF": "",
    "encoders": {"x265": "x265 HEVC encoder (4.1+1-1d117be)", "mask": "mask"},
    "decoders": {"libde265": "libde265 HEVC decoder, version 1.0.16"},
}


def upstream_notice():
    return "\n".join(
        ["License for binary wheels: GPLv2."]
        + [
            f"Name: {name}\nLicense: {'GPLv2' if name == 'x265' else 'LGPLv3'}\n"
            f"  For details, see {previous}/COPYING\n  Source code: {previous}\n"
            for name, _, _, previous in licenses.CODEC_SOURCES
        ]
        + ["Name: libaom\nLicense: BSD 3-Clause\nSource code: obsolete\n"]
    )


def test_notice_points_to_actual_codec_sources_and_preserves_license_terms():
    result = licenses.corrected_bundled_notice(upstream_notice(), "1.1.1", CODEC_INFO)
    for name, version, source, previous in licenses.CODEC_SOURCES:
        assert f"Name: {name}\nVersion: {version}\n" in result
        assert f"Source code: {source}\n" in result
        assert f"For details, see {source}/COPYING\n" in result
        assert previous not in result
    assert result.count("License: LGPLv3") == 2
    assert "License: GPLv2" in result
    assert "Name: libaom" not in result


@pytest.mark.parametrize("codec", ["libheif", "HEIF", "decoders", "AVIF", "encoders"])
def test_changed_codec_build_requires_notice_review(codec):
    changed = {**CODEC_INFO, codec: "unexpected"}
    with pytest.raises(RuntimeError, match="대조"):
        licenses.corrected_bundled_notice(upstream_notice(), "1.1.1", changed)


def test_changed_wheel_version_requires_notice_review():
    with pytest.raises(RuntimeError, match="대조"):
        licenses.corrected_bundled_notice(upstream_notice(), "1.2.0", CODEC_INFO)


def test_changed_upstream_notice_fails_instead_of_shipping_old_links():
    with pytest.raises(RuntimeError, match="형식"):
        licenses.corrected_bundled_notice(
            upstream_notice().replace("v1.18.1", "v1.19.0"), "1.1.1", CODEC_INFO
        )


@pytest.mark.parametrize("name", ["README.md", "README.ko.md"])
def test_build_instructions_use_absolute_url_for_excluded_sdist_docs(name):
    readme = (ROOT / name).read_text()
    assert "](docs/macos-build-release.md)" not in readme
    assert (
        "https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-build-release.md"
        in readme
    )
