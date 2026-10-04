# macOS 앱 빌드와 배포

기능 버전은 앱과 Python 패키지 모두 **0.3.0**이다. 이 문서는 배포 절차이며
버전 태그 생성이나 실제 게시 완료를 뜻하지 않는다. 기능 PR은 main에 머지하지
않은 상태로 검토한다. 릴리스와 PyPI 게시는 별도의 배포 작업이다.

## 빌드 환경

- Apple Silicon arm64, macOS 15 이상
- Swift 및 macOS SDK가 포함된 Xcode 또는 Command Line Tools
- `uv` 0.11.11
- 앱 worker: Python 3.12.12, `packaging/macos/requirements.lock`의 해시 고정 의존성

앱 패키징 의존성은 기본 CLI 의존성에 추가하지 않는다. 빌드 도구는 별도의
`.venv-app-build` 환경을 사용한다. CI는 Apple Silicon `macos-15`, `macos-26`에서
동일한 검증을 수행한다. 실행 OS와 아키텍처를 로그에 남기고 각 OS의 산출물을
구분한다. runner 목록은 [GitHub 공식 문서](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)를 기준으로 한다.

```bash
uv sync --group dev
uv run ruff check .
uv run pytest
swift build --package-path macos
swift test --package-path macos
bash packaging/macos/build.sh
uv build
uvx --from twine twine check dist/*.whl dist/*.tar.gz
.venv-app-build/bin/python packaging/macos/validate_python_dist.py dist
```

## 산출물과 검증

| 산출물 | 경로 |
| --- | --- |
| 앱 | `dist/macos/HEIC Converter.app` |
| arm64 DMG | `dist/macos/HEIC-Converter-0.3.0-arm64.dmg` |
| SHA-256 | 위 DMG 이름 뒤 `.sha256` |
| Python wheel 및 sdist | `dist/*.whl`, `dist/*.tar.gz` |

빌드는 PyInstaller onedir worker의 Python 런타임, Pillow, pillow-heif,
PyObjC와 네이티브 라이브러리를 앱에 포함한다. Swift 실행 파일, 고정
`Info.plist`, 생성한 아이콘, 프로젝트 및 제3자 라이선스만 추가한다. 앱 번들 ID는
`io.github.jaehunshin-git.heic-converter`, 최소 OS는 15다.

모든 Mach-O와 앱에 무료 ad-hoc 서명을 적용하고 arm64 아키텍처, 라이브러리 로더
경로, 서명을 검증한다. Python 동적 확장 모듈을 로드할 수 있도록 이 ad-hoc 앱에
hardened runtime을 적용하지 않는다. Apple Developer ID 서명 및 공증은 첫 범위에
포함하지 않는다.

`validate_app.py`는 번들 구조와 전수 네이티브 코드를 확인한다. `smoke_worker.py`는
합성 HEIC를 사용해 JPEG·PNG를 생성한다. 앱의 `--smoke-test`는 내장 worker의 실제
변환과 JSONL 인터페이스, 패널 표시·숨김·비활성화 시 유지 조건을 검증한다.
사용자의 Python 경로를 제외한 PATH와 임시 HOME을 사용한다. 이는 시스템의 Python을
삭제하는 검증 대신 사용자 Python 설치에 대한 실행 의존성을 확인하는 방법이다.

DMG는 앱 하나와 `/Applications` 바로가기로 구성한다. `validate_dmg.py`는 DMG를
읽기 전용으로 마운트하고 별도 임시 설치 위치에 복사한 앱에서 worker 및 앱 검증을
반복한다. 마운트는 검증 후 해제하고 체크섬을 확인한다.

```bash
cd dist/macos
shasum -a 256 -c HEIC-Converter-0.3.0-arm64.dmg.sha256
```

`validate_python_dist.py`로 wheel `METADATA` 및 sdist `PKG-INFO`의 버전,
영문 Summary와 본문, sdist 허용 목록을 확인한다. `input/`, `output/`, 개인 사진,
개발 환경 및 클립보드 데이터는 배포에 포함하지 않는다. 앱 프로젝트와 패키징 코드는
GitHub에서 관리하고 기존 Python sdist 허용 목록은 유지한다.

테스트 사진은 실행 중 합성한다. HDR 테스트는 ImageIO로 SDR 기본 이미지와 Apple
게인 맵을 생성하고 실제 네이티브 16비트 PNG, PQ ICC 프로파일 또는 CICP 색상 정보, 메타데이터 정책과
원본 보존을 확인한다. 일반 HEIC나 JPEG의 SDR 처리는 별도로 검증한다.
ICC와 CICP 모두 HDR 색상 표현에 유효하며 [Apple 설명](https://developer.apple.com/videos/play/wwdc2023/10181/)과
[PNG3 규격](https://www.w3.org/TR/png-3/)을 따른다. 실행 OS에 따라 ImageIO의 기록
형식이 다를 수 있다.

## 설치와 첫 실행

DMG의 체크섬을 검증한 뒤 앱을 Applications에 복사한다. 실행 차단 시 앱 실행을
시도한 다음 시스템 설정의 개인정보 보호 및 보안에서 이 앱을 확인 없이 열기로
허용한다. [Apple 공식 안내](https://support.apple.com/ko-kr/102445)를 따른다.
DMG 포장과 ad-hoc 서명은 공증이나 Gatekeeper 통과를 의미하지 않는다.

메뉴 막대 아이콘으로 패널을 열고 HEIC 파일을 드롭한다. 지금 변환 또는 대기 목록에
추가를 명시적으로 선택한다. 직접 붙여넣기와 백그라운드 감지는 로컬 파일 URL만
다룬다. 패널 숨기기는 작업 취소나 앱 종료가 아니다.

## 릴리스 절차

1. 최종 커밋에서 CI의 두 OS 검증을 통과시키고 산출물과 검증 로그를 확인한다.
2. 앱 `CFBundleShortVersionString`, `pyproject.toml`, wheel, sdist가 0.3.0인지 확인한다.
3. 릴리스 승인 후 해당 커밋에 `v0.3.0` 태그를 생성한다. 태그와 Python 버전을 일치시킨다.
4. 검증한 DMG와 체크섬을 GitHub Releases에 게시하고 wheel·sdist는 PyPI에 게시한다.
5. 다운로드한 파일의 체크섬과 설치본 실행을 재확인한다.

이미 게시한 PyPI 버전은 덮어쓰지 않는다. 설명 수정도 새 버전을 사용한다.
README.md와 PyPI 설명·메타데이터는 영어, README.ko.md와 추가 문서는 한국어다.
CI는 산출물 업로드까지 수행하며 PR 생성 과정에서 main 머지, 태그 또는 게시를 실행하지
않는다. Intel, Universal2, 로그인 자동 실행, 자동 업데이트, Homebrew Cask 및 Mac App
Store는 후속 범위다.

## 라이선스

프로젝트 소스는 MIT 라이선스다. 앱에 포함한 Python 및 제3자 라이브러리는 각자의
조건을 따른다. Pillow-heif binary wheel에는 GPL/LGPL 코덱 고지가 포함될 수 있다.
배포된 앱의 `Contents/Resources/Licenses`에서 해당 버전의 라이선스 전문, 고지와
소스 링크를 확인한다. 앱 배포 시 이 고지를 함께 제공한다.
