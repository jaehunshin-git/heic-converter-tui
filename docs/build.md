# Python 패키지 개발과 배포 검증

이 저장소는 `heic-converter-tui` 패키지와 `heic-converter` CLI/TUI를 관리한다.
macOS 앱·DMG는 `heiccy`가 담당한다. [제품별 분리 결정](decisions/2026-10-18-product-repository-split.md)과
[로컬 정리 결과·원격 적용 조건](python-only-cleanup.md)을 함께 확인한다.

## 개발 환경

Python 3.11 이상과 uv를 사용한다. macOS를 지원 대상으로 검증하며, HDR PNG는
macOS 15 이상의 Quartz/Image I/O와 PyObjC 경로를 사용한다. `service.py`는
CLI/TUI 공통 실행 계층이므로 유지한다. `python -m heic_converter.worker`도
기존 JSONL 호환 계약과 회귀 테스트를 유지한다.

```sh
uv sync --locked --group dev
uv run --locked ruff check src tests scripts
uv run --locked pytest
```

`uv.lock`에 고정한 의존성을 사용한다. 새 의존성을 도입할 때만 잠금을 갱신하고
관련 검증을 다시 수행한다. 테스트는 임시 합성 이미지를 생성하며 개인 사진을 쓰지 않는다.

## wheel과 sdist 검증

이전 버전의 배포 파일은 별도로 보관하고 빈 출력 폴더에서 빌드한다.

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
- CI는 PyPI 업로드나 macOS 앱·DMG 빌드를 실행하지 않는다.

[후속 공개 운영 결정](decisions/2026-10-18-python-repository-public.md)에 따라
이 저장소에는 Python 전용 CI를 반영한다. `heiccy`의 앱 CI 복구와 기본 브랜치 반영은
별도 후속 작업이며 이 저장소의 통과로 대체하지 않는다. 로컬 workflow 검사는 GitHub
실행 결과를 대신하지 않는다.

## 배포 경계

패키지명·실행 명령·의존성과 현재 버전 `0.3.0`은 정리 작업에서 바꾸지 않았다.
이는 새 배포가 완료됐다는 뜻이 아니다. 실제 배포 전 게시된 버전과 태그 상태를
확인하고 새 버전·태그·릴리스를 맞춘다. 이미 게시된 PyPI 설명은 다음 버전 배포에 반영한다.

Python 제품의 공개 소스·문서 창구는
[현재 저장소](https://github.com/jaehunshin-git/heic-converter-tui), 문의는
[이슈](https://github.com/jaehunshin-git/heic-converter-tui/issues)로 안내한다.
배포 메타데이터의 Homepage는 [PyPI 프로젝트](https://pypi.org/project/heic-converter-tui/)를 가리킨다.
과거 앱 문서는 [보관 폴더](archive/macos/README.md)에서 당시 기록으로 열람한다.
