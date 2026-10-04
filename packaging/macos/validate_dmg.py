"""DMG 체크섬, 허용 목록과 읽기 전용 설치본의 실행을 검증합니다."""

import hashlib
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

from smoke_worker import smoke
from validate_app import validate


def main() -> None:
    dmg = Path(sys.argv[1]).resolve()
    checksum = Path(f"{dmg}.sha256").read_text().split()[0]
    with dmg.open("rb") as source:
        assert hashlib.file_digest(source, "sha256").hexdigest() == checksum
    subprocess.run(["hdiutil", "verify", "-quiet", str(dmg)], check=True)
    with tempfile.TemporaryDirectory(prefix="heic-dmg-") as temporary:
        mount = Path(temporary) / "mount"
        result = subprocess.run(
            [
                "hdiutil",
                "attach",
                "-readonly",
                "-nobrowse",
                "-mountpoint",
                str(mount),
                "-plist",
                str(dmg),
            ],
            check=True,
            capture_output=True,
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
            subprocess.run(["hdiutil", "detach", "-quiet", device], check=True)
    print("DMG SHA-256, Applications 링크, 설치 복사본 worker/앱 실행 검증 완료")


if __name__ == "__main__":
    main()
