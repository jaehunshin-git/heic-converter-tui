# macOS 앱 검증 결과

- 연결 이슈: [#2](https://github.com/jaehunshin-git/heic-converter-tui/issues/2)
- 검증일: 2026-10-05
- 기능 버전: 앱·wheel·sdist 0.3.0
- CI: [macOS 15·26 Apple Silicon 검증 성공](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/37216718123)
- CI 검증 커밋: `9a3eab5b786e589cba66b03cac958f1a5145eafb`
- 로컬: macOS 27.2, arm64, 앱 빌드 Python 3.12.12

## 기능과 근거

| 완료 기준 | 검증 근거 |
| --- | --- |
| 메뉴 막대·고정 패널·반복 토글·외부 포커스·완료 후 유지 | Swift/AppKit 앱 smoke에서 패널 표시·반복 숨김/열기·비활성화 후 유지 확인. 실제 앱 UI에서 Finder로 전환하고 변환 완료 뒤 열린 패널 확인 |
| 패널 숨김과 앱 종료 구분 | 닫기는 `orderOut`, 앱 종료는 타이머 무효화와 worker 종료. panel smoke 및 worker 종료 신호 회귀 |
| 단일/여러 파일 드롭·선택 취소·재입력·지금 변환·목록 추가 | 앱 입력 모델 통합 smoke에서 staged 선택·취소·재입력·수동 대기 검증. 예약 작업과 옵션 스냅샷 Swift 회귀 |
| Finder·직접 붙여넣기·숨긴 상태 감지·중복·재시작·토글·접근 거부 | 실제 Finder 복사→자동 실행 없이 대기 항목 추가 확인. 이름 있는 임시 pasteboard를 사용한 앱 smoke, ClipboardGate 및 설정 저장 Swift 회귀. 타이머는 패널과 독립적으로 실행 |
| 변환 중 추가·옵션 고정·취소·부분 실패·재시도·완료 정리 | Swift 대기열 회귀와 Python 배치/worker 회귀. 현재 파일 완료 뒤 취소, 완료 후 늦은 취소가 다음 작업을 방해하지 않는 회귀 |
| 공백·한글 경로·권한·삭제·심볼릭 링크·동일 이름·충돌 정책 | Python 서비스/CLI/worker 및 Swift 입력 검증. 패키징 smoke의 실제 공백·한글 임시 경로. 파일 링크 거절과 macOS 시스템 경로 별칭의 실제 경로 중복 제거 |
| 기존 CLI/TUI·worker 프로토콜·종료·취소·원자적 저장 | Python 83개 통과, Ruff 통과. Swift XCTest 6개 통과. SIGTERM 현재 파일 완료, EOF 완료 대기, 네이티브 stdout 진단 분리 |
| SDR/HDR·메타데이터·색상 프로파일 | 개인 사진 없이 합성 Apple 게인 맵 생성. 실제 16비트 HDR PNG/PQ 색상 정보, safe/preserve/strip, JPEG SDR, 원본 바이트 보존 검증 |
| macOS 15와 현재 지원 OS의 arm64 앱·독립 실행 설치 | CI macOS 15·26에서 앱 실행/DMG 검증 성공. 로컬 macOS 27.2도 성공. 임시 설치 위치의 복사본을 사용자 Python 없는 PATH/HOME으로 실행하여 실제 HEIC JPEG·PNG·HDR 변환 |
| 네이티브 아키텍처·로더·서명·DMG·체크섬 | Mach-O 44개 arm64, 최소 OS, 로더 상대 경로, 각 코드 및 앱 ad-hoc 서명 검사. DMG 읽기 전용 마운트, 앱+Applications 링크, SHA-256 및 설치 복사본 재검증 |
| 개인정보 배제·버전·영문 PyPI 메타데이터 | 앱/DMG와 wheel/sdist 허용 목록 검사. METADATA 및 PKG-INFO 버전·Summary·영문 본문 검사, Twine 통과. 기존 input/output 개인 자료 미사용·미포함 |
| 최종 산출물과 재현 가능한 절차 | 독립 앱, arm64 DMG·체크섬, wheel·sdist, [빌드/배포 문서](macos-build-release.md), [worker 프로토콜](macos-worker-protocol.md) |

## 검증 범위

macOS 15·26은 GitHub의 arm64 VM, macOS 27.2는 로컬 Apple Silicon에서 검증했다.
독립 실행 검증은 시스템 Python을 삭제하는 대신 사용자 Python 경로·개발 환경을
제외하고 앱에 포함한 실행 파일만 사용했다. DMG는 실제 마운트 후 임시 설치 위치로
복사하여 검증하며 사용자의 Applications를 덮어쓰지 않았다.

실제 Finder 복사·변환 UI 확인에는 실행 중 만든 합성 HEIC만 사용했다. 앱의 자동
입력 검증은 별도의 임시 pasteboard와 설정 저장소를 사용하여 사용자 복사 이력을
읽거나 기록하지 않는다. 드롭 선택 모델과 대기열을 자동 검증하고 실제 UI의 결과도
확인했다. 접근 거부는 순수 상태 모델의 회귀 테스트로 검증하며 시스템 권한을
임의 변경하지 않았다.

초기 16×16/8×8 합성 게인 맵은 macOS 15 ImageIO에서 표본이 부족해 SDR 색상으로
디코딩되었다. 검증 입력을 기본 이미지 256×256, 변화가 있는 게인 맵 128×128로
확대해 실제 HDR 결과를 두 OS에서 확인했다. 색상 정보는 ICC의 PQ 프로파일 또는
PNG3 CICP의 PQ 전달 함수를 검사하며 SDR sRGB 출력은 HDR 검증 성공으로 인정하지
않는다.

로컬 DMG의 SHA-256은 아래와 같다. CI 산출물은 빌드 환경에 따라 바이트가 달라질 수
있으므로 함께 생성한 각 체크섬을 사용한다.

```text
99d83caa79426ed8a0f05a7513fa27bf800c67b0bac6ebb514a83afd8f30c127
```

GitHub Releases/PyPI 게시, v0.3.0 태그 생성, main 머지는 이 구현 작업에서 수행하지
않았다. PR은 열어 두며 배포 절차는 [별도 문서](macos-build-release.md)에 기록했다.
