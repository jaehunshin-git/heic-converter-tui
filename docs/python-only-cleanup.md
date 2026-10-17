# Python 제품 전용 정리 작업

## 범위와 기준

2026-10-18 사용자 지시에 따라 [제품별 저장소 분리 결정](decisions/2026-10-18-product-repository-split.md)의
현재 저장소 정리 항목을 순서대로 진행한다. Python CLI/TUI 기능과 기존 명령·패키지명은 유지한다.
`worker.py`의 모듈 실행 계약, Quartz/PyObjC·HDR 기능, Git 훅, 개인 사진을 보존한다.

현재 작업은 로컬 구현·검증이다. 기존 원격 앱 CI는 `heiccy`의 대체 경로 검증과 기본 브랜치
반영을 확인하기 전까지 유지한다. 후속 사용자 지시에 따라 제품별 분리 결정, Python 전용
빌드·검증 구성, 안내·과거 기록 정리의 세 단위로 현재 저장소에 로컬 커밋한다.
push·PR·merge·배포·저장소 공개 범위 변경은 수행하지 않는다.

## 순서와 재개 체크리스트

- [x] 기존 소스·미커밋 문서 157개를 저장소 밖에 백업하고 파일별 SHA-256을 검증했다.
- [x] Python 배포 검증기를 `scripts/`로 분리하고 혼합 패키징 테스트를 Python 전용으로 정리했다.
- [x] 한국어 README와 영문 PyPI 설명을 CLI/TUI에 맞췄다. 공개 창구 확정 전에는 접근 가능한
  PyPI 링크만 제공하고 앱 저장소를 Python 소스·이슈 창구로 안내하지 않는다.
- [x] Python 전용 CI를 구성했다. macOS 15·26 HDR 검증과 wheel/sdist 허용 목록 검사를 유지한다.
- [x] 앱 소스·패키징·export·앱 전용 테스트를 현재 제품에서 제거하고 과거 문서·증거를 보관했다.
- [x] 앱 로컬 산출물·진단 기록은 복구 위치로 옮기고 재생성 가능한 앱 빌드 캐시는 정리했다.
- [x] 전체 Python 테스트·정적 검사·workflow 검사·패키지 빌드·설치·문서 링크를 검증했다.
- [x] 변경 범위와 보존 자료, 원격 적용 전 조건을 기록했다.

## 복구 기록

2026-10-18 사용자 지시에 따라 아래 복구용 백업 폴더 전체를 영구 삭제했다.
앱·DMG·진단 자료·이전 배포 파일·소스 백업·검증 기록·해시 목록을 포함해
92,608KiB(약 90.4MiB)를 추가 정리했다. 별도 백업 사본은 만들지 않았다.

삭제한 위치: `/Users/jhshin/Developer/01_github/_archives/heic-converter-tui/20261018-022727-python-only`

아래는 삭제 전 수행한 보존·검증 이력이며, 현재 남아 있는 백업 목록이 아니다.

`source-before-cleanup.tar.gz`, `source-manifest.json`, `working-tree-before.patch`에
정리 전 소스와 미커밋 변경을 보존했다. 개인 `input/`·`output/`은 백업·삭제 대상에서 제외했다.

- 원래 앱 문서·브랜딩·스크린샷·증거 JSON 43개와 이전 README 2개를
  `docs/archive/macos/`에 보존했다. 과거 기록 안내와 상대 링크만 보완했다.
- 앱·DMG, 기존 Python 배포 파일, QA·진단 기록 414개 항목을 백업의
  `local-artifacts/`로 이동하고 파일 해시·심볼릭 링크 대상을 확인했다.
- 남은 Xcode 작업 상태와 앱 전용 Python 캐시 16개는
  `local-artifacts/generated-app-state/`에 추가 보존했다.
- 사용 중이 아님을 확인한 `macos/.build`, `.venv-app-build`, `build/macos`의
  재생성 가능한 캐시 합계 1,185.16MiB(약 1.16GiB)를 삭제했다.
  당시 보존 위치로 옮긴 파일은 캐시 삭제량에 포함하지 않았다. 이후 위 지시에 따라 삭제했다.
- 기본 Python `.venv`는 유지했다. 개인 사진과 설치된 `/Applications` 앱은 변경하지 않았다.

문서 이동 매핑·해시와 산출물 정리 내역도 당시 백업 안에 기록했으며 함께 삭제했다.

## 구현 결과

- `macos/`, 앱 전용 `packaging/`, 앱 전용 테스트 6개와 기존 로컬 `macos.yml`을 정리했다.
  커밋된 앱 소스는 Git 이력에서 확인할 수 있다. 별도 복구용 백업은 삭제했다.
- 배포 검증기는 `scripts/validate_python_dist.py`로 옮겼다. 프로젝트 설정에서
  이름·버전을 읽고 UTF-8·영어 설명·배포 허용 목록을 검사한다.
- `tests/test_packaging.py`는 Python 배포 설정을 검증하고,
  `tests/test_python_dist.py`는 배포 파일 및 검증기 누락을 검사한다.
  `test_hdr_png.py`의 불필요한 `return None` 한 줄만 제거해 잠긴 Ruff 검사에 맞췄다.
- Python 실행 소스 6개와 `uv.lock`은 백업의 SHA-256과 일치한다.
  패키지명·실행 명령·버전·런타임 의존성·sdist 포함 목록은 유지했다.
- `README.md`는 한국어 CLI/TUI 안내, `README.ko.md`는 호환 링크,
  `README.pypi.md`는 영어 PyPI 설명으로 정리했다. 새 버전은 게시하지 않았다.
- `python.yml`은 push·PR에서 artifact를 업로드하지 않고, 수동 실행은 3일,
  `v*` 태그 push는 14일 동안 macOS 15 배포 파일 한 묶음만 보관하도록 구성했다.
  PyPI 자동 배포는 포함하지 않는다.

## 검증 결과

2026-10-18 로컬 macOS에서 확인했다. GitHub의 macOS 15·26 실행 결과를 대신하지 않는다.

| 검증 | 결과 |
| --- | --- |
| Python 3.12.13, 잠긴 의존성 | 271개 테스트 통과, skip 없음 |
| Python 3.11.15, 잠긴 의존성 | 271개 테스트 통과, skip 없음 |
| Ruff, lock 일치 검사 | 통과 |
| actionlint 1.7.12 | `python.yml` 통과 |
| wheel/sdist 실제 빌드 | 이름·버전·영문 메타데이터·허용 목록 통과 |
| 별도 환경의 wheel 설치 | CLI 도움말, 합성 HEIC → JPEG·PNG, JSONL worker 통과 |
| 원본 사진 보존 계약 | 합성 입력의 변환 전후 SHA-256 일치 |
| 저장소 밖에서 푼 sdist | 118개 통과, 개발 도구 제외에 따른 43개 skip |
| 문서 | 로컬 링크 147개 유효, 현재 안내 7개 Markdown lint 통과 |
| 변경 검사 | `git diff --check` 통과, 독립 검토 P0–P2 지적 없음 |

sdist의 skip은 배포에서 의도적으로 제외한 검증기 관련 42개와 Git 훅 테스트 모듈
1개다. checkout에서는 전체 검사가 실행됐다. 별도 설치 검증은 당시 패키지 인덱스에서
해결된 최신 허용 의존성을 사용했고, 개발 테스트는 `uv.lock`을 사용했다.
최종 로컬 wheel은 24,111바이트, sdist는 44,570바이트이며 공개 배포하지 않았다.

## 원격 적용 전 조건

조사 시 `heiccy/main`에는 workflow가 없고 전환 브랜치의 최신 커밋 `fbbaee5`는
[CI 38527551920](https://github.com/jaehunshin-git/heiccy/actions/runs/38527551920)에서
macOS 15·26 모두 앱·DMG 검증이 실패했다. 본 작업의 로컬 통과를 원격 앱 검증 성공으로
대체하지 않는다. 원격 적용 전에 해당 앱 CI를 복구·검증하고 기본 브랜치 반영을 확인한다.
