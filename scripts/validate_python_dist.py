"""wheel/sdist 허용 목록, 버전과 영어 PyPI 메타데이터를 확인합니다."""

import argparse
import email
import re
import tarfile
import tomllib
import zipfile
from email import policy
from pathlib import Path

# 영문 설명에 인용된 실제 UI 문자열만 허용한다. 코드 블록이나 한국어 문서 링크가
# 있다는 이유로 해당 행 전체를 허용하지 않는다. 새 인용은 이 목록과 검사를 함께 검토한다.
UI_QUOTES = ("“클립보드 감지 켜짐”", "“클립보드 감지 꺼짐”", "`한국어`")
TUI_LANGUAGE_PROMPT = "? Language / 언어 English"
HANGUL = re.compile(
    r"[\u1100-\u11ff\u3130-\u318f\ua960-\ua97f\uac00-\ud7af\ud7b0-\ud7ff]"
)


def metadata(contents: bytes, project: dict) -> None:
    # Core Metadata의 본문은 UTF-8이다. bytes 기반 email 파서는 charset이 없는
    # 본문의 한글을 대체 문자로 바꾸므로 원문을 먼저 엄격하게 디코딩한다.
    parts = re.split(r"\r?\n\r?\n", contents.decode("utf-8"), maxsplit=1)
    assert len(parts) == 2, "메타데이터에 본문이 없습니다."
    headers, description = parts
    message = email.message_from_string(headers, policy=policy.default)
    assert (
        re.sub(r"[-_.]+", "-", message["Name"] or "").lower()
        == re.sub(r"[-_.]+", "-", project["name"]).lower()
    ), message["Name"]
    assert message["Version"] == project["version"], message["Version"]
    summary = message["Summary"] or ""
    assert summary and summary.isascii(), summary
    assert "HEIC" in description and "install" in description.lower()
    korean_lines = []
    for line in description.splitlines():
        remaining = "" if line == TUI_LANGUAGE_PROMPT else line
        for quote in UI_QUOTES:
            remaining = remaining.replace(quote, "")
        if HANGUL.search(remaining):
            korean_lines.append(line)
    assert not korean_lines, korean_lines


def validate(directory: Path, project: dict) -> None:
    name = re.sub(r"[-_.]+", "_", project["name"]).lower()
    stem = f"{name}-{project['version']}"
    wheels = list(directory.glob(f"{stem}-*.whl"))
    sources = list(directory.glob(f"{stem}.tar.gz"))
    assert len(wheels) == len(sources) == 1, (
        "해당 이름·버전의 wheel/sdist가 필요합니다."
    )
    forbidden = {
        "input",
        "output",
        ".DS_Store",
        ".git",
        ".venv",
        "macos",
        "packaging",
        "docs",
        "scripts",
    }
    with zipfile.ZipFile(wheels[0]) as wheel:
        for name in wheel.namelist():
            path = Path(name)
            assert not path.is_absolute() and ".." not in path.parts, name
            assert not (set(path.parts) & forbidden), name
            assert path.parts[0] in {"heic_converter", f"{stem}.dist-info"}, name
        metadata(wheel.read(f"{stem}.dist-info/METADATA"), project)
    allowed = {
        "src",
        "tests",
        "pyproject.toml",
        "README.pypi.md",
        "LICENSE",
        "PKG-INFO",
        ".gitignore",
    }
    with tarfile.open(sources[0]) as source:
        for item in source.getmembers():
            path = Path(item.name)
            assert not path.is_absolute() and ".." not in path.parts, item.name
            assert path.parts[0] == stem, item.name
            assert len(path.parts) > 1 and path.parts[1] in allowed, item.name
            assert not (set(path.parts) & forbidden), item.name
        info = source.getmember(f"{stem}/PKG-INFO")
        stream = source.extractfile(info)
        assert stream is not None
        metadata(stream.read(), project)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument(
        "--pyproject",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "pyproject.toml",
    )
    args = parser.parse_args()
    project = tomllib.loads(args.pyproject.read_text(encoding="utf-8"))["project"]
    validate(args.directory, project)
    print(
        f"{project['name']} wheel/sdist 버전 {project['version']}, "
        "허용 목록과 영어 PyPI 설명 검증 완료"
    )


if __name__ == "__main__":
    main()
