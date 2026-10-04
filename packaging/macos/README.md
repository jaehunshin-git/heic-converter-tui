# macOS 앱 빌드와 패키징

Apple Silicon arm64, macOS 15 이상이 대상이며 기능 버전은 0.3.0이다. 실행 시 사용자의 Python, Homebrew, uv 또는 pip를 호출하지 않는다. Swift 실행 파일이 `Contents/Resources/worker/heic-worker`를 `Process`로 직접 실행한다.

## 고정 환경

빌드에는 Xcode Command Line Tools 또는 Xcode의 Swift 도구와 uv 0.11.11이 필요하다. `build.sh`가 CPython 3.12.12와 `.venv-app-build`를 생성한다. `requirements-pins.txt`에 모든 직접·전이 의존성 버전을 고정했고 `requirements.lock`은 배포 파일 SHA-256을 함께 고정한다. 빌드 시 `uv pip sync --require-hashes`로 잠금 파일을 적용한다. 앱 빌드 도구는 기존 CLI 기본 설치 의존성에 추가하지 않는다.

의존성을 갱신할 때 고정 버전 목록을 편집한 뒤 같은 arm64 Python 환경에서 잠금 파일을 다시 생성한다.

```sh
uv pip compile --python .venv-app-build/bin/python \
  --python-platform aarch64-apple-darwin --generate-hashes \
  packaging/macos/requirements-pins.txt -o packaging/macos/requirements.lock
bash packaging/macos/build.sh
```

`requirements.in`은 주요 도구의 선정 버전을 기록한 참고 목록이며 실제 설치에는 전체 버전과 해시가 고정된 `requirements.lock`만 사용한다.

## 조립 및 검증

1. PyInstaller onedir에 Python, Pillow, pillow-heif, PyObjC의 objc/Foundation/Quartz와 필요한 네이티브 코덱을 수집한다.
2. Swift Package의 arm64 릴리스 실행 파일을 빌드하고 `Info.plist`, 생성 아이콘과 라이선스 고지를 명시적으로 복사한다. 프로젝트 루트나 사진 폴더 전체를 복사하지 않는다.
3. Mach-O 파일과 중첩 프레임워크, 앱을 안쪽부터 무료 ad-hoc 서명한다. PyInstaller의 기본 runtime 서명은 무료 ad-hoc 환경에서 Python 라이브러리 로드에 실패할 수 있어 모든 코드를 hardened runtime 없이 다시 서명한다.
4. 모든 Mach-O의 arm64 아키텍처, 상대 로더 경로, 최소 OS 버전과 ad-hoc 서명, 앱 버전과 허용 목록을 검사한다.
5. 임시 폴더에 합성한 HEIC를 사용해 사용자 Python이 없는 PATH에서 JPEG와 PNG 변환을 확인한다. 앱 `--smoke-test`도 내장 worker 연결을 확인한다.
6. 앱과 `/Applications` 심볼릭 링크만 담은 DMG를 만들고 SHA-256을 생성한다. 읽기 전용으로 마운트한 뒤 임시 설치 복사본의 앱과 worker를 다시 실행한다.

산출물은 다음과 같다.

- `dist/macos/HEIC Converter.app`
- `dist/macos/HEIC-Converter-0.3.0-arm64.dmg`
- `dist/macos/HEIC-Converter-0.3.0-arm64.dmg.sha256`

별도 검증은 다음 명령으로 재실행할 수 있다.

```sh
.venv-app-build/bin/python packaging/macos/validate_app.py 'dist/macos/HEIC Converter.app'
.venv-app-build/bin/python packaging/macos/validate_dmg.py dist/macos/HEIC-Converter-0.3.0-arm64.dmg
.venv-app-build/bin/python -m build --no-isolation
.venv-app-build/bin/python packaging/macos/validate_python_dist.py dist
```

wheel과 sdist는 버전 0.3.0, 지정 경로 허용 목록, 영어 Summary와 README 본문을 검사한다. Hatch가 자동 포함하는 루트 `.gitignore`와 `PKG-INFO`는 sdist 허용 목록에 포함한다. 사진, 개발 환경, Swift 앱 소스와 패키징 소스는 Python 배포 파일에 포함하지 않는다.

## 설치와 배포

DMG를 열고 HEIC Converter를 Applications로 드래그한다. 첫 실행이 차단되면 한 번 실행을 시도한 뒤 시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기로 허용한다. ad-hoc 서명과 DMG는 Developer ID 서명·공증이나 Gatekeeper 신뢰를 제공하지 않는다. 이 버전은 Developer ID 서명과 공증을 수행하지 않는다.

`.github/workflows/macos.yml`은 Apple Silicon `macos-15`와 `macos-26`에서 Python 검사, Swift 검사, 앱/worker/DMG 설치본 실행과 Python 배포 파일 검증 후 CI 아티팩트를 업로드한다. PR에서 릴리스를 게시하거나 main에 머지하지 않는다. 배포 담당자는 모든 검증을 통과한 `v0.3.0` 태그의 DMG와 체크섬을 GitHub Releases에 올리고 같은 버전의 wheel과 sdist를 PyPI에 새로 게시한다. 이미 게시된 PyPI 메타데이터를 덮어쓰지 않는다.

자동 smoke 검증은 설치한 worker의 실제 변환과 앱의 프로토콜 연결을 확인한다. 메뉴 막대, 드롭, 접근 권한, 클립보드와 패널 동작의 대화형 검증은 별도로 수행한다. 로컬 OS에서 성공한 결과를 macOS 15 실기 검증으로 기록하지 않는다.
