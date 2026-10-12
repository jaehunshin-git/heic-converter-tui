# 이슈 #7 후속 검증과 보존 결함 수정

## 범위와 판정

2026-10-12 KST, `test/7-remaining-validation`에서 머지된 PR #9의 남은 검증을 수행했다.
기준 `origin/main`은 `820ba4d`이며 로컬 환경은 macOS 27.2 arm64, 카카오톡 26.8.0이다.
PR #9 당시 기록은 [PR 준비 기록](macos-issue7-pr-readiness.md)에 보존한다.
개인 사진·클립보드 원문·보관함 경로·자산 식별자는 저장소와 배포물에 포함하지 않는다.

| 기존 미검증 항목 | 후속 결과와 지원 한계 |
| --- | --- |
| Photos 원본 URL의 정상 종료 후 보존 | PR #9 앱에서 원본 HEIC를 변환한 뒤 정상 종료하면 `public.file-url`만 사라짐을 재현했다. URL 재게시로 해결했다고 판정하지 않는다. 수정 앱은 Photos 자산 참조와 `.photoslibrary` 내부 URL이 함께 있는 입력 전체를 자동 변경하지 않는다. 실제 HEIC 복사의 실행·종료 전후 세대 242와 모든 타입·바이트·항목 순서가 일치했다. |
| iCloud 미다운로드 사진 | 사용자가 해당 조건의 사진을 직접 지정·드래그·복사했다. 드래그에는 파일 약속과 `public.jpeg`, 일반 복사에는 JPEG·자산 참조·파일 URL이 있었다. HEIC 표현은 없었다. 수정 앱의 JPEG 입력 실행·종료 전후 세대 241과 모든 표현이 일치했다. 다운로드 상태는 독립 확인하지 않았으며 iCloud 전용 HEIC의 변환 성공을 주장하지 않는다. |
| Photos 드래그 파일 약속 | 실제 드래그에서 `NSFilePromiseItemMetaData`, 약속 이름·콘텐츠 타입·URL 등을 관찰했다. 타입 전용 조사 경로는 원문 공급자와 파일 약속 수신을 호출하지 않고 드롭을 거절했다. 앱 저장소의 캡처·실패 미리보기·정리는 합성 provider 회귀에서 호출 0회를 검증했다. |
| 카카오톡 실제 전송·수신 | 허용된 합성 이미지만 나와의 채팅에 전송했다. Finder HEIC 1개를 변환한 JPEG는 미리보기 1개 → 채팅 사진 1개 → 사진 뷰어 정상 표시를 확인했다. HEIC+JPEG+PNG 3개는 미리보기 3개 → 채팅 사진 3개로 표시됐고 중복은 없었다. 다른 상대·기기 수신과 서버 원본 바이트 보존은 검증 범위가 아니다. |
| 기본 키보드 접근성 | PR #10에 네이티브 앱 단축키와 Finder 재열기·목록 스크롤을 추가했다. 합성 전용 보드에서 패널 닫기, 일시정지·재개, 설정 Tab·Shift+Tab·값 변경·기본값 복원 실기를 확인했다. 앱 이벤트 큐를 통과하는 키보드 smoke와 스크롤 회귀 2개를 추가했다. OS별 모든 상태 메뉴 이동·VoiceOver 지원을 검증했다고 주장하지 않는다. |
| 대표 이미지가 index 0이 아닌 HDR HEIC | 실제 합성 다중 이미지 HEIC에서 첫 이미지는 128×96 SDR, 대표 이미지 index 1은 256×256 HDR이다. 이전 코어의 잘못된 첫 이미지 출력 문제를 수정했다. 대표 이미지 크기·16비트 PQ PNG·cICP·메타데이터 safe/preserve/strip·원본 바이트 보존을 검증했다. |

미다운로드 여부를 확정하기 위한 Photos 보관함 권한 확장·설정 변경·원본 다운로드를
수행하지 않았다. 드래그와 일반 복사가 같은 자산이라고도 단정하지 않는다.
이슈 #7은 지원 범위 밖의 표현을 변경하지 않는 계약을 포함한다. 2026-10-12 추가 감사에서
구현 중 바뀐 UI·실행 정책과 원문 22개 체크리스트를 함께 대조한다. 최신 종료 판정은
[변경 계약과 종료 조건 감사](macos-issue7-scope-audit.md)를 따른다. 위 검증 결과가
모든 Photos/iCloud 조합의 지원을 의미하지는 않는다.

## 수정한 동작

- Photos 자산 참조와 보관함 내부 파일 URL 조합을 복구 불가능 입력으로 거절한다.
  디코딩된 URL 경로 구성요소의 `.photoslibrary` 확장자는 대소문자를 구분하지 않는다.
  거절 전 원본 파일 조회·썸네일 읽기·worker 준비·클립보드 쓰기를 수행하지 않는다.
  사용자는 Photos의 무수정 원본을 내보낸 뒤 Finder에서 복사할 수 있다.
  보관함 URL이 없는 원문 HEIC 입력과 내보낸 일반 파일의 지원은 유지한다.
- 파일 약속은 전체 항목의 타입을 먼저 검사한다. 실패 미리보기에서도 약속 항목의
  URL·자산 참조·raw 공급자를 요청하지 않는다. 정리 중 약속이 있으면 참조 부재를
  단정하지 않고 이미 노출된 결과 파일을 보존한다.
- 네이티브 HDR PNG는 ImageIO의 대표 이미지 인덱스를 확인하고 유효 범위를 검사한다.
  Python CLI/TUI 명령·메타데이터 정책·패키지 버전 0.3.0은 유지한다.
- 최신 Swift에서 `swift test`가 실행 대상 XCTest를 생략하는 환경을 확인했다.
  CI에서 모델 XCTest 번들을 직접 실행해 해당 회귀도 검증한다.

## 로컬 자동 검증

- Python 149개, Ruff 통과. 실제 ImageIO 다중 이미지 HEIC 검증을 포함한다.
- Swift ConverterKit 76개와 앱 모델/worker XCTest 29개, 총 105개 통과.
- 클립보드 진단 도구 14개 검사가 통과했다. named pasteboard와 독립 프로세스로 검증한다.
  실제 일반 클립보드를 자동 테스트에서 사용하지 않는다.
- 앱·DMG 조립 및 설치본 smoke는 arm64 Mach-O·서명·로더 경로, 사용자 Python 없는
  환경의 JPEG/PNG·16비트 PQ HDR worker, DMG SHA-256과 설치 복사본 실행을 확인한다.
- wheel/sdist의 영문 설명·버전·허용 목록 검증을 수행한다.
  macOS 전용 소스와 개인 사진은 Python 배포물에서 제외한다.

```sh
PYTHONPATH=src .venv-app-build/bin/python -m pytest -q
.venv-app-build/bin/ruff check src tests packaging/macos
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path macos
test_bin="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path macos --show-bin-path)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xctest "$test_bin/HEICConverterTests.xctest"
.venv-app-build/bin/python packaging/macos/test_clipboard_probe.py
bash packaging/macos/build.sh
.venv-app-build/bin/python -m build --no-isolation
.venv-app-build/bin/python packaging/macos/validate_python_dist.py dist
```

macOS 15/26 결과는 후속 PR의 GitHub Actions 기록으로 확인한다. 로컬 macOS 27.2의
성공을 다른 운영체제의 성공으로 대신하지 않는다.

## 진단 도구 사용

클립보드 원문을 캡처하기 전에 비공개 임시 디렉터리를 만든다. 스냅샷은 0600으로
저장되고 기존 파일을 덮어쓰지 않는다. `compare`는 항목 순서와 타입별 바이트를 비교한다.
한 항목의 타입 나열 순서와 캡처 세대 숫자는 비교에서 제외한다.

```sh
swiftc packaging/macos/clipboard_probe.swift -o /tmp/clipboard-probe
probe_dir="$(mktemp -d)"
chmod 700 "$probe_dir"
/tmp/clipboard-probe types general
/tmp/clipboard-probe capture general "$probe_dir/original.json"
/tmp/clipboard-probe compare general "$probe_dir/original.json"
# restore의 마지막 인자는 실제 관찰한 현재 changeCount다. 새 복사를 덮어쓰지 않는다.
# /tmp/clipboard-probe restore general "$probe_dir/original.json" <현재세대>
```

`types`는 데이터 공급자를 호출하지 않는다. `capture`와 `inspect`는 모든 데이터 표현을
요청하므로 파일 약속·iCloud 조사에 무조건 사용하지 않는다. 복구의 세대 검사는 원자적
비교·교환 보장이 아니며 복구 실패에도 스냅샷을 유지한다. Photos 보관함 URL은 도구의
쓰기 성공만으로 종료 뒤 보존됐다고 판정할 수 없다.

```sh
swiftc -parse-as-library macos/Sources/ConverterKit/*.swift \
  packaging/macos/photos_drag_probe.swift -o /tmp/photos-drag-probe
/tmp/photos-drag-probe --types-only --report-file "$probe_dir/drag-types.json"
```

이 창은 드롭을 받지 않는다. 타입 전용 모드의 보고서는 타입·항목 수·세대 유지 여부만
담는다. 기본 모드는 실제 저장소의 캡처 안전성 검사를 수행하므로 원문 읽기를 피하려면
먼저 `--types-only`를 사용한다. 기존 보고서는 덮어쓰지 않는다.

실기 종료 후 합성 Finder 입력의 정상 복구와 검증 직전 사용자 클립보드의 모든 표현
일치를 확인했고 진단 창과 검증 앱을 정상 종료했다. 카카오톡 전송 사진은 허용된 합성
이미지뿐이며 개인 Photos 사진을 전송하지 않았다.
