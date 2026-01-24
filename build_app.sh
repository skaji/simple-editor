#!/bin/sh
set -eu

APP_NAME="SimpleEditor"
BUNDLE_ID="com.simple-editor"
VERSION="0.1.0"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENT_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENT_DIR/MacOS"
RESOURCES_DIR="$CONTENT_DIR/Resources"

swift build -c release

BIN_PATH="$BUILD_DIR/arm64-apple-macosx/release/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
  BIN_PATH="$BUILD_DIR/release/$APP_NAME"
fi

if [ ! -f "$BIN_PATH" ]; then
  echo "Binary not found: $APP_NAME"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [ -f "$ROOT_DIR/assets/AppIcon.icns" ]; then
  cp "$ROOT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENT_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
