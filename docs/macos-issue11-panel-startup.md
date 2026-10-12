# 이슈 #11: 새 실행 직후 메뉴바 패널 표시

2026-10-12 KST, `fix/11-menu-bar-panel-cold-start`에서
[이슈 #11](https://github.com/jaehunshin-git/heic-converter-tui/issues/11)을 조사했다.
기준 소스는 `b0a3566`, 로컬 환경은 macOS 27.2 arm64이다.
Python CLI/TUI·변환 코어·PyPI 버전은 변경하지 않는다.

## 실제 클릭에서 확인한 실패

- 앱 두 개가 함께 실행된 첫 시도는 대조 재현에서 제외했다. 이후 기존 프로세스를
  정상 종료하고 같은 계측 릴리스 번들 하나를 일반 실행했다.
- 새 프로세스 `94185`에서 사용자가 반복 좌클릭해도 패널이 열리지 않음을 확인했다.
  클릭은 `.leftMouseUp`이며 Control이 없었고, 핸들러·앵커 검사를 통과했다.
  표시 호출 뒤 `isVisible=true`여도 `isActive=false`, `isKeyWindow=false`가 지속됐다.
  이 구간에 key 상실이나 비활성화 콜백이 패널을 닫은 기록은 없었다.
- 우클릭 메뉴의 **현재 클립보드 보기**로 표시한 뒤에는 key·활성화 콜백이 발생했고
  이후 좌클릭도 정상화됐다. 메뉴만 열었다 닫은 경우에는 실패가 유지됐다.
- 좌클릭 처리를 다음 main queue turn으로 미루는 대조 수정은 실패했다.
  기본 run loop에서 표시해도 앱과 패널은 비활성·non-key 상태였다.

초기 실패는 클릭 분류나 앵커 미준비가 아니라 비활성 앱의 패널 표시·포커스 획득
단계에서 발생했다. AppKit·WindowServer 내부의 활성화 거절 사유까지 확정한 것은 아니다.
수정 전 원본 번들을 새 프로세스 `25010`으로 실행해 설정 창만 먼저 열고 닫은
조건도 대조했다. 사용자가 이후 좌클릭으로 패널이 정상 표시됨을 확인했다.
메뉴 자체보다 실제 창 표시·활성화가 회복과 연결된다는 관찰을 뒷받침한다.

## 수정한 동작

1. `showPanel()`에서 위치를 정한 뒤 `orderFrontRegardless()`로 패널을 먼저 화면
   앞으로 올리고, 앱 활성화와 `makeKeyAndOrderFront()`를 요청한다.
2. 첫 클릭 표시가 해결된 뒤 두 번째 클릭의 재열림을 추가 확인했다. 아이콘을
   누르면 mouseUp 전에 key 상실·비활성화 콜백이 패널을 닫았고, mouseUp의 토글은
   이미 숨겨진 패널을 다시 열었다.
3. `hidesOnDeactivate=false`로 OS 자동 숨김과 앱의 닫기 처리가 중복되지 않게 했다.
   포커스 콜백은 자기 아이콘 위에서 일반 좌클릭을 누르는 동안 닫기를 보류한다.
   mouseUp 핸들러가 표시·숨김을 결정한다. 아이콘을 누른 채 밖으로 끌어 클릭을
   취소하는 경우에도 닫기가 남지 않도록 마우스 해제 뒤 포커스를 다시 확인한다.
   정상 action·재표시·종료는 예약된 닫기를 취소한다. 다른 앱·설정으로 이동하거나 키보드로
   포커스를 옮길 때의 닫기와 우클릭·Control 클릭의 메뉴 분기는 유지한다.

수정 릴리스 프로세스 `1256`에서 사용자가 첫 클릭 표시, 두 번째 클릭 닫기,
세 번째 클릭 다시 표시, 외부 앱 클릭 시 닫힘을 모두 확인했다.
우클릭·Control+좌클릭 메뉴, 메뉴의 현재 클립보드 보기·설정 열기,
⌘드래그로 메뉴바 아이콘 위치 이동도 정상 확인했다.
최종 패키징 번들 하나를 새 프로세스 `31752`로 실행한 뒤에도 사용자가 첫 클릭·
반복 토글, 아이콘 밖으로 끌어 클릭 취소 후 닫힘·다음 클릭 재표시,
우클릭·Control 클릭 메뉴의 요청한 확인 절차를 모두 정상으로 확인했다.

## 회귀 검사

- `StatusItemInteractionTests`는 일반 좌클릭·우클릭·Control 클릭·키보드·접근성
  활성화의 분기와, 마우스를 누르지 않은 키보드 포커스 이동에서 닫기를 보류하지
  않는 조건을 검사한다.
- `--panel-startup-test`는 named pasteboard와 별도 UserDefaults를 사용한다.
  시작 시 설정이나 패널을 먼저 열지 않고, 상태 버튼 창에 mouseDown/up을 앱 이벤트
  큐로 게시한다. 첫 핸들러 도달·표시·key, 두 번째 숨김·숨김 유지,
  세 번째 재표시와 외부 앱 이동 시 닫힘을 검사한다.
- 테스트는 `NSApp.terminate`와 기존 `terminateLater` 정리 경로를 사용한다.
  MainActor Task가 반환한 뒤 AppKit run loop에서 종료를 요청해 중첩 루프에서도
  worker 정리의 main queue 콜백이 진행되게 한다.
- `test_panel_startup.py`는 일반 LaunchServices 실행·정상 종료를 같은 번들에서
  두 번 수행하고 서로 다른 PID·필수 검사·정상 종료 로그·프로세스 소멸을 확인한다.
  기존 실행파일명의 프로세스가 있으면 실패하며 다른 앱을 종료하거나 중복 실행하지 않는다.
- 합성 앱 이벤트는 실제 WindowServer 메뉴바 입력을 완전히 재현하지 않는다.
  합성 검사의 성공을 실제 첫 클릭 검증 대신 사용하지 않는다. 실제 입력 근거는 위 사용자 실기다.
- `DeferredPanelDismissalTests` 6개는 마우스 해제 대기, 포커스 조합, 예약 후 취소,
  재예약과 콜백 실행 시점의 포커스 재판정을 검사한다.
- 로컬 Swift XCTest는 ConverterKit 76개와 앱 대상 41개, 총 117개를 통과했다.
  앱 XCTest 번들을 직접 실행해 최신 SwiftPM의 실행 대상 테스트 생략도 보완했다.
- 최종 일반 번들 재실행 검사에서 `30689 → 30708`의 서로 다른 두 프로세스가
  모든 클릭·포커스 검사와 정상 종료를 통과했다.
- 기존 번들 앱 smoke의 패널·설정·키보드 명령·포커스 닫힘·알림·실제 worker
  JPEG/PNG 자동 변환·원본 복구 검사도 통과했다. Ruff와 빌드 스크립트 구문 검사를 통과했다.
- 새 worker부터 조립한 전체 `build.sh`가 앱·DMG 체크섬·설치 복사본 검증까지 통과했다.
  첫 패키징 실행에서는 기존 키보드 smoke 일부가 실패했다. 코드 변경 없이
  포커스 로그를 추가한 독립 smoke와 전체 패키징 재실행은 모두 통과했다.
  첫 실패의 원인은 확정하지 않았으며 GUI 포커스 검사의 변동 가능성으로 기록한다.
- Python pytest 163개, 클립보드 진단 도구의 독립 프로세스 검사 14개,
  wheel·sdist 허용 목록·영문 메타데이터 검사도 통과했다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path macos
test_bin="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path macos --show-bin-path)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xctest "$test_bin/HEICConverterTests.xctest"
python3 packaging/macos/test_panel_startup.py 'dist/macos/HEIC Converter.app'
```

`build.sh`도 기존 앱 smoke 뒤 재실행 검사를 수행한다. 검사에는 로그인된 GUI 세션이 필요하다.
로컬 macOS 27.2의 성공을 CI의 macOS 15/26 성공으로 대신하지 않는다.
키보드 상태 메뉴 진입은 수정 전 원본과 수정본 모두 Control+F8 및
Fn+Control+F8에서 HEIC 아이콘에 도달하지 못했다. 사용자는 Xcode 메뉴 안에서만
방향키·Tab 이동이 가능하다고 보고했다. 시스템 설정에서 상태 메뉴 포커스 단축키가
Control+F8로 활성화된 것은 읽기 전용으로 확인했고 설정은 변경하지 않았다.
이번 변경에 따른 새 회귀는 관찰되지 않았지만 실제 키보드 아이콘 진입 성공을
확인한 것은 아니다. 기존 이벤트 분기와 키보드 포커스 닫기 조건은 XCTest로 검사한다.
OS 상태 메뉴 접근 문제와 VoiceOver 실기는 별도 확인 범위로 남긴다.

## 선택적 계측

`HEIC_PANEL_TRACE=1`은 PID·단조 시각·이벤트 종류와 수정 키·run loop 모드,
앱 활성 상태·패널 visible/key·앵커 유효 여부와 콜백 순서를 stdout에 남긴다.
클립보드 원문·파일명·이미지·설정 값은 기록하지 않는다.
기존 앱이 종료된 상태에서 실행해야 새 프로세스 로그를 확보할 수 있다.

```sh
open --env HEIC_PANEL_TRACE=1 \
  --stdout /tmp/heic-panel.log --stderr /tmp/heic-panel.err \
  'dist/macos/HEIC Converter.app'
```
