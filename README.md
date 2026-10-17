# heic-converter-tui

> HEIC 이미지 폴더를 JPEG 또는 PNG로 변환하는 Python CLI와 방향키 TUI

`heic-converter-tui`는 로컬 `.heic` 파일을 JPEG 또는 PNG로 일괄 변환합니다.
대화형 터미널에서는 방향키 TUI로 설정을 고를 수 있고, 스크립트에서는
`heic-converter` 명령으로 같은 변환 옵션을 지정할 수 있습니다. 변환은 로컬에서
수행하며 원본 파일은 변경하지 않습니다.

## ✨ 주요 기능

| 기능 | 설명 |
| --- | --- |
| 디렉터리 변환 | `.heic` 확장자 파일을 JPEG 또는 PNG로 변환합니다. |
| CLI와 TUI | 스크립트용 CLI와 한국어·영어를 선택할 수 있는 방향키 TUI를 제공합니다. |
| 안전한 출력 | 원본을 변경하지 않고, 임시 파일 완성 뒤 결과를 저장합니다. |
| 출력 제어 | 하위 디렉터리 탐색, 품질·압축 수준, 메타데이터, 이름 충돌 정책을 설정합니다. |
| HDR PNG | 지원되는 Apple HDR 게인 맵은 macOS 15 이상에서 16비트 PNG로 보존할 수 있습니다. |

## 🧭 설계 방향

- **원본 보존:** 입력은 읽기 전용으로 처리하고 결과는 별도 출력 디렉터리에 만듭니다.
- **안전한 기본값:** `safe` 메타데이터 정책은 GPS와 XMP를 제거하며, 출력 이름이
  충돌하면 기본적으로 번호를 붙여 새 파일을 만듭니다.
- **명확한 범위:** CLI는 디렉터리 입력의 정지 이미지 변환을 담당합니다. `.heif`,
  동영상, 시퀀스·보조 이미지 추출, 단일 파일 CLI 입력은 지원하지 않습니다.

## 🛠 기술 스택

| Category | 기술 |
| --- | --- |
| Runtime | Python 3.11 이상 |
| Image Processing | Pillow, pillow-heif |
| CLI & TUI | Typer, Rich, questionary |
| macOS Integration | PyObjC Quartz (macOS에서만) |
| Testing & Build | pytest, Ruff, Hatchling, uv |

## 📁 프로젝트 구조

```text
heic-converter-tui/
├── src/heic_converter/  # CLI, TUI, 변환 코어와 worker 실행 계약
├── tests/               # CLI/TUI와 변환 동작 회귀 테스트
├── scripts/             # 배포 파일 검증 등 개발 보조 도구
├── docs/                # 빌드·결정·과거 기록 문서
├── pyproject.toml       # 패키지 메타데이터와 빌드 설정
└── uv.lock              # 잠긴 의존성 해상도
```

## 🚀 시작하기

### 요구 사항

- Python 3.11 이상
- macOS가 주 지원 환경
- `uv` 또는 `pipx`

### 1. 설치하기

PyPI 패키지 안내: <https://pypi.org/project/heic-converter-tui/>

```bash
uv tool install heic-converter-tui
```

```bash
pipx install heic-converter-tui
```

### 2. 실행하기

실제 터미널에서 인수 없이 실행하면 TUI가 열립니다. 언어, 입력·출력 디렉터리,
형식, 품질 또는 압축 수준, 하위 디렉터리 포함 여부, 메타데이터와 충돌 정책을
선택한 뒤 변환을 시작합니다.

```bash
heic-converter
```

스크립트나 비대화형 환경에서는 `--format`을 반드시 지정합니다.

```bash
# input 디렉터리의 HEIC 파일을 JPEG로 변환합니다.
heic-converter --input ./input --output ./output --format jpeg

# 하위 디렉터리를 포함해 PNG로 변환합니다.
heic-converter --input ./photos --output ./converted --format png --recursive

# 품질, 메타데이터, 충돌 처리를 지정합니다.
heic-converter --input ./photos --output ./converted --format jpeg \
  --jpeg-quality 95 --metadata strip --on-conflict rename
```

### 3. 옵션과 동작

| 옵션 | 값 또는 설명 | 기본값 |
| --- | --- | --- |
| `-i, --input PATH` | 입력 디렉터리 | `./input` |
| `-o, --output PATH` | 출력 디렉터리 | `./output` |
| `-f, --format FORMAT` | `jpeg`, `png` | TUI 밖에서는 필수 |
| `--jpeg-quality N` | `1`–`100` | `90` |
| `--png-compression N` | `0`–`9` | `6` |
| `--recursive` | 하위 디렉터리 포함 | 사용 안 함 |
| `--metadata POLICY` | `safe`, `preserve`, `strip` | `safe` |
| `--on-conflict POLICY` | `rename`, `skip`, `overwrite`, `error` | `rename` |

`safe`는 GPS와 XMP를 제거하고 가능한 EXIF·ICC 프로필을 보존합니다. `preserve`는
지원되는 메타데이터를 보존하며, `strip`은 EXIF와 XMP를 제거합니다. 출력은 `.jpeg`
또는 `.png` 확장자를 사용합니다. JPEG는 투명 영역을 흰색으로 합성하고 PNG는
알파 채널을 유지합니다.

지원되는 Apple HDR 게인 맵이 있는 HEIC는 macOS 15 이상에서 16비트 HDR PNG로
변환할 수 있습니다. 지원하지 않는 환경이나 입력에서는 SDR 기본 이미지를 사용하며,
JPEG 출력은 SDR입니다.

| 종료 코드 | 의미 |
| --- | --- |
| `0` | 모든 입력을 성공적으로 처리했습니다. |
| `1` | 하나 이상의 파일을 읽거나 변환하거나 저장하지 못했습니다. |
| `2` | 인수·경로·옵션이 잘못되었거나 `.heic` 파일이 없습니다. |
| `130` | 대화형 UI를 취소했거나 `Ctrl+C`로 중단했습니다. |

### 4. 개발 환경 검증하기

저장소를 내려받은 뒤 잠긴 개발 의존성을 설치합니다.

```bash
uv sync --locked --group dev
uv run --locked ruff check src tests scripts
uv run --locked pytest
uv build --out-dir dist/python
uv run --locked python scripts/validate_python_dist.py dist/python
```

## 📚 문서

| 문서 | 내용 |
| --- | --- |
| [Python 빌드 안내](docs/build.md) | 개발 환경에서 wheel과 sdist를 빌드하고 검증하는 절차 |
| [제품별 저장소 분리 결정](docs/decisions/2026-10-18-product-repository-split.md) | Python CLI/TUI와 macOS 앱의 담당 범위 |
| [PyPI 설명 원본](README.pypi.md) | PyPI에 게시되는 영문 패키지 설명 |

## 📄 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 저작권·허가 고지를 포함하는 조건으로
사용·수정·복사·배포·판매할 수 있으며, 소프트웨어는 보증 없이 제공됩니다.
이 설명은 한국어 요약이며 전문은 [LICENSE](LICENSE)를 확인하세요.
코덱을 포함한 외부 의존성에는 각 프로젝트의 라이선스와 고지가 적용됩니다.
