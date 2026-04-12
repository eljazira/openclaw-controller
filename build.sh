#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="OpenClawController"
DISPLAY_NAME="OpenClaw Controller"
BUNDLE_ID="ai.openclaw.controller"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "==> Building $APP_NAME (release)…"
swift build -c release

if [ ! -x "$BUILD_DIR/$APP_NAME" ]; then
    echo "Build failed: $BUILD_DIR/$APP_NAME not found"
    exit 1
fi

echo "==> Packaging ${APP_BUNDLE}…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License. https://github.com/YOUR_USERNAME/openclaw-controller</string>
</dict>
</plist>
PLIST

echo "==> Done."
echo "App bundle:  $(pwd)/$APP_BUNDLE"
echo
echo "To launch:       open $APP_BUNDLE"
echo "To install:      mv $APP_BUNDLE /Applications/"
echo "Then launch with: open -a \"$DISPLAY_NAME\""
