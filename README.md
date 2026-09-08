# HEIC Converter

HEIC 이미지를 JPEG 또는 PNG로 변환하는 설치형 Python 3.11+ 명령줄 도구입니다. macOS를 우선 지원하며, 입력 디렉터리와 하위 디렉터리를 처리합니다.

이 도구는 HEIC 파일의 **primary still image(기본 정지 이미지)**만 변환합니다. 원본 파일은 덮어쓰지 않으며, 변환 결과를 별도의 출력 경로에 저장합니다.

## 요구 사항

- Python 3.11 이상
- macOS 우선 지원
- HEIC 디코딩을 지원하는 시스템 및 Python 이미지 런타임

## 설치

저장소 루트에서 다음 중 하나를 실행합니다.

```bash
uv tool install .
```

또는

```bash
pipx install .
```

설치 후 실행 파일 이름은 `heic-converter`입니다.

## 사용법

인수 없이 TTY에서 실행하면 대화형 TUI가 시작됩니다.

```bash
heic-converter
```

화면에서 `↑`/`↓` 방향키와 Enter로 JPEG 또는 PNG, 형식별 품질/압축 preset, 재귀 검색, metadata 정책, conflict 처리 방식, 실행 또는 취소를 선택합니다. 입력 경로와 출력 경로는 화면의 입력란에 직접 입력합니다. 기본 경로는 각각 `./input`과 `./output`입니다.

간단한 실행 화면 예시는 다음과 같습니다.

```text
HEIC Converter

❯ JPEG
  PNG

JPEG 품질 preset     ❯ 고품질 (90)
재귀 검색            ❯ 아니요
메타데이터           ❯ safe
충돌 처리            ❯ rename
입력 경로            ./input
출력 경로            ./output

❯ 실행
  취소
```

키 안내:

- `↑`/`↓`: 선택 항목 이동
- `Enter`: 선택 확정 또는 다음 단계로 이동
- 경로 입력란: 경로를 직접 입력
- `Ctrl+C` 또는 `취소`: 작업을 시작하지 않고 종료(코드 `130`)

TTY가 아닌 환경에서는 이 화면을 사용하지 않으며, 아래 비대화형 명령을 사용해야 합니다.

스크립트나 자동화에서는 단일 명령 형식을 사용합니다.

```bash
# 입력 디렉터리의 HEIC를 JPEG로 변환
heic-converter --input ./input --output ./output --format jpeg

# 디렉터리의 HEIC 파일을 PNG로 변환
heic-converter --input ./photos --output ./converted --format png

# 하위 디렉터리까지 검색하고 기존 결과가 있으면 새 이름으로 저장
heic-converter --input ./photos --output ./converted --format jpeg --recursive --on-conflict rename
```

## 명령 형식

```text
heic-converter --input INPUT --output OUTPUT --format {jpeg,png} [옵션]
```

`--input`은 입력 디렉터리이고 `--output`은 출력 디렉터리입니다. 두 옵션의 기본값은 각각 `./input`과 `./output`입니다. 변환 결과는 입력 디렉터리의 상대 경로 구조를 유지해 저장됩니다. 단일 파일 입력은 지원하지 않습니다.

### 옵션

| 옵션 | 설명 | 기본값 |
| --- | --- | --- |
| `--input PATH` | 입력 디렉터리 | `./input` |
| `--output PATH` | 출력 디렉터리 | `./output` |
| `--format {jpeg,png}` | 출력 형식 | 필수(비대화형) |
| `--jpeg-quality N` | JPEG 품질(일반적으로 1~100). PNG에서는 무시됨 | `90` |
| `--png-compression N` | PNG 압축 수준(일반적으로 0~9). JPEG에서는 무시됨 | `6` |
| `--recursive` | 입력 디렉터리의 하위 디렉터리까지 검색 | 꺼짐 |
| `--metadata {safe,preserve,strip}` | 메타데이터 처리 정책 | `safe` |
| `--on-conflict {rename,skip,overwrite,error}` | 같은 이름의 출력 파일이 있을 때의 동작 | `rename` |

JPEG 출력은 `.jpeg`, PNG 출력은 `.png` 확장자를 사용합니다.

예:

```bash
# JPEG 품질 88, 메타데이터 보존
heic-converter --input ./input --output ./output --format jpeg --jpeg-quality 88 --metadata preserve

# PNG 압축 9, GPS와 XMP를 제거하고 나머지는 가능한 범위에서 보존
heic-converter --input ./input --output ./output --format png --png-compression 9 --metadata safe

# 기존 파일은 건너뜀
heic-converter --input ./input --output ./output --format jpeg --on-conflict skip

# 기존 파일을 교체
heic-converter --input ./input --output ./output --format png --on-conflict overwrite
```

## 메타데이터와 이미지 처리

메타데이터 정책은 다음과 같습니다.

- `safe` (기본값): GPS 위치 정보와 XMP를 제거합니다. 그 밖의 EXIF와 ICC 프로파일은 가능한 범위에서 보존합니다.
- `preserve`: 변환 라이브러리가 지원하는 메타데이터를 최대한 보존합니다.
- `strip`: 출력 이미지의 메타데이터를 제거합니다.

변환 시 이미지 orientation을 픽셀에 반영해 정규화합니다. 따라서 출력 파일은 EXIF orientation 태그에 의존하지 않고 올바른 방향으로 표시됩니다.

JPEG는 알파 채널을 지원하지 않으므로 투명 영역을 흰색으로 합성합니다. PNG는 알파 채널을 유지합니다.

## 파일 검색 및 충돌 처리

- 지원 입력은 확장자가 `.heic`인 파일입니다(대소문자 구분 없음). `.heif` 파일은 제외합니다.
- 디렉터리는 기본적으로 바로 아래 파일만 검색하며, `--recursive`를 지정하면 하위 디렉터리까지 검색합니다.
- 출력 디렉터리가 입력 디렉터리 안에 있더라도 출력 경로 자체는 검색 대상에서 제외합니다. 따라서 변환 결과를 다시 입력으로 처리하지 않습니다.
- `rename`은 `photo.jpeg`, `photo-2.jpeg`, `photo-3.jpeg`처럼 충돌하지 않는 새 파일명을 자동으로 선택합니다.
- `skip`은 기존 파일을 그대로 두고 해당 항목을 건너뜁니다.
- `overwrite`는 기존 출력 파일을 교체합니다.
- `error`는 충돌을 오류로 보고 처리를 실패시킵니다.

## 범위와 제한

이 프로젝트의 범위는 HEIC의 기본 정지 이미지 변환입니다. 다음 기능은 제공하지 않습니다.

- PDF 변환 또는 PDF 생성
- HWP/HWPX 변환
- OCR 및 텍스트 추출
- Live Photo의 동영상/비디오 처리
- primary still image 이외의 보조 이미지, 시퀀스 또는 동영상 추출

## 종료 코드

자동화에서 결과를 판별할 수 있도록 다음 종료 코드를 사용합니다.

| 코드 | 의미 |
| --- | --- |
| `0` | 모든 입력을 성공적으로 처리함 |
| `1` | 하나 이상의 파일을 읽거나 변환하거나 저장하는 중 오류가 발생함 |
| `2` | 명령줄 인수, 경로, 옵션 값 등 사용법이 잘못되었거나 대상 `.heic` 파일이 없음 |
| `130` | 대화형 화면에서 `Ctrl+C`를 누르거나 `취소`를 선택함 |

자세한 옵션은 다음 명령으로 확인할 수 있습니다.

```bash
heic-converter --help
```

## 실행 모드와 입력 없음 처리

- 인자 없이 TTY에서 실행하면 대화형 TUI가 시작됩니다. JPEG/PNG, 형식별 품질·압축 preset, 재귀, metadata, conflict, 실행/취소와 input/output 경로를 화면에서 선택합니다.
- TTY가 아닌 환경에서 `--format`을 생략하면 사용법 오류로 종료 코드 `2`를 반환합니다.
- 입력 디렉터리에서 처리할 `.heic` 파일을 찾지 못하면 종료 코드 `2`를 반환합니다.
- 대화형 화면에서 `Ctrl+C`를 누르거나 `취소`를 선택하면 종료 코드 `130`을 반환합니다.
