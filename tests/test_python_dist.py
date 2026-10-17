"""Python 배포 파일의 이름·버전·언어·허용 목록을 검증합니다.

검증기를 제외한 sdist에서 실행할 때만 HEIC_CONVERTER_TEST_SDIST=1을 지정한다.
PKG-INFO가 없는 checkout에서는 이 설정으로 누락된 검증기를 숨길 수 없다.
"""

import importlib.util
import io
import os
import sys
import tarfile
import tomllib
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROJECT = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))[
    "project"
]


def load_validator(root):
    path = root / "scripts" / "validate_python_dist.py"
    if (
        not path.is_file()
        and os.environ.get("HEIC_CONVERTER_TEST_SDIST") == "1"
        and (root / "PKG-INFO").is_file()
        and not (root / ".git").exists()
    ):
        pytest.skip("명시적으로 지정한 sdist에는 배포 검증기를 포함하지 않습니다.")
    spec = importlib.util.spec_from_file_location("validate_python_dist", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def validator():
    return load_validator(ROOT)


def package_metadata(
    body, *, project=PROJECT, newline="\n", summary="Local HEIC converter"
):
    return (
        f"Metadata-Version: 2.4{newline}"
        f"Name: {project['name']}{newline}"
        f"Version: {project['version']}{newline}"
        f"Summary: {summary}{newline}"
        f"Description-Content-Type: text/markdown{newline}{newline}{body}"
    ).encode()


def archives(
    directory,
    *,
    project=PROJECT,
    wheel_body=None,
    source_body=None,
    wheel_entries=(),
    source_entries=(),
):
    stem = f"{project['name'].replace('-', '_')}-{project['version']}"
    english = package_metadata("HEIC install instructions", project=project)
    with zipfile.ZipFile(directory / f"{stem}-py3-none-any.whl", "w") as archive:
        archive.writestr(f"{stem}.dist-info/METADATA", wheel_body or english)
        for name in wheel_entries:
            archive.writestr(name, b"fixture")
    with tarfile.open(directory / f"{stem}.tar.gz", "w:gz") as archive:
        for name, body in [
            (f"{stem}/PKG-INFO", source_body or english),
            *[(f"{stem}/{name}", b"fixture") for name in source_entries],
        ]:
            info = tarfile.TarInfo(name)
            info.size = len(body)
            archive.addfile(info, io.BytesIO(body))


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_pypi_readme_passes_english_metadata_validation(validator, newline):
    validator.metadata(
        package_metadata(
            (ROOT / "README.pypi.md").read_text(encoding="utf-8"), newline=newline
        ),
        PROJECT,
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
def test_korean_prose_cannot_hide_in_links_quotes_or_code(validator, body):
    with pytest.raises(AssertionError):
        validator.metadata(package_metadata(body), PROJECT)


def test_quoted_tui_language_is_allowed(validator):
    validator.metadata(
        package_metadata("HEIC install\nChoose `한국어`.\n? Language / 언어 English"),
        PROJECT,
    )


def test_encoded_korean_summary_is_rejected(validator):
    with pytest.raises(AssertionError):
        validator.metadata(
            package_metadata("HEIC install", summary="=?utf-8?b?7ZWc6riA?="),
            PROJECT,
        )


def test_invalid_utf8_is_rejected_without_replacement(validator):
    with pytest.raises(UnicodeDecodeError):
        validator.metadata(package_metadata("HEIC install") + b"\xff", PROJECT)


@pytest.mark.parametrize("bad_archive", ["wheel", "sdist"])
def test_archive_entrypoint_rejects_korean_description(
    validator, tmp_path, monkeypatch, bad_archive
):
    korean = package_metadata("HEIC install\n한국어 설명")
    archives(
        tmp_path, **{"wheel_body" if bad_archive == "wheel" else "source_body": korean}
    )
    monkeypatch.setattr(sys, "argv", ["validate_python_dist.py", str(tmp_path)])
    with pytest.raises(AssertionError):
        validator.main()


@pytest.mark.parametrize(
    "name",
    [
        "README.pypi.md",
        "README.md",
        "README.ko.md",
        "input/photo.heic",
        "output/photo.png",
        "docs/guide.md",
        "scripts/validate_python_dist.py",
        "packaging/macos/build.sh",
        "macos/Package.swift",
        "tests/.DS_Store",
        "../README.pypi.md",
    ],
)
def test_sdist_description_allowlist(validator, tmp_path, name):
    archives(tmp_path, source_entries=[name])
    if name == "README.pypi.md":
        validator.validate(tmp_path, PROJECT)
    else:
        with pytest.raises(AssertionError):
            validator.validate(tmp_path, PROJECT)


@pytest.mark.parametrize(
    "name",
    [
        "input/photo.heic",
        "output/photo.png",
        "docs/guide.md",
        "scripts/validate_python_dist.py",
        "packaging/macos/build.sh",
        "macos/Package.swift",
        "heic_converter/.DS_Store",
        "unrelated-1.0.dist-info/METADATA",
        "heic_converter/../photo.heic",
        "/heic_converter/photo.heic",
    ],
)
def test_wheel_allowlist(validator, tmp_path, name):
    archives(tmp_path, wheel_entries=[name])
    with pytest.raises(AssertionError):
        validator.validate(tmp_path, PROJECT)


def test_entrypoint_reads_name_and_future_version_from_pyproject(
    validator, tmp_path, monkeypatch, capsys
):
    project = {"name": "future-package", "version": "1.2.3"}
    config = tmp_path / "pyproject.toml"
    config.write_text(
        '[project]\nname = "future-package"\nversion = "1.2.3"\n', encoding="utf-8"
    )
    archives(
        tmp_path,
        project=project,
        wheel_entries=["heic_converter/__init__.py"],
        source_entries=[
            "src/heic_converter/__init__.py",
            "tests/test_example.py",
            "pyproject.toml",
            "README.pypi.md",
            "LICENSE",
        ],
    )
    monkeypatch.setattr(
        sys,
        "argv",
        ["validate_python_dist.py", str(tmp_path), "--pyproject", str(config)],
    )
    validator.main()
    assert "future-package wheel/sdist 버전 1.2.3" in capsys.readouterr().out


@pytest.mark.parametrize(
    "field,value", [("name", "other-package"), ("version", "9.9.9")]
)
@pytest.mark.parametrize("archive", ["wheel_body", "source_body"])
def test_metadata_must_match_declared_project(
    validator, tmp_path, field, value, archive
):
    changed = {**PROJECT, field: value}
    archives(tmp_path, **{archive: package_metadata("HEIC install", project=changed)})
    with pytest.raises(AssertionError):
        validator.validate(tmp_path, PROJECT)


def test_artifacts_must_match_declared_version(validator, tmp_path):
    archives(tmp_path)
    with pytest.raises(AssertionError):
        validator.validate(tmp_path, {**PROJECT, "version": "9.9.9"})


@pytest.mark.parametrize(
    "sdist_env,has_pkg_info,has_git",
    [
        (False, False, False),
        (False, True, False),
        (True, False, False),
        (True, True, True),
    ],
)
def test_missing_checkout_validator_fails(
    tmp_path, monkeypatch, sdist_env, has_pkg_info, has_git
):
    monkeypatch.setenv("HEIC_CONVERTER_TEST_SDIST", "1" if sdist_env else "0")
    if has_pkg_info:
        (tmp_path / "PKG-INFO").write_text("fixture", encoding="utf-8")
    if has_git:
        (tmp_path / ".git").write_text("gitdir: fixture", encoding="utf-8")
    with pytest.raises(FileNotFoundError):
        load_validator(tmp_path)


def test_missing_validator_skips_only_in_explicit_sdist(tmp_path, monkeypatch):
    monkeypatch.setenv("HEIC_CONVERTER_TEST_SDIST", "1")
    (tmp_path / "PKG-INFO").write_text("fixture", encoding="utf-8")
    with pytest.raises(pytest.skip.Exception, match="sdist"):
        load_validator(tmp_path)
