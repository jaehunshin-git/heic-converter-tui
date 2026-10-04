"""재배포 사진 없이 합성 HEIC로 독립 worker의 JPEG/PNG 변환을 검증합니다."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image
from pillow_heif import from_pillow


def smoke(worker: Path) -> None:
    worker = worker.resolve()
    with tempfile.TemporaryDirectory(prefix="heic 앱 검증 ") as temporary:
        directory = Path(temporary).resolve()
        source = directory / "합성 입력.HEIC"
        from_pillow(Image.new("RGB", (24, 16), "#3868b5")).save(source)
        environment = {
            "PATH": "/usr/bin:/bin",
            "HOME": str(directory),
            "TMPDIR": str(directory),
            "LANG": "en_US.UTF-8",
        }
        for output_format in ("jpeg", "png"):
            destination = directory / output_format
            job = f"packaged-{output_format}"
            requests = [
                {
                    "protocol_version": 1,
                    "job_id": job,
                    "command": "prepare",
                    "files": [str(source)],
                    "output_directory": str(destination),
                    "options": {"output_format": output_format, "metadata": "safe"},
                },
                {"protocol_version": 1, "job_id": job, "command": "run"},
            ]
            result = subprocess.run(
                [str(worker)],
                input="".join(json.dumps(request) + "\n" for request in requests),
                capture_output=True,
                text=True,
                env=environment,
                timeout=60,
            )
            assert result.returncode == 0, result.stderr
            events = [json.loads(line) for line in result.stdout.splitlines()]
            assert any(event.get("event") == "file_succeeded" for event in events), (
                events
            )
            assert any(event.get("event") == "completed" for event in events), events
            assert not any(
                event.get("event") in {"file_failed", "error"} for event in events
            ), events
            image_path = destination / f"합성 입력.{output_format}"
            with Image.open(image_path) as converted:
                assert converted.size == (24, 16)
                assert converted.format == output_format.upper()
            assert all(event.get("protocol_version") == 1 for event in events), events
        assert source.is_file()
    print("사용자 Python 없는 PATH/HOME에서 합성 HEIC JPEG/PNG worker 변환 검증 완료")


if __name__ == "__main__":
    smoke(Path(sys.argv[1]))
