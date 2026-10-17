# 과거 macOS 앱 기록

이 폴더는 `heic-converter-tui`에서 macOS 앱을 함께 개발하던 당시의 문서·브랜딩·
실기 검증 자료를 보관한다. 현재 Python 제품의 기능·배포 안내로 사용하지 않는다.
새 앱 개발은 `heiccy`, Python CLI/TUI 개발은 이 저장소가 담당한다.
[제품별 분리 결정](../../decisions/2026-10-18-product-repository-split.md)을 따른다.

## 보존 범위

- [초기 앱 설계](macos-app-plan.md), [자동 클립보드 계약](macos-auto-clipboard.md),
  [과거 JSONL worker 계약](macos-worker-protocol.md)
- [날짜별 검증](macos-verification.md), [패널 시작 문제](macos-issue11-panel-startup.md),
  [이슈 #13 배포 검증](macos-issue13-release-readiness.md)
- [기존 빌드 안내](build.md), [이전 배포 운영](macos-build-release.md),
  [수동 릴리스 기록](macos-manual-release.md), [artifact 정리 기록](macos-artifact-storage.md)
- [브랜딩 결정](macos-branding.md), [브랜드 원본](assets/branding/DESIGN.md),
  원본 아이콘·로고·설치 검증 캡처와 증거 JSON
- [이전 한국어 앱 README](README.app.ko.md), [이전 영어 앱 README](README.app.en.md)

본문의 완료·미검증 표시는 당시 기록이다. 현재 앱 구현·CI·릴리스 상태를 증명하지 않는다.
과거 문서·검증 기록은 현재 저장소의 이력으로 보존하며 `heiccy`에 일괄 복사하지 않는다.

## 복구와 링크

정리 전 원문을 보관했던 저장소 밖 백업은 2026-10-18 사용자 지시에 따라 삭제했다.
당시 검증 결과와 삭제 내역은 [정리 작업 기록](../../python-only-cleanup.md)에 있다.
이 폴더의 문서는 과거 기록 안내와 이동한 상대 링크만 보완했으며 검증 결과를 다시 쓰지 않았다.
앱 코드는 정리 전 커밋 `0516b5883ae8b55fe5af7ed3412fbd40a0e47288`의 Git
이력에서 확인할 수 있다. 과거 실행 명령·절대 경로는 현재 실행 절차가 아니다.
