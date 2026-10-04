"""wheel/sdist 허용 목록, 버전과 영어 PyPI 메타데이터를 확인합니다."""

import email
import sys
import tarfile
import zipfile
from pathlib import Path


def metadata(contents: bytes) -> None:
    message = email.message_from_bytes(contents)
    assert message["Version"] == "0.3.0"
    summary = message["Summary"] or ""
    assert summary and summary.isascii(), summary
    description = message.get_payload()
    assert "HEIC" in description and "install" in description.lower()
    # README의 한국어 문서 링크 제목은 허용하지만 본문 설명은 영어여야 한다.
    korean_lines = [
        line
        for line in description.splitlines()
        if any("가" <= character <= "힣" for character in line)
    ]
    assert all(
        "README.ko.md" in line or "한국어" == line.strip() for line in korean_lines
    ), korean_lines


def main() -> None:
    directory = Path(sys.argv[1])
    wheels = list(directory.glob("heic_converter_tui-0.3.0-*.whl"))
    sources = list(directory.glob("heic_converter_tui-0.3.0.tar.gz"))
    assert len(wheels) == len(sources) == 1
    forbidden = {
        "input",
        "output",
        ".DS_Store",
        ".git",
        ".venv",
        "macos",
        "packaging",
        "docs",
    }
    with zipfile.ZipFile(wheels[0]) as wheel:
        for name in wheel.namelist():
            path = Path(name)
            assert not (set(path.parts) & forbidden), name
            assert path.parts[0] == "heic_converter" or path.parts[0].endswith(
                ".dist-info"
            ), name
        metadata(
            wheel.read(
                next(name for name in wheel.namelist() if name.endswith("/METADATA"))
            )
        )
    allowed = {
        "src",
        "tests",
        "pyproject.toml",
        "README.md",
        "README.ko.md",
        "LICENSE",
        "PKG-INFO",
        ".gitignore",
    }
    with tarfile.open(sources[0]) as source:
        for item in source.getmembers():
            path = Path(item.name)
            assert len(path.parts) > 1 and path.parts[1] in allowed, item.name
            assert not (set(path.parts) & forbidden), item.name
        info = next(
            item for item in source.getmembers() if item.name.endswith("/PKG-INFO")
        )
        stream = source.extractfile(info)
        assert stream is not None
        metadata(stream.read())
    print("wheel/sdist 버전 0.3.0, 허용 목록과 영어 PyPI 설명 검증 완료")


if __name__ == "__main__":
    main()
