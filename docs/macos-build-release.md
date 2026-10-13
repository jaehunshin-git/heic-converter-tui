# heiccy 개발 저장소의 릴리스 운영

## 확정한 정책

- 개발 기준: `jaehunshin-git/heic-converter-tui`. 내부 이슈·PR과 전체 이력 유지.
- 공개 저장소: `jaehunshin-git/heiccy`. 릴리스별 소스·사용 안내·사용자 이슈·DMG 제공.
- 최초 공개 이전은 새로운 Git 이력으로 시작하며 내부 이슈·PR과 개인 파일은 제외.
- 공식 설치 파일은 GitHub Releases. Homebrew Cask·Mac App Store는 후속 범위.
- 앱 첫 버전 `1.0.0`, Python 소스 버전 `0.3.0`. 패키지 이름·명령 호환성 유지.
- ad-hoc 서명·미공증 안내 제공. Developer ID 도입 요건은 [빌드 안내](build.md) 참고.

빌드·설치·입력 범위는 [빌드 안내](build.md), [호환성 안내](compatibility.md),
[코덱 대응 소스 안내](third-party-sources.md)에서 관리한다.
공개 exporter는 이 문서와 과거 내부 검증 기록을 복사하지 않는다.

## 현재 선택과 보류 상태 (2026-10-13)

사용자는 계정 플랜이 GitHub Free임을 확인하고
**Private 전환 보류, 나머지 검증 완료 (권장)**를 선택했다. 현재 자동 게시 변수는
`HEICCY_RELEASE_ENABLED=false`이며 DMG 게시·PR #16 머지·개발 저장소의 Private 전환을 모두 보류한다.
개발 저장소는 Public 상태를 유지하고 기존 `main` 브랜치 보호와 `public-release`
environment의 보호 설정을 유지한다. 설치 실기와 나머지 검증은 진행하되 실제
완료 여부는 [이슈 #13 검증 기록](macos-issue13-release-readiness.md)에서 확인한다.

CI artifact의 다운로드·SHA-256 대조·설치 검증은 빌드 산출물의 검증이다.
GitHub Releases에 설치 파일을 공개했거나 비인증 사용자가 공개 DMG를 내려받아
설치할 수 있음을 확인한 결과로 기록하지 않는다. 공개 다운로드 검증은 게시가
별도로 승인되고 실제 릴리스가 공개된 뒤 수행한다.

GitHub Free의 Private 저장소에서는 현재 보호 설정을 그대로 사용할 수 없다.

- [브랜치 보호 지원 범위](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches):
  Free는 Public 저장소에서 지원한다. Private 저장소의 branch protection은
  Pro·Team·Enterprise에서 지원한다.
- [environment 관리와 공개 범위 변경](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments):
  Free에서 Public 저장소를 Private로 바꾸면 기존 environment 보호 규칙과
  environment secrets가 무시되고 environment를 설정할 수 없다. Private 저장소의
  environment·secrets·배포 브랜치 제한에는 Pro·Team·Enterprise가 필요하다.
- [보호 규칙별 지원 범위](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments):
  required reviewers와 wait timer는 Free·Pro·Team에서도 Public 저장소에만 제공된다.
  플랜 변경만으로 Private 저장소의 모든 보호 기능이 유지된다고 판단하지 않는다.

## 릴리스 순서

다음은 정상 릴리스 흐름이며 현재 보류한 작업의 실행 승인을 뜻하지 않는다.
게시·머지·Private 전환은 별도 승인 후 재개한다. Private 전환은 아래 공개 배포 확인과
함께 필요한 브랜치·environment 보호 기능의 플랜 지원 여부도 충족해야 한다.

1. 개발 PR을 검토하고 `main`에 반영한다. Python·Swift·worker·패널·DMG·배포 파일을
   macOS 15·26에서 검증한다. 보호 브랜치 머지는 별도로 수행한다.
2. `Info.plist`와 릴리스 노트를 확인하고 개발 커밋에 `macos-v1.0.0` 태그를 붙인다.
   Python 태그 `v<Python 버전>`은 앱 게시를 실행하지 않는다.
3. 태그 실행에서 두 OS 검증을 모두 통과해야 게시 job이 시작된다. macOS 15 artifact의
   DMG를 선택하고 재빌드하지 않는다. macOS 26 artifact는 별도 검증 자료로 보존한다.
4. 선택한 artifact의 커밋·앱 버전·파일명·SHA-256을 검증한다. 공개 소스는 태그 커밋의
   허용 목록에서 추출하므로 작업 폴더·미추적 파일이 섞이지 않는다.
5. 공개 소스 사본에 `v1.0.0` 태그를 연결한다. `SOURCE.json`은 개발 SHA와 파일 해시를,
   릴리스 manifest는 게시 파일과 개발·공개 커밋의 대응을 기록한다.
6. DMG·체크섬·manifest·코덱 대응 소스를 초안 릴리스에 업로드한다.
   기존 태그·릴리스·산출물은 덮어쓰지 않는다. 실패한 초안은 내용을 확인한 뒤 복구한다.
7. 초안에서 받아 SHA-256·Applications 설치·첫 실행·핵심 변환·기존 설정 승계를 확인하고
   공개한다. 비인증 다운로드와 문서 링크를 다시 확인한다.
8. 공개 배포가 정상 동작한 다음에만 개발 저장소를 Private로 전환하고 권한·CI를 재검증한다.

## 게시 인증

자체 `GITHUB_TOKEN`은 개발 저장소 artifact 조회에 사용한다. 공개 저장소 쓰기에는
`public-release` environment의 `HEICCY_RELEASE_TOKEN`이 필요하다. 대상 `heiccy`만
선택한 fine-grained PAT의 `Contents: read and write` 또는 같은 권한의 GitHub App을
사용한다. 현재 로컬 CLI의 넓은 OAuth 토큰을 CI secret으로 재사용하지 않는다.
토큰 값은 문서·채팅·Git에 기록하지 않는다.

GitHub의 [토큰 인증 안내](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)와
[보안 운영 안내](https://docs.github.com/en/actions/reference/security/secure-use)를 따른다.
environment 접근 범위는 `macos-v*` 태그로 제한한다. 태그는 `main`에 포함된 커밋만
허용하도록 workflow에서도 검증한다. Private 저장소에서 environment·보호 규칙의
사용 가능 여부는 계정 플랜에 따라 확인한다. 지원되지 않으면 토큰을 노출하는 우회
없이 배포 인증 방식을 조정한다.

## DMG 생성 재시도와 검증 로그

DMG 생성은 OS 버전·빌드 번호·아키텍처와 `hdiutil create -verbose` 출력을
기록한다. `create_dmg.py`는 각 시도의 명령·종료 코드·stdout·stderr를 보존하고,
최종 실패 진단이 `hdiutil: create failed - Resource busy`인 경우에만 2초 간격으로
최대 총 3회 시도한다. 실패한 명령에 지정한 불완전한 DMG 파일만 정리하며 다른 오류와
시도별 300초 타임아웃은 즉시 중단한다. 재시도 한도를 소진하면 빌드도 실패한다.
새 생성 전에 이전 체크섬을 제거하고 생성 성공 후에만 새 체크섬·설치 검증을 진행한다.
검증은 파일 경로·크기·예상/실제 SHA-256을 먼저 기록한 뒤
`hdiutil verify -verbose`로 이미지 내부 체크섬을 검사한다. verify·attach·detach의
명령, 종료 코드, stdout과 stderr를 로그에 남기며 attach의 원본 stdout은
별도로 plist 파싱에 사용한다. 외부 체크섬이나 hdiutil 검증 실패 시 즉시 중단하며
자동 재시도하거나 설치 검증으로 우회하지 않는다.

2026-10-13 KST의 [PR #17 실행 38367295201](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38367295201)은
macOS 15.7.9에서 앱·worker·시작 패널 검증 후 `hdiutil create`의 복사 완료·마무리
단계에서 `Resource busy`로 실패했다. macOS 26 작업은 통과했다. 배타적 접근 실패를
일으킨 프로세스는 해당 로그로 특정할 수 없으므로 원인을 단정하거나 검증을 생략하지 않는다.
위 재시도는 생성 단계의 해당 오류에 한정하며 verify·attach·설치 검증의 실패는 그대로 유지한다.

2026-10-07 KST의 [push 실행 37491932847](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/37491932847)은
macOS 26의 `hdiutil verify -quiet`에서 exit 1로 실패했다. 같은 HEAD
`fd07bb1`의 [PR 실행 37491939634](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/37491939634)는
두 OS에서 성공했다. macOS 26.6.2와 runner 이미지 버전은 같지만 PR 실행은
GitHub의 임시 merge 커밋을 체크아웃했다. 기존 quiet 로그에는 구체적인 실패 사유가
없으므로 이미지 손상이나 runner 상태 문제로 단정할 수 없다. 위 변경은 실패 원인을
진단할 근거를 보존하는 개선이며, 해당 CI 실패가 재발하지 않는다는 검증은 아니다.

## PyPI

`README.pypi.md`는 영어 CLI/TUI 설명이며 앱 README와 분리한다. wheel `METADATA`와
sdist `PKG-INFO`의 영어 Summary·설명·버전·포함 목록을 검증한다.
`input/`·`output/`과 Swift·packaging·내부 문서는 Python 배포에 포함하지 않는다.

앱 배포는 Python 배포를 실행하지 않는다. 이미 PyPI에 게시된 설명·URL은 이번 소스
수정만으로 바뀌지 않는다. 공개 경로를 반영하려면 다음 독립 Python 릴리스에서
새 메타데이터를 게시해야 한다. 이전 버전의 오래된 링크까지 수정할 수는 없다.

## Private 전환 전후 점검

- 공개 안내에서 내부 이슈·PR·검증 문서 링크를 제거한다.
- 기존 Python 버전 PyPI 링크의 단절 영향과 새 Python 설명의 공개 URL을 확인한다.
- 기존 공개 fork·외부 복제본은 Private 전환으로 회수되지 않는다.
- 계정 플랜에 따른 branch protection·environment·Actions 요금과 분 제한 변화를 확인한다.
- 로컬 개발 `origin`은 기존 저장소를 유지하고 공개 저장소는 별도 checkout을 사용한다.
- 비인증 접근에서 기존 코드·이슈·PR이 차단되고 새 README·태그·설치 파일이 열리는지
  확인한다. Private 전환 후 두 OS CI와 게시 토큰을 재검증한다.

실제 완료 여부는 [이슈 #13 검증 기록](macos-issue13-release-readiness.md)에 남긴다.
