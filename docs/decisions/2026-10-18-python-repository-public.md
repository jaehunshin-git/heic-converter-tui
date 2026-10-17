# Python 저장소 공개 운영

- 결정일: 2026-10-18 KST
- 상태: 사용자 확정
- 근거: 사용자의 현재 저장소 push·공개 전환 지시

## 결정

`jaehunshin-git/heic-converter-tui`의 Python 제품 전용 변경을 `main`에 push하고
저장소를 공개로 전환한다. 기존 [제품별 분리 결정](2026-10-18-product-repository-split.md)의
두 제품 독립 운영은 유지하며, 이 저장소를 비공개로 유지하던 방침은 대체한다.

공개 소스·문서는 `https://github.com/jaehunshin-git/heic-converter-tui`,
이슈는 해당 저장소의 `/issues`를 사용한다. 패키지 메타데이터와 영문 PyPI 설명에도
이 주소를 반영한다. PyPI 프로젝트는 기존 Homepage로 유지한다.

이 저장소에는 Python CLI/TUI 검증과 wheel·sdist 빌드만 반영한다. 이번 명시적
push 지시에 따라 이전의 `heiccy` 앱 CI 복구 선행 조건을 이 저장소의 반영 조건에서
제외한다. `heiccy` 앱 CI 복구와 기본 브랜치 반영은 별도 후속 작업으로 관리하며,
이번 공개 전환만으로 앱의 빌드·배포 검증 완료를 선언하지 않는다.

## 적용 범위

- 공개 전 현재 추적 파일과 원격 브랜치·태그를 포함한 Git 이력을 검사한다.
  개인 입력·출력, 가상환경, 캐시, 로컬 배포 파일은 Git에 추가하지 않는다.
- 과거 앱 문서·브랜딩·검증 기록은 `docs/archive/macos/`에서 당시 이력으로 보존한다.
- 패키지명·실행 명령·버전을 바꾸거나 PyPI에 새 버전을 배포하지 않는다.
  이미 게시된 PyPI 메타데이터와 설명은 다음 배포 시 갱신한다.
- 별도 `heiccy` 저장소의 코드·설정·공개 범위는 변경하지 않는다.
- push 후 원격 `main` 커밋 일치, 공개 상태, 인증 없는 접근과 Python CI 상태를 확인한다.
