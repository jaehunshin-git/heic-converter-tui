# Python 패키지 개발과 배포 검증

이 저장소는 `heic-converter-tui` 패키지와 `heic-converter` CLI/TUI를 관리한다.
사용법은 [README](../README.md), 모듈 실행 인터페이스는
[worker JSONL 계약](worker-protocol.md)을 확인한다.

## 개발 환경

Python 3.11 이상과 uv를 사용한다. macOS를 지원 대상으로 검증하며, HDR PNG는
macOS 15 이상의 Quartz/Image I/O와 PyObjC 경로를 사용한다. `service.py`는
CLI/TUI 공통 실행 계층이므로 유지한다. `python -m heic_converter.worker`도
JSONL 호환 계약과 회귀 테스트를 유지한다.

```sh
uv sync --locked --group dev
uv run --locked ruff check src tests scripts
uv run --locked pytest
```

`uv.lock`에 고정한 의존성을 사용한다. 새 의존성을 도입할 때만 잠금을 갱신하고
관련 검증을 다시 수행한다. 테스트는 임시 합성 이미지를 생성하며 개인 사진을 쓰지 않는다.

## wheel과 sdist 검증

이전 빌드 결과물이 섞이지 않도록 비어 있는 출력 폴더에서 빌드한다.

```sh
uv build --out-dir dist/python
uv run --locked python scripts/validate_python_dist.py dist/python
```

검증기는 `pyproject.toml`의 이름·버전, wheel의 `METADATA`와 sdist의 `PKG-INFO`,
영문 설명, 배포 허용 목록을 확인한다. wheel에는 `heic_converter`와 배포 메타데이터만,
sdist에는 `src/`, `tests/`, `pyproject.toml`, `README.pypi.md`, `LICENSE`와
빌드 도구가 만드는 메타데이터만 허용한다. 앱·문서·개인 입력·출력은 배포하지 않는다.

배포 전에는 저장소 밖의 별도 가상환경에 wheel을 설치하고 `heic-converter --help`와
합성 HEIC의 JPEG·PNG 변환을 확인한다. sdist도 별도 임시 폴더에 풀어 테스트한다.
sdist에는 개발용 `scripts/`가 없으므로 `HEIC_CONVERTER_TEST_SDIST=1`을 지정하면
검증기 관련 테스트만 건너뛴다. Git 훅 테스트도 도구가 없는 sdist에서 건너뛴다.
원본 checkout에서는 검증기 누락을 허용하지 않는다.

## CI와 artifact 보관

`.github/workflows/python.yml`은 기본 브랜치 push, PR, `v*` 태그, 수동 실행에서
Python 테스트와 배포 파일 검증을 수행한다. macOS 15/Python 3.11과
macOS 26/Python 3.12.12를 검증한다. 두 환경 모두 ARM64인지 확인한다.

- 일반 push·PR에서는 artifact를 업로드하지 않는다.
- 수동 실행은 macOS 15에서 만든 wheel/sdist 한 묶음만 3일 보관한다.
- `v*` 태그 push는 같은 한 묶음만 14일 보관한다.
- 실제 PyPI 게시 절차는 별도로 수행한다.

로컬 workflow 검사는 GitHub 실행 결과를 대신하지 않는다. 배포 전에는 해당
커밋의 두 CI 환경에서 테스트와 배포 파일 검증이 성공했는지 확인한다.

## 배포 경계

패키지명·버전은 `pyproject.toml`을 기준으로 확인한다. 실제 배포 전 게시된 버전과
태그 상태를 확인하고 새 버전·태그·릴리스를 맞춘다. 설명·메타데이터 변경은
다음 버전의 PyPI 배포에 반영한다. 로컬 빌드만으로 새 배포 완료를 선언하지 않는다.

Python 제품의 공개 소스·문서 창구는
[현재 저장소](https://github.com/jaehunshin-git/heic-converter-tui), 문의는
[이슈](https://github.com/jaehunshin-git/heic-converter-tui/issues)로 안내한다.
배포 메타데이터의 Homepage는 [PyPI 프로젝트](https://pypi.org/project/heic-converter-tui/)를 가리킨다.
