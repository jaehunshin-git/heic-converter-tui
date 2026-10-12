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

**HEIC Converter**는 Apple Silicon, macOS 15 이상을 대상으로 하는 독립 메뉴 막대
앱입니다. Python 런타임과 이미지 코덱을 포함하므로 별도 Python 설치가 필요하지 않습니다.
[이슈 #7](https://github.com/jaehunshin-git/heic-converter-tui/issues/7)의 자동 클립보드
변환은 현재 소스에서 구현 중이며 아직 릴리스되지 않았습니다. 아래 설명을 기존
릴리스의 기능으로 해석하지 마세요.

사진은 로컬에서 처리하고 원본 파일은 변경하지 않습니다. CLI/TUI는 별도 출력
디렉터리에 결과를 저장하며 앱은 클립보드용 임시 결과를 준비합니다. CLI/TUI 패키지는
[PyPI](https://pypi.org/project/heic-converter-tui/)에서 배포합니다.

## ✨ 주요 기능

| 기능 | 설명 |
| --- | --- |
| 메뉴 막대 앱(이슈 #7, 미릴리스) | 왼쪽 클릭 패널에는 현재 클립보드 파일의 이름·썸네일·상태만 표시합니다. 오른쪽 클릭은 일시정지·다시 시작, 설정 열기와 앱 종료를 제공합니다. 복사 감지로 패널을 열지 않습니다. |
| 자동 클립보드 변환(구현 중) | 지원하는 HEIC를 JPEG/PNG로 변환한 뒤 기존 ⌘V로 붙여넣습니다. 다른 항목을 보존하고 모든 HEIC 성공 및 현재 클립보드 세대 확인 후에만 게시합니다. |
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

**이슈 #7은 현재 구현 중이며 아직 릴리스되지 않았습니다.** 다음은 소스 변경의
동작 계약이며 기존 DMG의 검증된 기능을 뜻하지 않습니다. 앱은 **Apple Silicon
arm64, macOS 15 이상**을 대상으로 내장 worker 런타임을 사용합니다. 앱/DMG와
PyPI 배포 분리를 진행하며 이번 변경에서는 `pyproject.toml`과 Python 패키지 버전을
0.3.0으로 유지합니다. 기존 배포물은 [GitHub Releases](https://github.com/jaehunshin-git/heic-converter-tui/releases),
소스 빌드는 [빌드 안내](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-build-release.md)를 참고하세요.

왼쪽 클릭 패널에는 현재 클립보드 파일의 이름·썸네일 및 준비/변환 중/완료/실패
상태만 표시합니다. 오른쪽 클릭 메뉴는 자동 변환 일시정지·다시 시작, 설정 열기와
앱 종료를 제공하며 변환 옵션은 별도 설정 창에서 조정합니다. 메뉴 아이콘을 가리키는 돌출부와
화면 경계 배치를 유지합니다. 복사 감지로 패널을 자동으로 열지 않고 과거 이력은 쌓지 않습니다.
다른 앱이나 창으로 포커스를 옮기면 패널이 닫힙니다. 메뉴 아이콘을 클릭하면 다시 열립니다.
메뉴바와 패널은 사진을 담은 클립보드 아이콘을 함께 사용합니다. 패널 높이는 최대 세 행과
하단 안내에 맞추고 더 긴 목록은 스크롤로 표시합니다. 직접 늘린 패널 높이는 유지합니다.
패널이 숨겨져 있으면 메뉴 아이콘 아래의 작은 알림에 복사한 HEIC 개수와 변환 진행·결과를
표시합니다. 알림은 키보드 포커스를 가져오지 않으며 모든 결과가 현재 클립보드에 반영된
뒤에만 완료를 표시합니다. 완료 알림은 4초, 실패 알림은 6초 뒤에 닫힙니다. 알림을 클릭하면
현재 클립보드 패널이 열리고 닫기 버튼으로 알림만 숨길 수 있습니다.
알림 높이는 문구와 진행 막대에 맞춰 자동으로 조절됩니다.

앱에 포커스가 있을 때 `⌘⇧P`로 일시정지·재개, `⌘1`로 현재 클립보드 표시,
`⌘,`로 설정 열기, `⌘W`로 창 닫기, `⌘Q`로 종료할 수 있습니다. `Esc`는 패널만 숨깁니다.
macOS 키보드 탐색 또는 전체 키보드 접근을 켜면 Tab·Shift+Tab·Space로 설정을
이동·조작할 수 있습니다. 읽기 전용 파일 목록은 방향키·Page Up/Down·Home/End로
스크롤합니다. 실행 중인 앱을 Finder나 Spotlight에서 다시 열면 아이콘 클릭 없이
패널에 진입합니다. 단축키는 앱에 포커스가 있을 때만 적용됩니다.

자동 변환은 앱을 실행할 때마다 켜집니다. 일시정지는 해당 실행에만 유지하며 다음
실행에서는 다시 켜집니다. 예전 설정에 꺼짐이 저장돼 있어도 같은 정책을 적용합니다.
변환 옵션은 계속 저장합니다. 일시정지 중에는 메뉴바 아이콘의 정지 기호와 패널 안내가
표시됩니다. 앱 시작과 다시 시작 때 현재 HEIC도 처리합니다.
클립보드는 0.25초마다 확인합니다. 지원 입력은 파일 URL로 제공되는 읽기 가능한
로컬 일반 `.heic` 파일과 원문 `public.heic` 이미지 데이터입니다. 확장자는
대소문자를 구분하지 않습니다. 파일 약속이나 안전하게 읽고 복구할 수 없는 표현은
거절합니다. 접근이 거부되면 자동 읽기를 중단하고 상태를 안내합니다.

Photos 자산 참조 메타데이터(`com.apple.photos.object-reference.asset`)와
`.photoslibrary` 내부 파일 URL이 함께 있는 입력은 정상 종료 후
전체 표현의 복구를 보장할 수 없어 지원하지 않습니다. raw HEIC나 다른 변환 가능한
항목이 있어도 전체 입력을 거절하며 보관함 파일을 읽거나 썸네일로 사용하지 않습니다.
보관함 URL 없는 raw HEIC 단독 입력은 계속 지원합니다. 파일 변환이 필요하면 원본을
내보낸 뒤 Finder에서 복사하세요. 파일 약속은 전체 항목의 타입을 먼저 확인해 공급자에게
표현 데이터를 요청하기 전에 거절합니다.
일반 오프라인 파일은 열기 전에 거절합니다.

동영상 타입·MOV 등 동영상 파일 URL·Photos 동영상 메타데이터는 함께 제공된
JPEG/HEIC 미리보기보다 우선합니다. 동영상은 변환 제외로 표시하고 클립보드 표현을
그대로 유지합니다. Photos가 MOV 원본 대신 JPEG 포스터를 제공한 경우, 클립보드
보존은 원본 동영상 내보내기와 다릅니다. 원본 파일이 필요하면
[Photos의 무수정 원본 내보내기](https://support.apple.com/ko-kr/guide/photos/pht6e157c5f/12.0/mac/27)를
사용하세요. 해석할 수 없는 Photos 메타데이터는 자동 변환하지 않습니다.

HEIC를 복사하고 완료를 기다린 뒤 대상 앱에서 기존 **⌘V**로 붙여넣습니다. 완료
전에 붙여넣으면 원본이 전달될 수 있습니다. 비HEIC 파일과 텍스트는 항목 순서와
보존 가능한 표현을 유지합니다. 모든 HEIC가 성공하고 클립보드 세대가 유효할 때만
결과를 게시합니다. 새 복사·취소·기능 끄기는 미게시 결과의 게시를 막고, 끄기 전에
이미 게시한 결과는 유지합니다.

변환 항목에는 임시 파일 URL과 이미지 표현을 함께 제공합니다. 현재 클립보드가
참조하는 동안 임시 파일을 유지하며 일반 출력 폴더에 결과를 누적하지 않습니다.
정상 종료 시 현재 클립보드가 앱의 게시 세대인 경우에만 원본을 복구한 뒤 임시
파일을 정리합니다. 복구 실패 시 참조 파일을 유지하고 원본 파일은 변경하지
않습니다. 비정상 종료 후 복구는 보장하지 않습니다.

기본 옵션은 JPEG, JPEG 품질 90, PNG 압축 6, 메타데이터 `safe`입니다. 이전에
저장한 변환 옵션 수치를 유지합니다. 기존 `outputDirectory`와 `onConflict`는
레거시 설정으로 보존하되 자동 변환 UI에서 제외합니다. CLI/TUI의 출력 경로,
충돌 정책과 조작 방식은 유지합니다.
기본값 복원은 화면의 형식·품질·압축·메타데이터만 초기화하며 레거시 저장 경로·충돌
정책과 현재 일시정지 상태는 유지합니다.

[2026-10-11 PR #9 기록](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-issue7-pr-readiness.md)에서는 Photos HEIC 복사,
합성 원본·편집·다중 사진과 동영상 포스터 제외를 확인했습니다. Finder에는 변환 파일
한 개·세 개와 혼합 파일 여섯 개가 중복 없이 붙었습니다. 카카오톡은 전송 전 미리보기에
한 개·여섯 개를 표시했으며 당시 전송은 취소했습니다. 별도 복구 도구에서는 종료 후
Photos 파일 URL이 사라지고 사진·메타데이터만 보존됐습니다. 이는 당시 관찰 기록이며
현재 Photos 보관함 URL의 지원을 보장하지 않습니다. 당시 macOS 27.2에서 Python
136개·Swift 95개·Ruff, 앱/DMG smoke와 Python 배포물 검사가 통과했습니다.
macOS 15·26 Apple Silicon에서도 커밋 `bdbde95`의 테스트, 앱 빌드·DMG 설치·Python
배포물 검증이 [CI에서 통과했습니다](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38128156256).

후속 관찰에서 사용자가 미다운로드로 지정한 실제 iCloud 사진의 드래그는 파일 약속과
`public.jpeg`, 일반 복사는 HEIC 없는 JPEG raw를 제공했습니다. 드래그 타입은 공급자에게
데이터를 요청하지 않고 관찰했으며 다운로드 상태는 독립적으로 검증하지 않았습니다.
일반 복사 JPEG는 재변환 없이 앱 실행·정상 종료 후 전체 표현의 타입·바이트·세대가
보존됐습니다. 수신 앱은 지원하는 표현을 선택하므로 모든 항목의 붙여넣기는 별도 검증
대상입니다. 현재 결과와 테스트 수, 카카오톡 후속 실기 상태는
[남은 검증 후속 기록](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-issue7-remaining-validation.md), 구현 중 변경 계약과 체크리스트 판정은
[이슈 #7 범위 감사](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-issue7-scope-audit.md), 지원 계약은
[클립보드 계약](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-auto-clipboard.md)을 참고하세요. Python 코어를 수정하지
않았다는 설명은 PR #9 당시 범위입니다. 후속 범위에는 네이티브 HDR 대표 이미지 선택
수정이 포함되며 CLI/TUI 및 기존 SDR fallback 정책은 유지합니다.

앱 배포물은 ad-hoc 서명을 사용하며 공증을 받지 않습니다. DMG 포장은 Gatekeeper를
우회하지 않습니다. 릴리스된 DMG의 체크섬을 확인하고 앱을 Applications에 설치하며,
실행이 차단되면 [Apple 안내](https://support.apple.com/ko-kr/102445)를 따릅니다.

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
| `strip` | 출력 이미지에서 EXIF와 XMP를 제거합니다. HDR PNG의 색 재현에 필요한 ICC 프로파일 또는 CICP 색상 정보는 유지합니다. |

변환 시 이미지 방향을 픽셀에 반영하고, 메타데이터를 저장하는 경우 출력 EXIF 방향
값을 `1`로 정규화합니다. JPEG는 알파 채널을 지원하지 않으므로 투명 영역을 흰색
배경과 합성합니다. PNG는 알파 채널을 유지합니다.

macOS 15 이상에서는 Apple HDR 게인 맵이 포함된 HEIC를 16비트 HDR PNG로
변환합니다. 네이티브 HDR 경로는 대표 이미지의 인덱스가 0이 아니어도 해당 이미지를
선택합니다. 실제 생성한 합성 다중 HEIC로 대표 인덱스 1, 16비트·PQ 출력과 메타데이터
정책을 검증했습니다. HDR 화면에서 원본의 밝기와 색 표현을 유지하기 위해 PNG에 HDR
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
- CLI의 단일 파일 입력(앱은 클립보드 입력을 사용)

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
앱에 포함된 제3자 구성 요소는 각각의 라이선스를 따릅니다. pillow-heif에 포함된
코덱 고지 등 Python 런타임과 라이브러리 이용 조건은 앱의
`Contents/Resources/Licenses`에서 확인할 수 있습니다.
