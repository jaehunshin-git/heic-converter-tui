"""DMG 오류 진단, 실패 중단과 설치 검증의 정리 경로를 확인합니다."""

import hashlib
import importlib.util
import plistlib
import subprocess
import sys
from pathlib import Path

import pytest


@pytest.fixture
def validator(monkeypatch):
    directory = Path(__file__).resolve().parents[1] / "packaging/macos"
    path = directory / "validate_dmg.py"
    if not path.is_file():
        pytest.skip("sdist에는 macOS 패키징 스크립트가 포함되지 않습니다.")
    monkeypatch.syspath_prepend(str(directory))
    spec = importlib.util.spec_from_file_location("validate_dmg", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def dmg(tmp_path):
    path = tmp_path / "공백 있는 이미지.dmg"
    contents = b"DMG subprocess test fixture"
    path.write_bytes(contents)
    Path(f"{path}.sha256").write_text(
        f"{hashlib.sha256(contents).hexdigest()}  {path.name}\n"
    )
    return path


def test_checksum_mismatch_stops_before_hdiutil(validator, dmg, monkeypatch, capsys):
    dmg.write_bytes(b"changed after checksum creation")
    calls = []
    monkeypatch.setattr(validator.subprocess, "run", lambda *a, **k: calls.append(a))
    with pytest.raises(ValueError, match="SHA-256 불일치"):
        validator.verify_image(dmg)
    assert calls == []
    log = capsys.readouterr().err
    assert "예상 SHA-256:" in log and "실제 SHA-256:" in log


@pytest.mark.parametrize(
    ("stdout", "stderr"),
    [(b"CRC mismatch\n", b"hdiutil: verify failed\n"), (b"", b"\xff")],
)
def test_verify_failure_logs_and_stops_without_retry_or_attach(
    validator, dmg, monkeypatch, capsys, stdout, stderr
):
    calls = []

    def run(command, **kwargs):
        calls.append(command)
        return subprocess.CompletedProcess(command, 1, stdout, stderr)

    monkeypatch.setattr(validator.subprocess, "run", run)
    monkeypatch.setattr(sys, "argv", ["validate_dmg.py", str(dmg)])
    with pytest.raises(subprocess.CalledProcessError) as failure:
        validator.main()
    assert calls == [["hdiutil", "verify", "-verbose", str(dmg)]]
    assert failure.value.returncode == 1
    assert failure.value.stdout == stdout and failure.value.stderr == stderr
    log = capsys.readouterr()
    assert "DMG 명령 종료 코드: 1" in log.err
    assert "hdiutil stdout:" in log.err and "hdiutil stderr:" in log.err
    assert str(dmg) in log.err
    assert "DMG SHA-256, Applications" not in log.out


def test_attach_failure_preserves_diagnostics(validator, monkeypatch, capsys):
    def run(command, **kwargs):
        return subprocess.CompletedProcess(command, 16, b"", b"Resource busy\n")

    monkeypatch.setattr(validator.subprocess, "run", run)
    with pytest.raises(subprocess.CalledProcessError) as failure:
        validator.run_hdiutil("attach", "-plist", "image.dmg")
    assert failure.value.returncode == 16
    assert "Resource busy" in capsys.readouterr().err


@pytest.mark.parametrize("installed_failure", [False, True])
def test_installation_parses_plist_runs_checks_and_detaches(
    validator, dmg, monkeypatch, capsys, installed_failure
):
    calls, checks = [], []

    def run(command, **kwargs):
        calls.append(command)
        if command[:2] == ["hdiutil", "attach"]:
            mount = Path(command[command.index("-mountpoint") + 1])
            mount.mkdir()
            (mount / "HEIC Converter.app").mkdir()
            (mount / "Applications").symlink_to("/Applications")
            contents = plistlib.dumps(
                {
                    "system-entities": [
                        {"dev-entry": "/dev/disk42", "mount-point": str(mount)}
                    ]
                }
            )
            return subprocess.CompletedProcess(command, 0, contents, b"attach notice\n")
        if command[0] == "ditto":
            Path(command[2]).mkdir()
        return subprocess.CompletedProcess(command, 0, b"verified\n", b"")

    def validate(app):
        checks.append("app")
        assert app.is_dir()
        if installed_failure:
            raise ValueError("installed app invalid")

    monkeypatch.setattr(validator.subprocess, "run", run)
    monkeypatch.setattr(validator, "validate", validate)
    monkeypatch.setattr(validator, "smoke", lambda worker: checks.append("worker"))
    monkeypatch.setattr(sys, "argv", ["validate_dmg.py", str(dmg)])
    if installed_failure:
        with pytest.raises(ValueError, match="installed app invalid"):
            validator.main()
        assert checks == ["app"]
    else:
        validator.main()
        assert checks == ["app", "worker"]
        app_command = next(command for command in calls if "--smoke-test" in command)
        assert app_command[0].endswith("Contents/MacOS/HEICConverter")
    assert calls[-1] == ["hdiutil", "detach", "/dev/disk42"]
    log = capsys.readouterr()
    assert "attach notice" in log.err
    assert ("DMG SHA-256, Applications" in log.out) is not installed_failure
