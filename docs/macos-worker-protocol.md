# 내장 worker 프로토콜

앱은 번들 `Contents/Resources/worker` 아래의 실행 파일을 `Process`로 실행한다.
사용자의 셸, Python 설치, Homebrew 또는 작업 디렉터리를 사용하지 않는다.
개발 시에는 `python -m heic_converter.worker`로 같은 인터페이스를 확인할 수 있다.

표준 입력과 출력은 UTF-8 JSONL이며 한 줄에 객체 하나를 전달한다. stdout에는
프로토콜 이벤트만 출력하고 진단은 stderr로 보낸다. 파일명에 포함된 공백, 한글 및
개행은 JSON 문자열로 인코딩한다. 경로는 절대 경로를 사용한다.

## 요청

모든 요청에 `protocol_version: 1`, 비어 있지 않은 `job_id`, `command`를 포함한다.

```json
{"protocol_version":1,"job_id":"job-1","command":"prepare","files":["/tmp/사진 1.heic"],"output_directory":"/tmp/변환 결과","options":{"output_format":"jpeg","jpeg_quality":90,"png_compression":6,"metadata":"safe","on_conflict":"rename"}}
{"protocol_version":1,"job_id":"job-1","command":"run"}
```

`prepare`는 옵션과 입력을 검증하고 작업 내용을 고정한다. `prepared`를 확인한 뒤
같은 ID로 `run`을 전송한다. `cancel`도 같은 작업 ID로 전송한다. 취소는 현재
파일의 변환과 저장을 완료한 뒤 다음 파일 전에 적용한다.

저장 폴더가 일반 파일로 교체된 오류는 `output_unavailable`로 처리한다. 이름 변경
재시도는 결과 파일의 원자적 커밋에서 발생한 실제 충돌에만 적용하며, 변환 실패 시
미완성 출력의 이름 예약을 해제한다. 따라서 손상된 입력 다음의 같은 이름 정상
입력은 아직 결과 파일이 없으면 원래 이름으로 저장할 수 있다.

| 옵션 | 범위 | 기본값 |
| --- | --- | --- |
| `output_format` | `jpeg`, `png` | `jpeg` |
| `jpeg_quality` | 정수 1~100 | 90 |
| `png_compression` | 정수 0~9 | 6 |
| `metadata` | `safe`, `preserve`, `strip` | `safe` |
| `on_conflict` | `rename`, `skip`, `overwrite`, `error` | `rename` |

## 이벤트

각 이벤트는 `protocol_version`, `job_id`, `event`를 포함한다. 앱은 버전과 ID가
맞는지 확인한 뒤 상태를 갱신한다. 버전 불일치, 손상된 응답, 실행 파일 부재 또는
완료 이벤트 없는 worker 종료는 사용자에게 오류로 표시한다.

| 이벤트 | 주요 필드와 의미 |
| --- | --- |
| `prepared` | `files`, `rejected`의 `source`/`reason`, `total`: 실행 가능한 입력과 제외 이유 |
| `file_started` | `source`, `index`, `total`: 파일 처리 시작, index는 1부터 시작 |
| `file_succeeded` | `source`, `destination`, `hdr_applied`, `sdr_reason`: 저장 완료 |
| `file_skipped` | `source`, `reason`: 충돌 정책에 따른 건너뜀 |
| `file_failed` | `source`, `error`, `error_code`: 파일별 실패, 다음 파일은 계속 처리 |
| `completed` | `succeeded`, `skipped`, `failed`, `total`, `remaining`: 작업 집계 |
| `cancelled` | 완료한 파일의 집계와 실행하지 않은 `remaining` 경로 |
| `error` | `error_code`, `message`: 요청 또는 프로토콜 오류 |

`prepared.total`과 최종 worker 집계는 수락한 입력을 기준으로 한다. 앱은
`prepared.rejected`의 파일을 실패 상태로 표시하고 그 수를 최종 실패 문구에 더한다.
작업 준비의 `invalid_request`와 worker가 정리한 단일 작업 `worker_failed`는 해당
작업만 실패 처리하고 다음 예약을 기존 설정·저장 경로로 실행한다. 프로토콜 오류,
응답 ID 불일치 또는 연결 종료는 worker 세션 장애로 처리한다.

한 번에 하나의 작업만 실행한다. 앱의 예약 작업은 독립적인 입력·설정 스냅샷을
사용한다. 실행 중 새 입력은 별도의 대기 항목으로 남긴다. worker는 원본을 변경하지
않으며 결과를 임시 파일에 완성한 뒤 원자적으로 반영한다.

파일 목록 모드는 지정 저장 폴더에 결과를 모은다. CLI의 디렉터리 모드는 기존 상대
디렉터리 구조를 보존한다. 같은 이름의 여러 원본도 동일한 충돌 정책을 적용한다.

## HDR 결과

`hdr_applied`는 macOS ImageIO의 HDR 경로가 실제 적용되었는지 나타낸다.
`sdr_reason`은 JPEG 출력, 지원하지 않는 OS 또는 API, HDR 게인 맵 부재 등 SDR
처리 사유다. 모든 HEIC의 HDR 보존을 의미하지 않는다. 네이티브 HDR PNG에는
Pillow의 PNG 압축 수준을 강제하지 않는다.

파일 목록과 이벤트를 파일로 영구 기록하지 않는다. 앱은 종료 시 대기 목록을 버리고
설정과 저장 위치만 기억한다. 앱 종료 시 입력 파이프, worker 및 감지 타이머를 정리한다.

표준 입력 EOF를 받으면 실행 중 작업이 완료된 뒤 종료한다. SIGTERM 또는 SIGINT는
현재 파일 저장을 마친 뒤 취소 결과를 보내고 종료한다. 출력 이벤트는 네이티브
라이브러리의 stdout 진단과도 분리하여 JSONL 스트림을 보호한다.
