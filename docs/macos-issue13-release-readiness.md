# 이슈 #13 배포 준비와 검증 기록

## 결정 사항

2026-10-13 사용자 확인으로 다음 정책을 확정했다.

- 새 공개 저장소 `jaehunshin-git/heiccy`에 소스·문서·DMG 공개.
- 최초 이전은 새 Git 이력이며 기존 내부 이슈·PR·과거 커밋은 이전하지 않음.
- 기존 저장소를 개발 기준으로 유지하고 공개 배포 검증 후 Private 전환.
- GitHub Releases 앱 `v1.0.0`, 독립 PyPI 유지, ad-hoc 서명·미공증 첫 실행 안내.

## 현재 검증 결과

현재 로컬 환경은 arm64, `sw_vers` 출력 macOS 27.2, Xcode 개발자 도구다.
이 결과가 macOS 15·26 CI를 대신하지는 않는다.

| 검증 | 결과 |
| --- | --- |
| Python 기존 회귀 테스트 | 177건 통과. 신규 배포 테스트의 최종 결과는 아래 추가 기록 |
| Swift ConverterKit | 76건 통과 |
| Swift 앱 XCTest 직접 실행 | 47건 통과 |
| 앱 1.0.0 빌드 | 성공. Mach-O 44개 arm64·로더·ad-hoc 서명 검사 통과 |
| worker | 합성 HEIC JPEG·PNG와 지원 HDR 16비트 PQ 변환 통과 |
| 패널 시작·키보드 | 빌드 스크립트의 LaunchServices 새 프로세스 2회와 실제 상태 버튼 분기·콜드 메뉴 검사 통과 |
| DMG | SHA-256·hdiutil verify·마운트·Applications 링크·임시 설치 복사본 실행 통과 |
| Python 배포 파일 | wheel/sdist 0.3.0 영어 설명과 허용 목록 통과 |
| UI 관찰 | 새 heiccy 패널의 이름·아이콘·워드마크·빈 상태 표시 확인 |

UI 도구에서 첫 앱 연결이 timeout, bundle ID 연결은 기존·새 번들 중복으로 실패했다.
새 번들의 전체 경로로 연결 후 패널은 확인했다. 메뉴바 AX 클릭은 offscreen 오류로
실패해 이번 UI 도구로 물리적 좌·우클릭 완료를 증명하지 못했다. 빌드 smoke의 상태
버튼 분기 성공과 구분한다. 기존 설치본을 Applications에서 교체하고 실제 사용자
설정이 승계되는 최종 검증도 아직 완료하지 않았다.

`swift test`는 실행 대상 테스트를 생략하므로 실제 `.xctest` 경로를 찾아 별도 실행했다.
Ruff는 앱 고정 환경의 0.14.4에서 검사한다. 기본 개발 환경의 최신 Ruff가 추가로
지적하는 기존 스타일 진단은 이번 배포 동작 변경과 구분한다.

## 원격 상태와 남은 작업

- 새 공개 저장소 생성 완료. 실제 소스 이전·태그·DMG 게시 완료 여부는 추가 기록한다.
- 개발 저장소는 Public 유지. 공개 다운로드 검증 전에 Private로 바꾸지 않는다.
- `public-release` environment 생성, `macos-v*` 태그 접근 제한 설정 완료.
- 전용 `HEICCY_RELEASE_TOKEN`은 사용자 직접 등록 필요. 토큰 값을 채팅·Git에 넣지 않는다.
- 최종 개발 커밋의 macOS 15·26 CI, 공개 snapshot과 source SHA·파일 해시 검증이 필요하다.
- 배포 workflow는 초안 릴리스까지만 만든다. 초안·공개 다운로드에서 설치·첫 실행·
  변환·업그레이드를 검증한 뒤 공개 게시와 Private 전환을 진행한다.
- 기존 PyPI 게시 버전의 URL은 소스 수정만으로 바뀌지 않는다. 다음 독립 Python
  릴리스에서 새 공개 경로를 반영해야 하며 이전 설명의 내부 링크는 남을 수 있다.
- Private 전환 후 계정 플랜에 따른 environment·branch protection·Actions 동작을 재검증한다.

## 기록 위치

로컬 빌드·Swift·XCTest 로그는 `/tmp/heiccy-issue13-*.log`, 배포 파일은 `dist/`에
보존한다. 개인 파일과 로그는 공개 snapshot과 Python 배포에 포함하지 않는다.
전체 배포 완료 여부는 위 남은 작업을 실제 검증한 뒤 갱신한다.

## 배포 설정 추가 기록

- 사용자가 전용 토큰 생성·등록 완료를 알렸고 environment secret 이름
  `HEICCY_RELEASE_TOKEN`의 존재를 API로 확인했다. 값은 읽거나 출력하지 않았다.
- 저장소 변수 `HEICCY_RELEASE_ENABLED=true`를 설정했다. 기능 브랜치·PR에서는
  게시 job이 실행되지 않으며 두 OS 성공·main 포함·macOS 태그 조건을 요구한다.
- 별도 클립보드 진단 도구의 독립 프로세스 테스트 14건이 통과했다.

## 통합 검증 추가 기록

- 새 릴리스·exporter·코덱 테스트를 포함한 Python 295건과 고정 Ruff 0.14.4 검사 통과.
- 고정 원본 5개의 다운로드·해시·tar·필수 파일·x265 원본 대조와 약 32MB 코덱
  source bundle 생성, SHA-256 검사 통과. 동일 wheel 재빌드와 수정 라이브러리
  교체·실행 검증은 아직 완료하지 않았다.
- Python sdist에서 111건 통과·66건 skip. macOS 패키징 코드가 없는 배포 파일에서도
  테스트 collection이 정상 동작한다.
