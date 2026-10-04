#!/bin/bash
# 고정한 arm64 환경에서 앱, DMG와 체크섬을 조립한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
    echo '앱 빌드는 Apple Silicon macOS에서만 지원합니다.' >&2
    exit 1
fi
export MACOSX_DEPLOYMENT_TARGET=15.0
PYTHON_VERSION=3.12.12
BUILD="$ROOT/build/macos"
DIST="$ROOT/dist/macos"
APP="$DIST/HEIC Converter.app"
ENVIRONMENT="$ROOT/.venv-app-build"
uv python install "$PYTHON_VERSION"
uv venv --allow-existing --python "$PYTHON_VERSION" "$ENVIRONMENT"
uv pip sync --python "$ENVIRONMENT/bin/python" --require-hashes packaging/macos/requirements.lock
PYTHON="$ENVIRONMENT/bin/python"
"$PYTHON" -c 'import platform, sys; assert platform.machine() == "arm64"; assert sys.version_info[:3] == (3, 12, 12)'
mkdir -p "$BUILD" "$DIST"
"$PYTHON" -m PyInstaller --noconfirm --clean --workpath "$BUILD/pyinstaller" --distpath "$BUILD/frozen" packaging/macos/worker.spec
swift build --package-path macos --configuration release --arch arm64
# 복사 범위는 세 개의 빌드 산출물과 아래 명시한 파일로 한정한다.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Licenses"
SWIFT_BIN="$(swift build --package-path macos --configuration release --arch arm64 --show-bin-path)"
cp "$SWIFT_BIN/HEICConverter" "$APP/Contents/MacOS/HEICConverter"
cp packaging/macos/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp -R "$BUILD/frozen/worker" "$APP/Contents/Resources/worker"
cp LICENSE "$APP/Contents/Resources/Licenses/HEIC-Converter-MIT.txt"
"$PYTHON" packaging/macos/collect_licenses.py "$APP/Contents/Resources/Licenses"
"$PYTHON" packaging/macos/create_icon.py "$BUILD/AppIcon.iconset"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
"$PYTHON" packaging/macos/normalize_app.py "$APP"
"$PYTHON" packaging/macos/sign_app.py "$APP"
"$PYTHON" packaging/macos/validate_app.py "$APP"
"$PYTHON" packaging/macos/smoke_worker.py "$APP/Contents/Resources/worker/heic-worker"
"$APP/Contents/MacOS/HEICConverter" --smoke-test
STAGING="$BUILD/dmg-root"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/HEIC Converter.app"
ln -s /Applications "$STAGING/Applications"
DMG="$DIST/HEIC-Converter-0.3.0-arm64.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname 'HEIC Converter' -srcfolder "$STAGING" -format UDZO "$DMG"
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
"$PYTHON" packaging/macos/validate_dmg.py "$DMG"
echo "검증 완료: $DMG"
