# Python worker JSONL v1 계약

`python -m heic_converter.worker`는 표준 입출력으로 요청과 이벤트를 주고받는다.
개발 환경에서는 `uv run --locked python -m heic_converter.worker`로 실행한다.

## 전송과 요청

UTF-8 JSONL은 줄마다 객체 하나를 전달한다. 파일명의 공백·한글·개행은 JSON으로 인코딩한다.
stdout은 이벤트 전용이다. Python 및 네이티브 라이브러리의 진단은 stderr로
분리하므로 두 스트림을 합치지 않는다. 이벤트는 줄마다 즉시 flush한다.

모든 요청에는 정수 `protocol_version: 1`, 공백만으로 이루어지지 않은 문자열
`job_id`, 문자열 `command`가 필요하다. 버전의 불리언 값은 허용하지 않는다.
클라이언트는 이벤트의 버전과 ID를 확인하고 작업마다 고유 ID를 사용한다.

- `prepare`: `files`는 비어 있지 않은 경로 문자열의 배열이며 빈 배열도 허용한다.
  `output_directory`는 비어 있지 않은 경로 문자열이다. 모든 경로는 절대 경로여야
  하며 상대 경로나 `~`를 작업 디렉터리 기준으로 해석하지 않는다.
  `options`는 생략 가능한 객체이며 알 수 없는 옵션 키는 오류다.
- `run`: `prepared` 확인 후 같은 `job_id`로 실행한다.
- `cancel`: 같은 `job_id`의 준비 또는 실행 중 작업을 취소한다.

한 번에 준비한 작업 하나만 보관하며 실행도 하나씩 처리한다. 실행 전 새
`prepare`가 성공하면 이전 준비 내용을 대체한다. 실행 중 새 준비나 같은 작업의
중복 실행은 `busy`, 실행·취소의 ID가 맞지 않으면 `unknown_job`이다.

## 옵션과 준비 결과

| 옵션 | 허용값 | 기본값 |
| --- | --- | --- |
| `output_format` | `jpeg`, `png` | `jpeg` |
| `jpeg_quality` | 정수 1~100 | 90 |
| `png_compression` | 정수 0~9 | 6 |
| `metadata` | `safe`, `preserve`, `strip` | `safe` |
| `on_conflict` | `rename`, `skip`, `overwrite`, `error` | `rename` |

열거형 문자열은 대소문자를 구분하지 않고 소문자로 정규화한다. 정수 옵션에
문자열·실수·불리언은 허용하지 않는다. 생략한 옵션에는 각각 기본값을 적용한다.
`prepare`는 목록·출력 경로·옵션을 고정하며 내용은 복사하지 않고 실행 시 다시
검사한다. 준비만으로 출력 폴더를 만들지 않는다.

`prepared.files`는 읽을 수 있는 로컬 일반 `.heic` 파일의 실제 절대 경로 목록이다.
확장자 대소문자를 허용하고 실제 경로로 중복을 제거해 자연 정렬한다.
입력 파일 자체의 심볼릭 링크는 제외하되 상위 디렉터리의 별칭은 허용한다.
누락·읽기 권한 부족·비일반 파일·다른 확장자·중복 입력은
`rejected: [{"source": "요청 경로", "reason": "제외 이유"}]`로 보고한다.
손상된 HEIC의 디코딩 실패는 실행 단계에서 발생할 수 있다.
`prepared.total`은 수락한 파일 수다. 모두 제외돼도 `total: 0`으로 준비된다.
`rejected`는 실행의 `failed`나 `total`에 더하지 않는다.
출력 경로가 이미 일반 파일인 경우처럼 작업 준비 자체가 불가능하면
`prepared` 대신 `error`의 `invalid_request`를 보낸다.

## 이벤트와 오류

모든 이벤트에 정수 `protocol_version: 1`, `job_id`, 문자열 `event`가 있다.
문자열 ID를 얻지 못한 오류의 `job_id`는 `null`이다.
`file_*` 이벤트는 공통으로 `source`, 1부터 시작하는 `index`, 수락한 `total`을
포함한다. 경로는 문자열이며, 아래 필드들은 이 공통 필드에 추가된다.

| `event` | 추가 필드와 의미 |
| --- | --- |
| `prepared` | `files`, `rejected`, `total`: 준비 결과 |
| `file_started` | 없음: 해당 입력의 처리 시작 |
| `file_succeeded` | `destination`, `hdr_applied`, `sdr_reason`: 저장 결과 |
| `file_skipped` | `reason`: 충돌 정책에 따른 건너뜀 이유 |
| `file_failed` | `error`, `error_code`: 파일별 실패 메시지와 코드 |
| `completed`, `cancelled` | 아래 집계와 `remaining` |
| `error` | `error_code`, `message`: 요청 또는 작업 수준 오류 |

`succeeded`, `skipped`, `failed`, `total`은 정수 집계이며
`remaining`은 미처리 파일의 절대 경로 문자열 배열이다.
`total = succeeded + skipped + failed + len(remaining)`이며 `completed`의
`remaining`은 빈 배열이다. 파일별 실패 후에도 다음 파일을 계속 처리한다.

요청·작업 수준 `error_code`는 다음과 같다.

- `invalid_request`: JSON 파싱·객체 형식·ID·명령·경로·옵션·준비 검증 오류.
- `protocol_mismatch`: 유효한 ID의 요청에서 버전이 정수 1이 아님.
- `busy`: 실행 중 새 준비 또는 같은 작업의 중복 실행 요청.
- `unknown_job`: 해당 ID의 준비한 작업이 없음.
- `worker_failed`: 배치 처리에서 예상하지 못한 예외. 작업 상태를 해제하고
  `error`를 보내며 해당 실행의 정상 최종 집계는 보장하지 않는다.

파일별 `error_code`는 `input_missing`, `input_permission`, `output_permission`,
`output_unavailable`, `name_conflict`, `invalid_input`, `conversion_failed`다.
각각 입력 소실·입력 권한·출력 권한·출력 경로 불가·이름 충돌·입력 검증·기타 변환
실패다. 출력 폴더가 일반 파일로 바뀌어도 `output_unavailable`이다.
종료 코드만으로 성공을 판단하지 말고 이벤트를 확인한다. 최종 이벤트 없이 연결이
끊기면 클라이언트는 결과를 확인할 수 없는 상태로 다룬다.

## 취소와 종료

실행 중 `cancel`은 현재 파일의 변환·저장 결과까지 보고한 뒤 다음 파일 전에
적용한다. 남은 파일이 있으면 `cancelled`, 이미 전부 처리했다면 `completed`다.
준비 후 실행 전 `cancel`은 세 집계 모두 0, 전체 수락 목록을 `remaining`으로
담은 `cancelled`를 즉시 보내고 준비 상태를 해제한다. 빈 목록이어도 동일하다.
직전 `completed`·`cancelled` 작업 ID의 `cancel`은 응답 없이 무시하며 다음 작업에 영향을 주지
않는다. 더 오래된 ID는 `unknown_job`이고, 같은 ID를 새 준비에 재사용했다면
현재 작업이 취소되므로 ID를 재사용하지 않는 편이 안전하다.

stdin EOF는 취소 요청이 아니다. 실행 중이면 전체 작업 완료를 기다린 뒤 종료하고,
준비만 된 작업은 실행하지 않는다. SIGTERM·SIGINT는 취소를 설정하고 현재 파일
처리를 마친 뒤 남은 파일을 중단한다. 이때도 잔여 파일 유무에 따라 최종 이벤트가
달라지며, 실행 전 준비 상태에서 시그널을 받으면 취소 이벤트 없이 종료한다.

## 저장과 HDR

결과는 지정 출력 폴더 한 곳에 모으며 원본 파일을 수정하거나 삭제하지 않는다.
`rename`은 `이름-2.jpeg`처럼 새 이름을 선택하고 `skip`은 건너뛰며,
`overwrite`는 기존 출력을 교체하고 `error`는 해당 파일을 실패 처리한다.
같은 디렉터리의 임시 파일에 완성한 뒤 원자적으로 결과를 반영하고 임시 파일을
정리한다. 이름 변경 재시도는 실제 목적지 충돌에만 적용한다. 변환에 실패한 입력의
이름 예약은 해제하므로 다음 동일 이름 입력은 아직 비어 있는 원래 이름을 쓸 수 있다.

`hdr_applied`는 불리언으로 macOS ImageIO의 HDR PNG 경로 적용 여부를 나타낸다.
HDR 적용 시 `sdr_reason`은 `null`, SDR 처리 시에는 사유 문자열이다.
HDR PNG는 macOS 15 이상·지원 API·Apple HDR 게인 맵·방향 보정 불필요 등의
조건을 필요로 한다. JPEG는 SDR이며 모든 HEIC의 HDR 보존을 보장하지 않는다.
네이티브 HDR PNG에는 Pillow의 `png_compression` 값을 강제하지 않는다.

## 임시 합성 이미지로 실행 확인

아래는 임시 합성 이미지로 JSONL 요청·이벤트와 EOF를 확인하는 개발 환경 예제다.

```sh
uv run --locked python - <<'PY'
import json, subprocess, sys, tempfile
from pathlib import Path
from PIL import Image
from pillow_heif import register_heif_opener
register_heif_opener()
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory).resolve()
    source = root / "합성 사진.heic"
    Image.new("RGB", (12, 8), (31, 97, 173)).save(source, format="HEIF")
    base = {"protocol_version": 1, "job_id": "example-1"}
    prepare = dict(base, command="prepare", files=[str(source)],
                   output_directory=str(root / "결과"), options={})
    data = "\n".join(map(json.dumps, [prepare, dict(base, command="run")])) + "\n"
    result = subprocess.run([sys.executable, "-m", "heic_converter.worker"],
                            input=data, capture_output=True, text=True, check=True)
    events = [json.loads(line) for line in result.stdout.splitlines()]
    assert [item["event"] for item in events] == [
        "prepared", "file_started", "file_succeeded", "completed"]
    assert events[-1]["succeeded"] == 1 and not events[-1]["remaining"]
    assert source.is_file() and (root / "결과" / "합성 사진.jpeg").is_file()
    print(result.stdout, end="")
PY
```
