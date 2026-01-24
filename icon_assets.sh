#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSET_DIR="$ROOT_DIR/assets"
ICONSET="$ASSET_DIR/SimpleEditor.iconset"
PNG_SRC="$ASSET_DIR/AppIcon.png"

if [ ! -f "$PNG_SRC" ]; then
  echo "Missing $PNG_SRC"
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16   "$PNG_SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32   "$PNG_SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32   "$PNG_SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64   "$PNG_SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PNG_SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$PNG_SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PNG_SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$PNG_SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PNG_SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$PNG_SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$ASSET_DIR/AppIcon.icns"

echo "Wrote $ASSET_DIR/AppIcon.icns"
