#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# One download for both Apple Silicon and Intel Macs.
bash scripts/build-app.sh --universal
APP="$PWD/dist/NextayClip.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
OUTPUT_DIR="$PWD/dist"
DMG="$OUTPUT_DIR/NextayClip-${VERSION}-universal.dmg"
PKG="$OUTPUT_DIR/NextayClip-${VERSION}-universal.pkg"
ZIP="$OUTPUT_DIR/NextayClip-${VERSION}-universal.zip"
WORK_DIR="$(mktemp -d "$PWD/.build/installer.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

ARCHS="$(lipo -archs "$APP/Contents/MacOS/NextayClip")"
if [[ " $ARCHS " != *" arm64 "* || " $ARCHS " != *" x86_64 "* ]]; then
    echo "Expected both arm64 and x86_64; got: $ARCHS" >&2
    exit 1
fi
codesign --verify --deep --strict "$APP"

mkdir -p "$WORK_DIR/dmg" "$WORK_DIR/pkgroot/Applications"
ditto "$APP" "$WORK_DIR/dmg/NextayClip.app"
ln -s /Applications "$WORK_DIR/dmg/Applications"
cp LICENSE "$WORK_DIR/dmg/LICENSE.txt"
cat > "$WORK_DIR/dmg/Install.txt" <<'INSTALL'
Nextay Clip — by NexTay Solutions
Free and open source · MIT License
https://nextaysolutions.com/
https://github.com/NexTay/clip

Requires macOS 13 or later. Supports Apple Silicon and Intel Macs.

1. Quit any running copy of Nextay Clip before installing or updating.
2. Drag NextayClip.app onto Applications.
3. Eject the disk image, then open Nextay Clip from Applications.
4. Look for the paperclip in your menu bar, or press Command+Shift+V.
5. Choose Settings… from the menu to configure history and launch at login.

The app stays in the menu bar; no main window appears at launch.
Click a saved clip to copy it, then paste using Command+V.

This build is locally signed, not Apple-notarized. If macOS blocks it,
review the app in System Settings > Privacy & Security > Open Anyway.
https://support.apple.com/en-us/102445

History stays on this Mac in an unencrypted local file. Pause monitoring
before copying sensitive text. Full usage and privacy details are in the
repository README.
INSTALL

hdiutil create -volname "Nextay Clip" -srcfolder "$WORK_DIR/dmg" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"

# Disable relocation so updates always install into /Applications.
ditto "$APP" "$WORK_DIR/pkgroot/Applications/NextayClip.app"
pkgbuild --analyze --root "$WORK_DIR/pkgroot" "$WORK_DIR/components.plist"
if ! /usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$WORK_DIR/components.plist" 2>/dev/null; then
    /usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$WORK_DIR/components.plist"
fi
pkgbuild --root "$WORK_DIR/pkgroot" --component-plist "$WORK_DIR/components.plist" \
    --identifier com.nextaysolutions.clip --version "$VERSION" --install-location / "$PKG"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$(basename "$DMG")" "$(basename "$PKG")" "$(basename "$ZIP")" > SHA256SUMS.txt
)
echo "Created universal DMG, PKG, ZIP, and SHA256SUMS.txt in $OUTPUT_DIR"
