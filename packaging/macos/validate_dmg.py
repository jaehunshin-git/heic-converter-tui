"""DMG 체크섬, 허용 목록과 읽기 전용 설치본의 실행을 검증합니다."""

import hashlib
import plistlib
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

from smoke_worker import smoke
from validate_app import validate


def run_hdiutil(*arguments: str) -> subprocess.CompletedProcess:
    """출력을 plist 파싱과 분리해 기록하고, 실패 코드는 그대로 전파합니다."""
    command = ["hdiutil", *arguments]
    print(f"DMG 명령: {shlex.join(command)}", file=sys.stderr, flush=True)
    result = subprocess.run(command, capture_output=True, check=False)
    print(f"DMG 명령 종료 코드: {result.returncode}", file=sys.stderr, flush=True)
    for name, contents in (("stdout", result.stdout), ("stderr", result.stderr)):
        print(
            f"hdiutil {name}:\n{contents.decode('utf-8', errors='replace') or '(출력 없음)'}",
            file=sys.stderr,
            flush=True,
        )
    result.check_returncode()
    return result


def verify_image(dmg: Path) -> None:
    """외부 SHA-256과 이미지 내부 체크섬을 모두 확인합니다."""
    checksum = Path(f"{dmg}.sha256").read_text().split()[0]
    with dmg.open("rb") as source:
        actual = hashlib.file_digest(source, "sha256").hexdigest()
    print(
        f"DMG: {dmg}\n크기: {dmg.stat().st_size} bytes\n"
        f"예상 SHA-256: {checksum}\n실제 SHA-256: {actual}",
        file=sys.stderr,
        flush=True,
    )
    if actual != checksum:
        raise ValueError("DMG SHA-256 불일치: 이미지 내부 검증과 설치를 중단합니다.")
    run_hdiutil("verify", "-verbose", str(dmg))


def main() -> None:
    dmg = Path(sys.argv[1]).resolve()
    verify_image(dmg)
    with tempfile.TemporaryDirectory(prefix="heic-dmg-") as temporary:
        mount = Path(temporary) / "mount"
        result = run_hdiutil(
            "attach",
            "-readonly",
            "-nobrowse",
            "-mountpoint",
            str(mount),
            "-plist",
            str(dmg),
        )
        devices = plistlib.loads(result.stdout)["system-entities"]
        device = next(item["dev-entry"] for item in devices if "mount-point" in item)
        try:
            assert {path.name for path in mount.iterdir()} == {
                "HEIC Converter.app",
                "Applications",
            }
            shortcut = mount / "Applications"
            assert shortcut.is_symlink() and shortcut.readlink() == Path(
                "/Applications"
            )
            # DMG에서 설치한 복사본은 개발 폴더 밖에서도 실행 가능해야 한다.
            installed = Path(temporary) / "HEIC Converter.app"
            subprocess.run(
                ["ditto", str(mount / "HEIC Converter.app"), str(installed)], check=True
            )
            validate(installed)
            smoke(installed / "Contents/Resources/worker/heic-worker")
            subprocess.run(
                [str(installed / "Contents/MacOS/HEICConverter"), "--smoke-test"],
                check=True,
                timeout=30,
                env={"PATH": "/usr/bin:/bin", "HOME": temporary},
            )
        finally:
            run_hdiutil("detach", device)
    print("DMG SHA-256, Applications 링크, 설치 복사본 worker/앱 실행 검증 완료")


if __name__ == "__main__":
    main()
