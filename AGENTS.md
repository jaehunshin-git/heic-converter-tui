# AGENTS.md

## 제품별 저장소 운영

- 2026-10-18 확정한 [제품별 저장소 분리
  결정](docs/decisions/2026-10-18-product-repository-split.md)을 따른다.
- 이 저장소는 Python CLI/TUI와 PyPI `heic-converter-tui`의 개발·문서·테스트·배포 원본이다. 실행 명령
  `heic-converter`를 유지한다.
- Swift macOS 앱·DMG·앱 릴리스는 `jaehunshin-git/heiccy`에서 관리한다. 이 저장소를 과거 기록 전용으로
  바꾸는 기존 통합 방침은 대체됐다.
- 현재 작업 트리는 Python 제품 전용이다. 앱 관련 과거 기록은 `docs/archive/macos/`에 보존한다. 구현·검증 결과와
  원격 적용 전 조건은 [정리 작업 기록](docs/python-only-cleanup.md)을 확인한다.
- 원격 앱 CI 중단은 `heiccy`의 대체 빌드·검증 경로와 기본 브랜치 반영을 확인한 뒤 적용한다. 로컬 변경만으로 두 저장소의
  전환이 완료됐다고 보고하지 않는다.
- 현재 비공개 상태를 유지한다. Python 제품의 공개 소스·문서·이슈 창구는 별도로 확정하며 비공개 주소를 공개 안내로 사용하지 않는다.

## PyPI 문서 언어

- PyPI에 표시되는 프로젝트 설명과 배포 메타데이터는 영어로 작성한다.
- `pyproject.toml`의 `description`과 `readme`가 가리키는 `README.pypi.md`는 영어로 유지한다.
  PyPI의 프로젝트 설명은 `README.pypi.md`를 사용한다.
- `README.md`는 한국어 Python 제품 안내, `README.ko.md`는 해당 문서로의 호환 링크다.
  `README.pypi.md`에는 영어로 CLI/TUI의 기능·설치·사용·지원 환경·라이선스를 작성하고 앱 설치 안내는 넣지 않는다.
- CLI/TUI 기능을 변경할 때는 Python 제품 안내와 `README.pypi.md`를 함께 검토한다. 기존 `heiccy` 링크를
  일괄 계승하지 않으며 공개 창구 확정 후 접근 가능한 패키지 소스·문서·이슈 URL을 사용한다.
- 배포 전에 빌드된 wheel의 `METADATA`와 sdist의 `PKG-INFO`에서 `Summary` 및 본문 언어를 확인한다.
- 이미 게시된 PyPI 버전의 설명은 덮어쓸 수 없으므로 설명을 변경할 때 버전을 올리고 GitHub 태그·릴리즈와 일치시킨다.

## 배포 파일

- `input/`과 `output/`의 사진 및 개인 파일을 Git에 추가하거나 배포 파일에 넣지 않는다.
- sdist는 `pyproject.toml`의 `only-include` 허용 목록을 사용한다. 배포 전 sdist 목록을 확인해 개인
  파일이 없는지 검증한다.
- sdist의 설명 파일은 `README.pypi.md`만 포함한다. 앱 README, 앱 빌드 파일 및 `docs/`는 포함하지 않는다.
  PyPI 설명에는 접근 가능한 절대 URL만 사용하며 공개 창구 확정 전에는 PyPI 프로젝트 링크를 사용한다.

## 개발과 검증

- [Python 빌드 안내](docs/build.md)에 따라 `uv sync --locked --group dev`, `uv run
  --locked ruff check src tests scripts`, `uv run --locked pytest`를 실행한다.
- 배포 후보는 `uv build --out-dir dist/python`으로 만들고 `uv run --locked python
  scripts/validate_python_dist.py dist/python`으로 검증한다.
- `service.py`와 Quartz/PyObjC는 CLI/TUI와 HDR 기능에 필요하다. `worker.py`의 JSONL 모듈 실행
  계약도 호환성을 위해 유지한다.
- `input/`·`output/`의 개인 파일은 검사·정리 자료로 사용하지 않는다. 변환 검증은 임시 합성 이미지로 수행한다.
