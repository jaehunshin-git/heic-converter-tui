# AGENTS.md

## PyPI 문서 언어

- PyPI에 표시되는 프로젝트 설명과 배포 메타데이터는 영어로 작성한다.
- `pyproject.toml`의 `description`과 `readme`가 가리키는 `README.md`는 영어로 유지한다. PyPI의 프로젝트 설명은 `README.md`를 사용한다.
- 한국어 사용 설명은 `README.ko.md`에 작성한다. 새 기능을 설명할 때 두 README의 내용을 함께 갱신하되 각 문서의 언어를 유지한다.
- 배포 전에 빌드된 wheel의 `METADATA`와 sdist의 `PKG-INFO`에서 `Summary` 및 본문 언어를 확인한다.
- 이미 게시된 PyPI 버전의 설명은 덮어쓸 수 없으므로 설명을 변경할 때 버전을 올리고 GitHub 태그·릴리즈와 일치시킨다.

## 배포 파일

- `input/`과 `output/`의 사진 및 개인 파일을 Git에 추가하거나 배포 파일에 넣지 않는다.
- sdist는 `pyproject.toml`의 `only-include` 허용 목록을 사용한다. 배포 전 sdist 목록을 확인해 개인 파일이 없는지 검증한다.
