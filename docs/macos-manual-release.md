# heiccy 수동 릴리스

GitHub Free의 Private 개발 저장소에서 두 OS CI를 유지하고, 로그인된 GitHub CLI로
Public `jaehunshin-git/heiccy`에 게시한다. 전용 PAT·environment secret은 사용하지
않으며 `HEICCY_RELEASE_ENABLED=false`를 유지한다. CI 트리거는 push·PR 모두 유지한다.
아래 명령은 개발 저장소 루트에서 실행한다. PR #16은 사용자가 먼저 머지한다.
현재 작업 브랜치나 PR용 합성 머지 커밋으로 정식 릴리스를 만들지 않는다.

## 1. main과 개발 태그

작업 트리가 깨끗한지 확인하고 main의 실제 머지 커밋을 선택한다. 태그가 이미
있으면 이동·삭제하지 않고 기존 실행을 조사한다.

```bash
git status --short
git fetch origin main --tags
source_commit="$(git rev-parse origin/main)"
app_version="$(git show "${source_commit}:packaging/macos/Info.plist" | python3 -c 'import sys, plistlib; print(plistlib.loads(sys.stdin.buffer.read())["CFBundleShortVersionString"])')"
source_tag="macos-v$app_version"
public_tag="v$app_version"
git merge-base --is-ancestor "$source_commit" origin/main
git tag "$source_tag" "$source_commit"
git push origin "refs/tags/$source_tag"
gh run list --repo jaehunshin-git/heic-converter-tui --workflow macos.yml --branch "$source_tag"
```

## 2. 같은 태그 실행의 두 OS 원본

위 목록에서 태그 push 실행의 ID를 선택한다. `run_id`는 실제 숫자로 설정한다.
`gh run view`에서 event=push, headSha=선택한 SHA, headBranch=개발 태그,
conclusion=success와 macOS 15·26 두 validate job의 성공을 확인한다.
자동 release job은 skipped여야 한다. 불일치·실패이면 게시하지 않는다.

```bash
run_id='실제 실행 ID'
gh run view "$run_id" --repo jaehunshin-git/heic-converter-tui \
  --json event,headSha,headBranch,status,conclusion,jobs,attempt,url
run_attempt="$(gh run view "$run_id" --repo jaehunshin-git/heic-converter-tui --json attempt --jq .attempt)"
release_root="build/manual-release-$run_id-$run_attempt"
mkdir -p "$release_root"
gh run download "$run_id" --repo jaehunshin-git/heic-converter-tui \
  --name heiccy-macos-15-arm64 --dir "$release_root/macos-15"
gh run download "$run_id" --repo jaehunshin-git/heic-converter-tui \
  --name heiccy-macos-26-arm64 --dir "$release_root/macos-26"
python3 packaging/release/verify_release.py verify \
  --macos-15 "$release_root/macos-15/macos" \
  --macos-26 "$release_root/macos-26/macos" \
  --tag "$source_tag" --source-repository jaehunshin-git/heic-converter-tui \
  --source-commit "$source_commit" --run-id "$run_id" --run-attempt "$run_attempt" \
  --output "$release_root/verified.txt" --notes-output "$release_root/notes.md"
```

검증 도구는 현재 checkout의 Info.plist·릴리스 노트를 참조한다. 실행 전에
선택한 main과 해당 파일의 내용이 일치하는지 확인한다. 이후에는 macOS 15의
원본 DMG·체크섬·코덱 소스를 선택하고 재빌드하지 않는다.

## 3. 公開ソースとタグ

기존 태그·릴리스 목록에 `public_tag`가 있으면 중단한다. 실패한 첫 게시의
복구도 현물을 확인한 뒤 수행하며 `--force`·`--clobber`는 사용하지 않는다.

```bash
gh api "repos/jaehunshin-git/heiccy/git/matching-refs/tags/$public_tag" --jq '.[].ref'
gh api --paginate repos/jaehunshin-git/heiccy/releases --jq '.[].tag_name'
public_checkout="$release_root/public-repo"
gh repo clone jaehunshin-git/heiccy "$public_checkout"
python3 packaging/release/export_public.py "$public_checkout" --source-commit "$source_commit" --sync
python3 packaging/release/verify_release.py snapshot "$public_checkout" \
  --source-commit "$source_commit" --version "$app_version"
git -C "$public_checkout" remote get-url origin
git -C "$public_checkout" diff --stat
git -C "$public_checkout" add -A
git -C "$public_checkout" commit -m "chore(release): $public_tag 공개 소스 스냅샷"
public_commit="$(git -C "$public_checkout" rev-parse HEAD)"
git -C "$public_checkout" tag "$public_tag" "$public_commit"
git -C "$public_checkout" push --atomic origin HEAD:refs/heads/main "refs/tags/$public_tag"
python3 packaging/release/verify_release.py provenance \
  --manifest-15 "$release_root/macos-15/macos/release-manifest-macos-15.json" \
  --manifest-26 "$release_root/macos-26/macos/release-manifest-macos-26.json" \
  --public-commit "$public_commit" --output "$release_root/release-source.json"
```

remote가 `jaehunshin-git/heiccy`인지, 공개 diff에 내부 문서·개인 파일이 없는지
확인하고 push한다. SOURCE.json의 SHA와 모든 파일 해시를 비인증 ZIP에서도
대조한다. 개발 이력과 내부 이슈·PR은 복사하지 않는다.

## 4. 초안과 공개

검증한 macOS 15 원본과 두 OS의 manifest, 별도 공개 커밋 연결 기록을 첨부한다.
새 초안만 생성하며 이미 존재하는 릴리스나 첨부 파일은 덮어쓰지 않는다.

```bash
gh release create "$public_tag" --repo jaehunshin-git/heiccy --verify-tag --draft \
  --title "heiccy $public_tag" --notes-file "$release_root/notes.md" \
  "$release_root/macos-15/macos/heiccy-$app_version-arm64.dmg" \
  "$release_root/macos-15/macos/heiccy-$app_version-arm64.dmg.sha256" \
  "$release_root/macos-15/macos/heiccy-codec-sources-$app_version.tar.gz" \
  "$release_root/macos-15/macos/heiccy-codec-sources-$app_version.tar.gz.sha256" \
  "$release_root/macos-15/macos/release-manifest-macos-15.json" \
  "$release_root/macos-26/macos/release-manifest-macos-26.json" \
  "$release_root/release-source.json"
```

초안에서 다시 다운로드해 SHA·설치·핵심 변환·설정 승계를 검증한다. 코덱 소스·고지와
릴리스 노트의 제한 설명을 검토한 뒤 아래 명령으로 공개한다. CI artifact 검사만으로
공개 다운로드나 미공증 첫 실행이 통과했다고 기록하지 않는다.

```bash
gh release edit "$public_tag" --repo jaehunshin-git/heiccy --draft=false --latest
```

공개 후 비인증 다운로드의 SHA를 대조하고 브라우저로 받은 격리 속성 있는 DMG의
Applications 설치·Gatekeeper 첫 실행·실제 변환·업그레이드를 확인한다. 보안 속성을
제거해 검증을 우회하지 않는다. 결과·환경·미검증 한계를
[이슈 #13 검증 기록](macos-issue13-release-readiness.md)에 남긴다. PyPI 업로드는 별도다.
