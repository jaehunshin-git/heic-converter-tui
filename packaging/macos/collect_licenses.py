"""번들에 포함되는 Python 런타임과 의존성의 라이선스 고지 수집입니다."""

import importlib.metadata
import sys
from pathlib import Path

RUNTIME_DISTRIBUTIONS = (
    "Pillow",
    "pillow-heif",
    "pyobjc-core",
    "pyobjc-framework-Cocoa",
    "pyobjc-framework-Quartz",
    "pyinstaller",
    "altgraph",
    "macholib",
)


def main() -> None:
    destination = Path(sys.argv[1])
    notices = ["HEIC Converter 내장 런타임 및 제3자 라이선스 고지\n"]
    for name in RUNTIME_DISTRIBUTIONS:
        package = importlib.metadata.distribution(name)
        notices.append(f"{package.metadata['Name']} {package.version}\n")
        files = package.files or []
        matches = [
            item
            for item in files
            if any(
                token in item.name.lower() for token in ("license", "copying", "notice")
            )
        ]
        for index, item in enumerate(matches):
            source = Path(package.locate_file(item))
            if source.is_file():
                target = destination / f"{name}-{index}-{source.name}"
                target.write_bytes(source.read_bytes())
    # Python 독립 배포에는 PSF 고지 및 함께 배포된 라이브러리 고지가 포함된다.
    runtime = (
        Path(sys.base_prefix)
        / f"lib/python{sys.version_info.major}.{sys.version_info.minor}"
    )
    for name in ("LICENSE.txt", "LICENSE", "PYTHON.json"):
        source = runtime / name
        if source.is_file() and name != "PYTHON.json":
            (destination / f"Python-{name}").write_bytes(source.read_bytes())
    if not any(destination.glob("Python-LICENSE*")):
        raise RuntimeError("고정 Python 런타임의 라이선스 파일을 찾을 수 없습니다.")
    (destination / "THIRD-PARTY-NOTICES.txt").write_text("\n".join(notices))


if __name__ == "__main__":
    main()
