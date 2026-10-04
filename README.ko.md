# HEIC Converter

[![PyPI](https://img.shields.io/pypi/v/heic-converter-tui?logo=pypi&logoColor=white)](https://pypi.org/project/heic-converter-tui/)
[![다운로드](https://api.pepy.tech/personalized-badge/heic-converter-tui?period=month&units=none&left_color=grey&right_color=blue&left_text=downloads%2Fmonth)](https://pepy.tech/projects/heic-converter-tui)
[![Python](https://img.shields.io/badge/Python-%E2%89%A53.11-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![라이선스](https://img.shields.io/badge/License-MIT-yellow)](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/LICENSE)
![macOS](https://img.shields.io/badge/Platform-macOS-000000?logo=apple&logoColor=white)
![로컬 처리](https://img.shields.io/badge/Processing-Local%20only-2E8B57)

> 메뉴 막대에서 변환하고, 방향키로 설정하고, 명령어로 자동화하는 HEIC 변환기

`heic-converter-tui`는 디렉터리의 `.heic` 사진을 JPEG 또는 PNG로 변환하는
Python 3.11+ 명령줄 도구입니다. 인수 없이 실행하면 방향키와 Enter로 조작하는
대화형 화면이 열리고, 옵션을 지정하면 스크립트와 자동화 환경에서도 사용할 수
있습니다.

0.3.0에는 **HEIC Converter** 메뉴 막대 앱도 포함됩니다. Apple Silicon,
macOS 15 이상을 지원하며, Python 런타임과 이미지 코덱이 앱에 포함되어
앱 사용자에게 별도 Python 설치가 필요하지 않습니다.

사진은 외부 서비스로 전송되지 않으며 원본 파일도 변경하지 않습니다. 변환 결과는
별도의 출력 디렉터리에 저장됩니다. 패키지는
[PyPI의 heic-converter-tui](https://pypi.org/project/heic-converter-tui/)에서
배포합니다.

## ✨ 주요 기능

| 기능 | 설명 |
| --- | --- |
| 메뉴 막대 앱 | 다른 앱으로 전환해도 고정 드롭 패널을 유지하고, 패널을 숨겨도 변환과 클립보드 감지를 계속합니다. |
| 파일 대기 목록 | HEIC를 드롭한 뒤 지금 변환 또는 대기 목록에 추가를 선택하고 파일별 결과를 확인합니다. 드롭만으로 변환하지 않습니다. |
| Finder 클립보드 | 백그라운드에서 복사한 로컬 파일 URL을 감지하며, 버튼이나 ⌘V로 직접 붙여넣을 수 있습니다. 감지 설정을 기억합니다. |
| 다국어 방향키 TUI | 한국어 또는 English를 먼저 고른 뒤 입력·출력 경로, 형식, 품질, 메타데이터 및 충돌 정책을 순서대로 선택합니다. |
| 자동화용 CLI | 동일한 기능을 명령어 옵션으로 지정해 비대화형 환경에서 실행할 수 있습니다. |
| JPEG·PNG 출력 | JPEG는 품질을, PNG는 압축 수준을 조정할 수 있습니다. |
| HDR 색상 유지 | macOS 15 이상에서 Apple HDR 게인 맵을 16비트 HDR PNG에 반영합니다. |
| 안전한 메타데이터 기본값 | GPS와 XMP를 제거하면서 EXIF 촬영 정보와 ICC 프로파일은 가능한 범위에서 보존합니다. |
| 안정적인 파일 처리 | 임시 파일에 먼저 저장한 뒤 결과를 반영하며, 한 파일이 실패해도 나머지 변환을 계속합니다. |
| 재귀 변환 | `--recursive`를 사용하면 하위 디렉터리를 검색하고 상대 디렉터리 구조를 유지합니다. |
| 충돌 정책 | 자동 이름 변경, 건너뛰기, 덮어쓰기 또는 오류 처리를 선택할 수 있습니다. |

## 🧭 설계 방향

- **로컬 처리:** 사진 파일을 네트워크로 전송하지 않고 사용자 컴퓨터에서 변환합니다.
- **안전한 기본값:** 기본 메타데이터 정책은 위치 정보를 제거하는 `safe`, 기본 충돌
  정책은 기존 파일을 덮어쓰지 않는 `rename`입니다.
- **일관된 결과:** 방향 정보를 실제 픽셀에 적용하고, 메타데이터를 기록하는 경우
  출력 EXIF 방향 값을 정규화합니다.
- **자동화 친화성:** 대화형 화면과 비대화형 명령이 같은 변환 기능과 종료 코드를
  공유합니다.

## 🛠 기술 스택

| 분류 | 기술 |
| --- | --- |
| 실행 환경 | Python 3.11+ |
| macOS 앱 | SwiftUI, AppKit NSPanel, 내장 JSONL worker |
| 명령줄 | Typer, Rich |
| 터미널 UI | Questionary |
| 이미지 처리 | Pillow, pillow-heif, macOS ImageIO(PyObjC) |
| 테스트 및 빌드 | Pytest, Ruff, Hatchling, uv |

## 📁 프로젝트 구조

```text
heic-converter/
├── src/heic_converter/
│   ├── cli.py              # 명령어 옵션, 진행 및 결과 요약
│   ├── core.py             # 파일 검색, 경로 계획, 이미지 변환 및 원자적 저장
│   ├── service.py          # 공통 배치 서비스와 명시적 파일 목록 입력
│   ├── worker.py           # 버전이 있는 JSONL 요청과 이벤트
│   └── tui.py              # 방향키 기반 대화형 설정 화면
├── macos/                  # Swift Package 앱과 테스트
├── packaging/macos/        # 고정 worker 빌드, 서명 및 DMG 검증
├── docs/                   # 한국어 빌드 및 검증 문서
├── tests/                  # CLI, TUI, 이미지 변환 및 파일 처리 테스트
├── pyproject.toml          # 패키지 메타데이터와 의존성
└── uv.lock                 # 재현 가능한 개발 의존성 잠금 파일
```

## 🚀 시작하기

### 독립 실행 macOS 앱

**Apple Silicon arm64, macOS 15 이상**을 지원합니다. Intel 및 Universal2는
첫 지원 범위에 포함하지 않습니다. 릴리스 앱은
[GitHub Releases](https://github.com/jaehunshin-git/heic-converter-tui/releases)에서
DMG와 SHA-256 체크섬으로 배포합니다. 아직 릴리스되지 않은 소스 체크아웃은
[빌드 안내](docs/macos-build-release.md)에 따라 앱을 만들 수 있습니다.

1. 다운로드한 DMG의 SHA-256 체크섬을 확인합니다.
2. DMG를 열고 **HEIC Converter.app**을 **Applications**로 옮깁니다.
3. 앱을 실행하고 메뉴 막대 아이콘을 클릭해 드롭 패널을 엽니다.

첫 버전은 **ad-hoc 서명**을 사용하며 Apple 공증을 받지 않습니다. 최초 실행이
차단되면 앱 실행을 시도한 후 **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이
열기**에서 이 앱의 실행을 허용합니다.
[Apple의 안내](https://support.apple.com/ko-kr/102445)를 참고하세요.
DMG 포장이 Gatekeeper 차단을 없애지는 않습니다.

로컬 `.heic` 파일을 드롭하고 설정을 확인한 다음 **지금 변환** 또는 **대기 목록에
추가**를 선택합니다. 대기 항목은 변환 시작을 눌러야 실행됩니다. Finder에서 복사한
파일과 직접 붙여넣은 파일은 패널을 열거나 변환하지 않고 대기 목록에 추가됩니다.
패널을 닫아도 앱, 감지 및 진행 중인 작업은 유지됩니다. 앱 종료는 패널에서 선택합니다.

기본 저장 위치는 `~/Downloads/HEIC Converter`이며 첫 변환 때 생성합니다.
기본 설정은 JPEG, 품질 90, PNG 압축 6, 메타데이터 `safe`, 충돌 정책 `rename`입니다.
앱은 지정 폴더에 결과를 모으며 CLI는 기존 디렉터리 구조를 보존합니다. 설정과 저장
위치만 기억하고 파일 목록 및 클립보드 이력은 저장하지 않습니다. 완료 항목도 정리하기
전에는 중복 추가하지 않으며 제거하면 다시 입력할 수 있습니다. 취소하면 현재 파일을
마친 뒤 실행하지 않은 파일을 대기 상태로 돌립니다. 변환 중 들어온 파일이나 설정
변경은 이미 예약한 작업에 영향을 주지 않습니다.

확장자는 대소문자를 구분하지 않는 `.heic`로 제한합니다. 폴더, 심볼릭 링크, 읽을 수
없는 파일, `.heif`, 일반 클립보드 이미지 및 Photos 파일 약속은 제외하고 이유를
표시합니다. 클립보드를 0.75초마다 확인하며 시작 및 감지 재개 때 기존 내용은 추가하지
않습니다. 접근이 거부되면 자동 읽기를 중단하고 드롭 또는 직접 붙여넣기를 안내합니다.

### CLI/TUI 요구 사항

- Python 3.11 이상
- macOS 우선 지원
- `uv` 또는 `pipx`

런타임 의존성인 Pillow와 pillow-heif는 설치 명령이 함께 설치합니다.

### 설치

`uv`를 사용하면 다음과 같이 설치합니다.

```bash
uv tool install heic-converter-tui
```

`pipx`를 사용할 수도 있습니다.

```bash
pipx install heic-converter-tui
```

설치된 배포 패키지 이름은 `heic-converter-tui`, 실행 명령은
`heic-converter`입니다. 다음 명령으로 설치를 확인할 수 있습니다.

```bash
heic-converter --help
```

### TUI로 실행

인수 없이 실제 터미널에서 실행합니다.

```bash
heic-converter
```

먼저 `한국어` 또는 `English`를 고릅니다. 이후 질문, 검증 오류, 선택지, 요약과
취소 안내는 선택한 언어로 표시됩니다. 선택 항목은 `↑`/`↓` 방향키로 이동하고
Enter로 확정합니다. 경로는 직접 입력합니다.

```text
HEIC Converter TUI

? 언어 / Language 한국어

HEIC 이미지 변환 설정

? 입력 디렉터리 경로 ./input
? 출력 디렉터리 경로 ./output
? 출력 형식 JPEG
? JPEG 품질 높음 (90)
? 하위 디렉터리도 변환할까요? 아니요 — 현재 디렉터리만
? 메타데이터 처리 안전하게 유지 (권장) — GPS 등 민감 정보는 제거
? 같은 이름의 출력 파일이 있을 때 이름 변경 (권장) — 번호를 붙여 새 파일 생성

설정 요약
  입력 디렉터리: input
  출력 디렉터리: output
  출력 형식: JPEG (JPEG 품질 90)
  하위 디렉터리 포함: 아니요
  메타데이터: safe
  파일 충돌 처리: rename

? 이 설정으로 변환을 시작할까요? 시작
```

`Ctrl+C`를 누르거나 마지막 단계에서 `취소`를 선택하면 변환하지 않고 종료 코드
`130`으로 끝납니다.

### 명령어로 실행

스크립트나 자동화 환경에서는 출력 형식을 명시합니다.

```bash
# input 디렉터리의 HEIC를 JPEG로 변환
heic-converter --input ./input --output ./output --format jpeg

# photos 디렉터리의 HEIC를 PNG로 변환
heic-converter --input ./photos --output ./converted --format png

# 하위 디렉터리까지 검색하고 기존 결과가 있으면 새 이름으로 저장
heic-converter \
  --input ./photos \
  --output ./converted \
  --format jpeg \
  --recursive \
  --on-conflict rename
```

TTY가 아닌 환경에서 `--format`을 생략하면 사용법 오류로 종료합니다.

### 업데이트와 삭제

`uv`로 설치한 패키지는 다음과 같이 관리합니다.

```bash
uv tool upgrade heic-converter-tui
uv tool uninstall heic-converter-tui
```

`pipx`를 사용했다면 다음 명령을 실행합니다.

```bash
pipx upgrade heic-converter-tui
pipx uninstall heic-converter-tui
```

### 소스에서 설치 및 검증

소스 체크아웃을 도구로 직접 설치하려면 저장소 루트에서 다음 중 하나를 실행합니다.

```bash
uv tool install .
```

```bash
pipx install .
```

개발 의존성을 설치한 뒤 테스트, 정적 검사 및 배포 파일을 검증하려면 다음 명령을
사용합니다.

```bash
uv sync --group dev
uv run pytest
uv run ruff check .
uv build
uvx --from twine twine check dist/*
```

## 📚 동작 및 옵션

### 명령 형식

```text
heic-converter --input INPUT --output OUTPUT --format {jpeg,png} [옵션]
```

`--input`과 `--output`은 디렉터리 경로입니다. 기본값은 각각 `./input`과
`./output`입니다. 두 디렉터리에 같은 경로를 지정할 수 없으며 단일 파일 입력은
지원하지 않습니다.

| 옵션 | 설명 | 기본값 |
| --- | --- | --- |
| `-i, --input PATH` | 입력 HEIC 디렉터리 | `./input` |
| `-o, --output PATH` | 출력 디렉터리 | `./output` |
| `-f, --format {jpeg,png}` | 출력 형식 | 비대화형 실행에서 필수 |
| `--jpeg-quality N` | JPEG 품질, 1~100 | `90` |
| `--png-compression N` | PNG 압축 수준, 0~9 | `6` |
| `--recursive` | 하위 디렉터리까지 검색 | 꺼짐 |
| `--metadata {safe,preserve,strip}` | 메타데이터 처리 정책 | `safe` |
| `--on-conflict {rename,skip,overwrite,error}` | 출력 파일 충돌 정책 | `rename` |

JPEG 출력은 `.jpeg`, PNG 출력은 `.png` 확장자를 사용합니다.
TUI에서는 자주 쓰는 품질·압축 사전 설정을 고르며, CLI에서는 위 범위 안의 값을
직접 지정할 수 있습니다.

### 메타데이터와 이미지 처리

| 정책 | 동작 |
| --- | --- |
| `safe` | GPS와 XMP를 제거하고 나머지 EXIF와 ICC 프로파일을 가능한 범위에서 보존합니다. |
| `preserve` | EXIF, XMP, ICC 프로파일을 가능한 범위에서 보존합니다. |
| `strip` | 출력 이미지에서 EXIF와 XMP를 제거합니다. HDR PNG의 색 재현에 필요한 ICC 프로파일은 유지합니다. |

변환 시 이미지 방향을 픽셀에 반영하고, 메타데이터를 저장하는 경우 출력 EXIF 방향
값을 `1`로 정규화합니다. JPEG는 알파 채널을 지원하지 않으므로 투명 영역을 흰색
배경과 합성합니다. PNG는 알파 채널을 유지합니다.

macOS 15 이상에서는 Apple HDR 게인 맵이 포함된 HEIC를 16비트 HDR PNG로
변환합니다. HDR 화면에서 원본의 밝기와 색 표현을 유지하기 위해 PNG에 HDR
색상 프로파일을 기록합니다. 다른 환경에서는 HEIC의 기본 SDR 이미지를 PNG로
저장하므로 HDR 화면에서 원본과 다르게 보일 수 있습니다. JPEG 출력은 SDR입니다.
앱의 파일별 결과에는 HDR 적용 여부와 SDR 처리 사유를 표시합니다. HDR 처리는
원본 게인 맵과 ImageIO API 지원에 따라 달라지며 모든 HEIC의 HDR 보존을 보장하지
않습니다. PNG 압축 설정은 Pillow SDR 경로에 적용하고 네이티브 HDR 인코더는 자체
압축을 사용합니다.

### 파일 검색과 충돌 처리

- 확장자가 `.heic`인 파일만 처리하며 대소문자를 구분하지 않습니다. `.heif`는
  지원하지 않습니다.
- 기본적으로 입력 디렉터리 바로 아래만 검색합니다. `--recursive`를 사용하면 하위
  디렉터리까지 검색하고 상대 디렉터리 구조를 출력에 유지합니다.
- 출력 디렉터리가 입력 디렉터리 안에 있어도 출력 트리는 검색 대상에서 제외합니다.
- `rename`은 `photo.jpeg`, `photo-2.jpeg`, `photo-3.jpeg`처럼 사용 가능한 이름을
  자동으로 선택합니다.
- `skip`은 기존 파일을 유지하고 해당 입력을 건너뜁니다.
- `overwrite`는 기존 출력 파일을 교체합니다.
- `error`는 충돌한 파일을 실패로 기록하고 다음 입력을 계속 처리합니다.
- 완성된 결과만 나타나도록 출력 디렉터리의 임시 파일에 먼저 저장합니다.

### 지원 범위

HEIC의 기본 정지 이미지 한 장만 JPEG 또는 PNG로 변환합니다. 다음 기능은 지원하지
않습니다.

- PDF 또는 HWP/HWPX 변환
- OCR 및 텍스트 추출
- Live Photo의 동영상 처리
- 기본 정지 이미지 이외의 보조 이미지, 시퀀스 또는 동영상 추출
- CLI의 단일 파일 입력(앱은 명시적인 파일 목록을 지원)

### 종료 코드

| 코드 | 의미 |
| --- | --- |
| `0` | 모든 입력을 성공적으로 처리함 |
| `1` | 하나 이상의 파일을 읽거나 변환하거나 저장하는 중 오류가 발생함 |
| `2` | 인수·경로·옵션이 잘못됐거나 변환할 `.heic` 파일이 없음 |
| `130` | 대화형 화면에서 `Ctrl+C`를 누르거나 변환을 취소함 |

## 라이선스

이 프로젝트는 [MIT 라이선스](LICENSE)를 따릅니다. 저작권 표시와 라이선스 전문을
포함하는 조건으로 사용, 복사, 수정, 배포 및 상업적 이용을 허용합니다. 소프트웨어는
어떠한 보증도 없이 제공되며, 자세한 조건은 [LICENSE](LICENSE)를 참고하세요.
