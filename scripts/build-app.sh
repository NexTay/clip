#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/NextayClip.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NextayClip" "$APP/Contents/MacOS/NextayClip"
ditto "$BIN_DIR/NextayClip_NextayClip.bundle" "$APP/Contents/Resources/NextayClip_NextayClip.bundle"
# Package the supplied company mark as a native macOS app icon.
ICONSET="$PWD/.build/NextayClip.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Sources/NextayClip/Resources/BrandMark.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Sources/NextayClip/Resources/BrandMark.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/NextayClip.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Nextay Clip</string>
<key>CFBundleDisplayName</key><string>Nextay Clip</string>
<key>CFBundleIdentifier</key><string>com.nextaysolutions.clip</string>
<key>CFBundleExecutable</key><string>NextayClip</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleIconFile</key><string>NextayClip</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 NexTay Solutions. MIT License.</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
echo "Install with: cp -R '$APP' /Applications/"
