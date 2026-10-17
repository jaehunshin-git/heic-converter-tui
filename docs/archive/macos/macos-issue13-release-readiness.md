> 과거 macOS 앱 기록입니다. 현재 Python 제품의 안내·배포 절차가 아닙니다. [보관 기준](README.md)

# 이슈 #13 배포 준비와 검증 기록

> 이 문서의 결정·완료 범위는 당시 검증 이력으로 보존한다.
> 현재 제품별 담당 저장소는 2026-10-18 [분리 운영 결정](../../decisions/2026-10-18-product-repository-split.md)을
> 따른다. 과거 결과를 코드·CI 분리 완료의 근거로 사용하지 않는다.

## 현재 결정과 완료 범위 (2026-10-13)

- 공개 저장소는 `jaehunshin-git/heiccy`이며 소스·문서·사용자 이슈를 제공한다.
  최초 이전은 별도 Git 이력이다. 기존 내부 이슈·PR·전체 이력은 이전하지 않는다.
- 공식 DMG 채널은 GitHub Releases, 앱 최초 공개 태그는 `v1.0.0`이다.
  개발 태그 `macos-v1.0.0`과 Python 태그 `v<Python 버전>`은 구분한다.
- 앱 1.0.0과 Python 0.3.0의 릴리스는 독립적이다. PyPI 이름과 실행 명령은 유지한다.
- ad-hoc 서명과 미공증 첫 실행 안내를 제공한다. Developer ID·Apple 공증은 미적용이다.
- 사용자는 남은 작업을 재개하고 **Free로 Private 전환, 보호 제한 수용·수동 배포**를
  선택했다. 개발 저장소는 Private로 전환했고 공개 `heiccy`는 Public이다.
  main 보호 규칙·`public-release` environment의 Free Private 제한을 수용한다.
  전환 전 설정은 로컬에 백업했다.
- `HEICCY_RELEASE_ENABLED=false`를 유지하고 `HEICCY_RELEASE_TOKEN` secret을 삭제했다.
  사용자는 `heiccy-release` PAT를 직접 삭제했다고 확인했다. 로그인된 GitHub CLI로
  수동 배포하며, main 머지 전에는 개발·공개 태그와 초안 릴리스를 만들지 않는다.
- PR #16은 사용자가 직접 검토·머지한다. #5는 완료 범위에 맞춰 `Closes #5`,
  #13은 태그 CI·게시·공개 다운로드 검증이 남으므로 `Refs #13`을 유지한다.

## 요구사항별 상태

| #13 범위 | 확인한 결과 | 남은 범위 |
| --- | --- | --- |
| 채널·저장소·이전 정책 | GitHub Releases, 공개 `heiccy`, 별도 소스 이력, 독립 PyPI 운영 확정 | 없음 |
| 소스·라이선스 이전 | 공개 소스·영문 LICENSE·한국어 이용 조건·제3자 고지·대응 소스 수집 구현. 내부 workflow·사진·개발 문서 제외. 공개 사본 테스트 433건·131개 파일 해시·상대 링크 21개 확인 | 최종 출처 SHA 동기화 결과는 PR에서 기록 |
| 버전·메뉴·아이콘·설정 | 앱 1.0.0·Python 0.3.0, #5 실기 범위, CI 설치본의 실제 변환·Applications 교체·설정 승계 확인 | 이번 CI 설치본 자체의 메뉴바 좌·우 클릭은 미검증. 기존 빌드 사용자 확인과 구분 |
| CI와 수동 게시 | macOS 15·26 검증, macOS 15 원본 선택, manifest·SHA 검사, main 포함·태그 검사 구현. 수동 CLI 절차 작성, 자동 게시 비활성 | main 머지 후 실제 태그 실행·CLI 초안 생성과 공개 게시 미검증 |
| README·첫 실행·릴리스 노트 | 영어·한국어 앱 안내, macOS 15+ arm64, ad-hoc·미공증·업데이트 안내 작성 | 공개 릴리스 다운로드와 Gatekeeper 차단·허용 실기 미검증 |
| 공개 URL·기존 CLI | 새 안내·메타데이터의 공개 URL, 기존 로컬 origin·CLI 이름 유지 | 이미 게시된 PyPI 0.2.8의 이전 URL은 다음 독립 Python 릴리스 전까지 유지 |
| PyPI 설명·배포 파일 | 영어 README.pypi.md 분리, wheel METADATA·sdist PKG-INFO 0.3.0과 포함 목록 검사 통과 | 새 Python 버전의 PyPI 업로드는 이번 앱 작업과 별도 |
| 다운로드·설치·업그레이드 | 인증된 CI artifact의 SHA·/Applications 설치·실행·Finder 실제 변환·구 앱 교체·재실행 통과 | 비인증 공개 DMG 다운로드와 브라우저 격리 속성을 포함한 첫 실행은 게시 전으로 미검증 |
| Private 전환 | Free 제약 수용·설정 백업·Private 전환 완료. 비인증 개발 코드·이슈·PR HTTP 404, 공개 소스 HTTP 200. 전환 후 PR·push의 macOS 15·26 CI 성공 | 공개 DMG 경로는 main 머지·수동 게시 후 검증 |

## CI 산출물의 출처와 자동 검사

Private 전환 후 main의 PR #17과 충돌 정리를 포함한 커밋
`86bda5c7517c66770c70bbebae53bc1669ccfa72`에서
[PR CI 38382488358](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38382488358)와
[push CI 38382483705](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38382483705)의
macOS 15·26이 모두 성공했다. 자동 게시 job은 skipped였고 태그·릴리스는 생성하지 않았다.
아래 설치 실기에는 이전 CI 앱을 사용했으며 이 새 실행의 설치 실기로 바꾸지 않는다.

[PR CI 실행 38372615579](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38372615579)와
[push CI 실행 38372608171](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38372608171)은
브랜치 HEAD `4f0a0ab5ff3d4365b8d9d21c27c2ae34b9f4f31a`에서 두 OS 모두 성공했다.
게시 job은 실행하지 않았다. 이번 실기는 PR CI의 `heiccy-macos-15-arm64`를
인증된 GitHub CLI로 내려받아 수행했다.

PR manifest의 원본 SHA는 합성 머지 커밋
`db06939e7d6c7f4f13e855cf8410447f84b11324`다. 부모는 main `5ffb908`와
브랜치 HEAD `4f0a0ab`이며 두 원본 트리는
`7b5a851f622c2351d8c2d45cd903ad5ce8378d73`으로 일치했다.
이는 PR 검증용 커밋이며 실제 main 머지나 태그 릴리스의 증거는 아니다.

- DMG SHA-256: `21f28b7b9300ce574c6de6c7b1bf54375835fd304618a3d2a2943df0441eeaac`.
- 코덱 소스 SHA-256: `d47ef7bcf29a2f061604478581a1f222943e976ef22f95fcdda2a6c861f17b67`.
- `verify_release.py`의 manifest 구조·두 파일의 체크섬 검사를 통과했다.
- 함께 받은 CI wheel/sdist도 0.3.0·허용 목록·영어 PyPI 설명 검사를 통과했다.
- `validate_dmg.py`로 외부 SHA-256, hdiutil 내부 검증, 읽기 전용 마운트, 볼륨 이름,
  파일 허용 목록, `/Applications` 링크, 임시 설치 복사본을 재검증했다.
- Mach-O 44개의 arm64·로더·ad-hoc 서명, 사용자 Python 없는 PATH/HOME에서
  합성 HEIC JPEG·PNG와 지원 HDR 16비트 PQ worker 변환, 앱 smoke가 통과했다.

## 실제 설치·입력·업그레이드

실기 환경은 로컬 macOS 27.2 (`26B5101f`), arm64, 어두운 외관, Retina 2x다.
macOS 15에서 빌드한 산출물을 검사했지만 macOS 15 실기 결과로 기록하지 않는다.

1. 검증 시작 시 `/Applications`에 두 앱 모두 없었다. 기존 실행 앱을 정상 종료하고
   읽기 전용 CI DMG의 `heiccy.app`을 `ditto`로 `/Applications`에 복사했다.
2. 서명 무결성과 `/Applications/heiccy.app/Contents/MacOS/HEICConverter` 프로세스를
   확인하고 컴퓨터 제어 도구로 실제 패널·설정 창을 관찰했다. 첫 도구 연결은
   timeout이었지만 같은 설치본의 재연결은 성공했다.
3. Finder에서 합성 HEIC 24×16을 `⌘C`로 복사했다. 설치 앱 패널에 JPEG 변환 완료·
   붙여넣기 준비 상태가 표시됐고, 별도의 빈 검증 폴더에 `⌘V`로 붙여넣었다.
   실제 JPEG 디코딩·크기 24×16과 SHA-256을 확인했다.
4. 정상 종료 후 클립보드가 검증 원본 HEIC로 돌아온 것을 확인했다. 검증 전 원문은
   저장소 밖 0600 스냅샷으로 보존했으며 세대 검사 후 원래 항목·타입·바이트를
   복구하고 `compare equal`을 확인했다. 원문은 Git·문서·공개 소스에 넣지 않았다.
5. 기존 개발 폴더의 구 앱 0.3.0을 `/Applications/HEIC Converter.app`에 복사해 실제
   설정 창을 확인하고 정상 종료했다. 복사본을 Applications 밖에 백업하고 CI 1.0.0
   앱으로 교체한 뒤 같은 설정을 확인했다.
6. 교체한 CI 앱을 정상 종료·재실행한 뒤 설정 UI를 다시 확인했다. 실제 사용자
   기본설정 도메인의 전체 저장 바이트는 설치 전·첫 실행 후·교체 및 재실행 후 동일했다.
   옵션을 변경하거나 기본값 복원을 누르지 않았다.

현재 `/Applications/heiccy.app`은 이 검증의 CI 설치본이다. 원래 개발 폴더의 구 앱과
새 앱은 보존했다. 실제 창 캡처 5개와 해시는
[CI 설치 증거](assets/branding/verification/2026-10-13-ci-install/evidence.json)에 기록했다.
기존 설치 원본을 덮어쓴 것은 아니며, 보존한 구 앱의 복사본으로 설치 교체를 검증했다.

CLI로 받은 설치본에는 `com.apple.quarantine`이 없었다. 보안 속성을 제거하지 않았고
Gatekeeper 차단·확인 없이 열기 경로는 검증하지 않았다. 이 결과를 공개 다운로드·
미공증 앱의 최초 브라우저 설치 성공으로 확대하지 않는다. 이번 CI 설치본의 상태
아이콘 직접 조작도 수행하지 않았으며 #5의 사용자 실기 확인과 분리한다.

## 공개 소스·링크와 Private 전환

추가 문서 변경 전 공개 커밋 `c62154d`의 raw README·SOURCE.json·codeload ZIP은
비인증 HTTP 200이었다. SOURCE.json의 109개 파일 해시는 전부 일치했고 공개 안내의
상대 링크도 누락이 없었다. 이후 문서·검증 증거 동기화는 기존 태그나 DMG 게시 없이
수행하며 최종 파일 수·공개 커밋·비인증 해시 결과를 PR 본문에 기록한다.

현재 게시된 PyPI 0.2.8의 wheel·sdist는 비인증 다운로드와 SHA-256 검사를 통과했다.
그러나 Homepage·Repository·Issues는 이전 개발 저장소를 가리킨다. 새 0.3.0 소스
메타데이터는 이미 공개 URL을 사용하며 기존 버전의 URL에 소급 적용되지 않는다.
Private 전환 후 이전 개발 저장소 URL은 비인증 사용자에게 HTTP 404다.
기존 PyPI 버전의 오래된 링크는 변경할 수 없으며 새 독립 Python 릴리스에서 갱신한다.

GitHub Free에서는 Private 저장소의 보호 규칙과 environment를 현재 방식으로
유지할 수 없다. 사용자가 이 제한을 수용해 개발 저장소를 Private로 전환했다.
API의 private=true·visibility=private와 공개 저장소의 private=false를 확인했다.
Authorization 헤더 없는 요청에서 개발 저장소·이슈 #13·PR #16·raw README·저장소
API가 모두 HTTP 404였고, 공개 저장소·raw README·SOURCE.json은 HTTP 200이었다.
Private 전환 후 두 OS CI는 위 통합 커밋에서 성공했다. 공개 DMG 다운로드는 미검증이다.
근거와 수동 배포 순서는 [운영 문서](macos-build-release.md)와
[수동 릴리스 절차](macos-manual-release.md)에 기록한다.

공개 커밋 `a2307b268ad8dba2fd121827c8af70895190f292`은 개발 통합 커밋 `86bda5c`에
대응한다. 비인증 codeload ZIP HTTP 200에서 131개 파일 해시가 SOURCE.json과 모두
일치했고 공개 문서의 상대 링크 21개를 확인했다. 독립 공개 사본의 Python 테스트
433건이 통과했다. 공개 훅 5개 경로를 정확히 허용하며 다른 scripts·숨김 파일은
추가 허용하지 않는다. 후속 내부 문서 커밋의 출처 동기화는 PR에 기록한다.

## 앞선 검증 이력

- main의 PR #17 통합 후 Python 전체 433건·Ruff 0.14.4·diff 공백 검사 통과.
  공개 훅의 실제 설치·메시지 차단, 커밋 내용·실행 권한·해시 보존을 포함한다.
  workflow·릴리스 운영 문서의 충돌 두 곳을 해소하고 기존 push·PR CI 트리거를 유지했다.
- Python 295건·Swift ConverterKit 76건·앱 XCTest 직접 실행 47건·클립보드 진단 14건 통과.
- Ruff 0.14.4, wheel/sdist 0.3.0의 영어 Summary·설명·허용 목록 검사 통과.
- sdist 내부 검사 111건 통과·66건 skip, 최초 공개 소스 snapshot 테스트 281건 통과.
- 원본 5개의 다운로드·해시·tar·필수 파일·x265 원본 대조와 코덱 source bundle 생성 통과.
  동일 wheel 재빌드·수정 라이브러리 교체 및 전체 런타임 라이선스 검증은 미완료다.
- 공개 root commit `3685491`에서 109개 파일과 SOURCE.json을 게시한 뒤 `c62154d`에서
  공개 문서 링크를 보완했다. 과거 커밋의 파일 수와 출처 SHA는 당시 기록이다.
- 과거 사용자가 토큰 등록 완료를 알렸고 API에서 environment secret 이름
  `HEICCY_RELEASE_TOKEN`의 존재만 확인했다. 값은 읽거나 출력하지 않았다.
- 게시 변수는 초기에 `true`였으나 사용자 보류 지시 후 `false`로 바꿨다.
  현재 상태는 위 결정 사항을 따른다.
- Private 전환 전에 environment secret을 삭제하고 API에서 빈 목록을 확인했다.
  PAT 삭제 자체는 사용자 확인이며 자동 검증 결과로 바꾸지 않는다.
- #5의 밝은·어두운 패널·아이콘·사용자 메뉴바 확인·이름 조사·설정 승계와 한계는
  [브랜딩 검증 문서](macos-branding.md)에서 독립적으로 관리한다.
- 이번 문서 갱신 후 공개 exporter·릴리스·패키징 회귀 검사 122건,
  로컬 문서 링크 38개와 실제 캡처·렌더 PNG 12개 해시 검사를 통과했다.

로그·DMG·개인 기본설정 백업·진단 스냅샷·구 앱 백업은 Git에 추가하지 않는다.
DMG 게시·공개 다운로드 전에는 원격 상태와 권한을 다시 확인하고 해당 경로를
실제 검증한다. 개발 저장소 Private 전환 자체는 완료했다.
