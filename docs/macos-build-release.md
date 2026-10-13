# macOS 앱 빌드와 배포

macOS 앱의 표시 이름은 **heiccy**이며, 현재 앱과 Python 패키지 버전은 **0.3.0**이다. 앱 버전의 기준은
`packaging/macos/Info.plist`, Python/PyPI 버전의 기준은 `pyproject.toml`이며 독립적으로 관리한다.
이슈 #7의 자동 클립보드 기능은 소스 변경이며 아직 릴리스하지 않았다. 이 문서는 배포 절차이며
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

테스트에는 XCTest가 포함된 Xcode 개발자 디렉터리를 사용한다. `xcode-select -p`가
Command Line Tools를 가리키면 아래처럼 해당 셸에서만 Xcode 경로를 지정한다.
Xcode를 다른 위치에 설치했다면 경로를 그에 맞춘다.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

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
| 앱 | `dist/macos/heiccy.app` |
| arm64 DMG | `dist/macos/heiccy-0.3.0-arm64.dmg` |
| SHA-256 | 위 DMG 이름 뒤 `.sha256` |
| Python wheel 및 sdist | `dist/*.whl`, `dist/*.tar.gz` |

빌드는 PyInstaller onedir worker의 Python 런타임, Pillow, pillow-heif,
PyObjC와 네이티브 라이브러리를 앱에 포함한다. Swift 실행 파일, 고정
`Info.plist`, 생성한 아이콘, 프로젝트 및 제3자 라이선스만 추가한다. 앱 번들 ID는
`io.github.jaehunshin-git.heic-converter`, 최소 OS는 15다. 앱과 패널의 표시 이름은 `heiccy`이며 내부 실행 파일 `HEICConverter`는 유지한다. PyPI 패키지·CLI 이름과 기존 `~/Pictures/HEIC Converter` 출력 폴더도 유지한다.

모든 Mach-O와 앱에 무료 ad-hoc 서명을 적용하고 arm64 아키텍처, 라이브러리 로더
경로, 서명을 검증한다. Python 동적 확장 모듈을 로드할 수 있도록 이 ad-hoc 앱에
hardened runtime을 적용하지 않는다. Apple Developer ID 서명 및 공증은 첫 범위에
포함하지 않는다.

`validate_app.py`는 번들 구조와 전수 네이티브 코드를 확인한다. `smoke_worker.py`는
합성 HEIC를 사용해 JPEG·PNG를 생성한다. 앱의 `--smoke-test`는 내장 worker의 실제
변환과 JSONL 인터페이스, 패널 표시·숨김·비활성화 시 유지 조건을 검증한다.
사용자의 Python 경로를 제외한 PATH와 임시 HOME을 사용한다. 이는 시스템의 Python을
삭제하는 검증 대신 사용자 Python 설치에 대한 실행 의존성을 확인하는 방법이다.

DMG 볼륨 이름은 `heiccy`이며, `heiccy.app` 하나와 `/Applications` 바로가기로 구성한다. `validate_dmg.py`는 DMG를
읽기 전용으로 마운트하고 `diskutil info -plist`로 실제 볼륨 이름이 `heiccy`인지 확인한 뒤
별도 임시 설치 위치에 복사한 앱에서 worker 및 앱 검증을
반복한다. 마운트는 검증 후 해제하고 체크섬을 확인한다.

DMG 생성은 OS 버전·빌드 번호·아키텍처와 `hdiutil create -verbose` 출력을
기록한다. 검증은 파일 경로·크기·예상/실제 SHA-256을 먼저 기록한 뒤
`hdiutil verify -verbose`로 이미지 내부 체크섬을 검사한다. verify·attach·detach의
명령, 종료 코드, stdout과 stderr를 로그에 남기며 attach의 원본 stdout은
별도로 plist 파싱에 사용한다. 외부 체크섬이나 hdiutil 검증 실패 시 즉시 중단하며
자동 재시도하거나 설치 검증으로 우회하지 않는다.

2026-10-07 KST의 [push 실행 37491932847](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/37491932847)은
macOS 26의 `hdiutil verify -quiet`에서 exit 1로 실패했다. 같은 HEAD
`fd07bb1`의 [PR 실행 37491939634](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/37491939634)는
두 OS에서 성공했다. macOS 26.6.2와 runner 이미지 버전은 같지만 PR 실행은
GitHub의 임시 merge 커밋을 체크아웃했다. 기존 quiet 로그에는 구체적인 실패 사유가
없으므로 이미지 손상이나 runner 상태 문제로 단정할 수 없다. 위 변경은 실패 원인을
진단할 근거를 보존하는 개선이며, 해당 CI 실패가 재발하지 않는다는 검증은 아니다.

```bash
cd dist/macos
shasum -a 256 -c heiccy-0.3.0-arm64.dmg.sha256
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

기능이 켜져 있으면 HEIC를 복사한 뒤 변환 완료를 기다리고 기존 ⌘V로 붙여넣는다.
좌클릭 패널은 현재 클립보드와 켜기/끄기를, 우클릭 메뉴는 별도 설정 창과 종료를 제공한다.
패널 숨기기는 작업 취소나 앱 종료가 아니다. 정상 종료는 앱이 게시한 내용만 원본으로 복구한다.
자세한 입력 계약과 미검증 수신 앱 동작은 [자동 클립보드 문서](macos-auto-clipboard.md)를 따른다.

## 기존 앱에서 heiccy로 교체

이름 변경 전 `HEIC Converter.app`과 새 `heiccy.app`은 파일 이름이 달라 드래그 설치만으로
교체되지 않는다. 기존 앱의 메뉴바 메뉴에서 정상 종료해 앱이 게시한 클립보드의 복구와
임시 파일 정리를 마친다. 기존 번들은 Applications 밖의 백업 위치로 옮겨 복구 경로를
유지하고 새 `heiccy.app`을 설치한 뒤 해당 경로의 앱을 직접 연다. 두 번들을 동시에
실행하지 않는다. 이전 빌드로 돌아갈 때도 새 앱을 먼저 정상 종료한다.

번들 ID `io.github.jaehunshin-git.heic-converter`와 UserDefaults 키 `converter.settings`는
유지하며 새 설정 도메인이나 데이터 이동을 만들지 않는다. 저장한 형식·품질·압축·메타데이터,
사용자가 정한 레거시 출력 경로와 충돌 정책은 기존 값을 읽는다. 일시정지는 실행 중에만
적용되므로 이전 앱에서 일시정지했어도 새 앱 실행 시 자동 변환은 켜진다.

설치 검증은 빈 임시 디렉터리의 앱 실행과 기존 설정 승계를 구분한다. 기존 검증 스크립트의
임시 설치 성공만으로 사용자의 Applications 교체나 실제 설정 도메인 승계가 검증됐다고
기록하지 않는다.

## 릴리스 절차

1. 최종 커밋에서 CI의 두 OS 검증을 통과시키고 산출물과 검증 로그를 확인한다.
2. 앱 릴리스는 `Info.plist`의 버전과 DMG 이름·체크섬을 일치시킨다. Python 릴리스는
   `pyproject.toml`, wheel·sdist의 버전을 별도로 확인한다.
3. 앱 전용 릴리스 태그는 `macos-v<앱 버전>`, Python 릴리스 태그는 `v<Python 버전>`을 사용한다.
   태그와 릴리스·배포는 사용자 승인 후 진행한다.
4. 앱 전용 변경은 검증한 DMG·체크섬만 GitHub Releases에 게시한다. PyPI 업로드는
   Python 패키지 릴리스 때만 수행한다. 게시된 PyPI 설명 변경은 별도의 새 Python 버전이 필요하다.
5. 다운로드한 파일의 체크섬과 설치본 실행을 재확인한다.

이미 게시한 PyPI 버전은 덮어쓰지 않는다. 설명 수정도 새 버전을 사용한다.
README.md와 PyPI 설명·메타데이터는 영어, README.ko.md와 추가 문서는 한국어다.
이번 PR에 추가하는 브랜딩 문서·이미지는 상대 경로로 연결해 PR 브랜치에서도 확인할 수 있게 한다.
sdist에서 제외되는 기존 빌드·지원 안내는 공개된 GitHub 절대 URL을 유지한다.
새 Python 패키지를 PyPI에 게시하기 전에는 해당 설명의 문서·이미지 링크가 PyPI에서
해결되는지 확인한다. 상대 경로를 사용하는 GitHub README를 그대로 게시하지 말고
공개 절대 URL로 변환한 설명이나 별도 영어 PyPI 설명 파일을 준비·검증한다.
설명 분리와 배포 설정 조정은 후속 이슈 #13의 범위다.
CI는 산출물 업로드까지 수행하며 PR 생성 과정에서 main 머지, 태그 또는 게시를 실행하지
않는다. Intel, Universal2, 로그인 자동 실행, 자동 업데이트, Homebrew Cask 및 Mac App
Store는 후속 범위다.

## 라이선스

프로젝트 소스는 MIT 라이선스다. 앱에 포함한 Python 및 제3자 라이브러리는 각자의
조건을 따른다. Pillow-heif binary wheel에는 GPL/LGPL 코덱 고지가 포함될 수 있다.
배포된 앱의 `Contents/Resources/Licenses`에서 해당 버전의 라이선스 전문, 고지와
소스 링크를 확인한다. 앱 배포 시 이 고지를 함께 제공한다.

고정된 pillow-heif 1.1.1 wheel의 `LICENSES_bundled.txt`에는 이전 코덱의 소스
링크가 남아 있다. 수집 스크립트는 `libheif_info()`의 실제 버전을 아래 목록과
대조한 뒤, 라이선스 표기는 유지하면서 버전과 소스·라이선스 링크를 보정한다.
AVIF/libaom이 없는 현재 wheel에서는 이전 libaom 항목을 제외한다. wheel 버전이나
코덱 구성이 달라지면 빌드를 실패시켜 고지를 다시 확인하도록 한다.

| 코덱 | 실제 버전 | 공식 소스 |
| --- | --- | --- |
| libheif | 1.20.2 | [v1.20.2](https://github.com/strukturag/libheif/tree/v1.20.2) |
| libde265 | 1.0.16 | [v1.0.16](https://github.com/strukturag/libde265/tree/v1.0.16) |
| x265 | 4.1+1-1d117be | [1d117bed4747758b51bd2c124d738527e30392cb](https://github.com/Multicorewareinc/x265/tree/1d117bed4747758b51bd2c124d738527e30392cb) |

이 대조는 번들 버전과 고지 링크의 정확도를 확인하는 절차이며, 배포의 모든
라이선스 의무를 충족했다는 법률 판단을 대신하지 않는다.
