# AGENTS.md

## PyPI 문서 언어

- PyPI에 표시되는 프로젝트 설명과 배포 메타데이터는 영어로 작성한다.
- `pyproject.toml`의 `description`과 `readme`가 가리키는 `README.pypi.md`는 영어로 유지한다. PyPI의 프로젝트 설명은 `README.pypi.md`를 사용한다.
- `README.md`와 `README.ko.md`는 앱 안내 문서이며 PyPI 설명과 분리한다. `README.pypi.md`에는 CLI/TUI의 기능·설치·사용·지원 환경·라이선스를 작성하고 앱 설치 안내는 넣지 않는다.
- CLI/TUI 기능을 변경할 때는 관련 앱 README와 `README.pypi.md`를 함께 검토하고 각 문서의 언어와 범위를 유지한다. 공개 저장소 링크는 `https://github.com/jaehunshin-git/heiccy`를 사용한다.
- 배포 전에 빌드된 wheel의 `METADATA`와 sdist의 `PKG-INFO`에서 `Summary` 및 본문 언어를 확인한다.
- 이미 게시된 PyPI 버전의 설명은 덮어쓸 수 없으므로 설명을 변경할 때 버전을 올리고 GitHub 태그·릴리즈와 일치시킨다.

## 배포 파일

- `input/`과 `output/`의 사진 및 개인 파일을 Git에 추가하거나 배포 파일에 넣지 않는다.
- sdist는 `pyproject.toml`의 `only-include` 허용 목록을 사용한다. 배포 전 sdist 목록을 확인해 개인 파일이 없는지 검증한다.
- sdist의 설명 파일은 `README.pypi.md`만 포함한다. 앱 README, 앱 빌드 파일 및 `docs/`는 포함하지 않으며 PyPI 설명의 문서 링크는 공개 저장소의 절대 URL을 사용한다.
