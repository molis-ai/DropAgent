#!/usr/bin/env zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

BUILD_CONFIGURATION="${DROPAGENT_CONFIGURATION:-debug}"
case "$BUILD_CONFIGURATION" in
  debug|release) ;;
  *) echo "DROPAGENT_CONFIGURATION must be debug or release" >&2; exit 1 ;;
esac
swift build --configuration "$BUILD_CONFIGURATION" --product DropAgent
BIN_DIR="$(swift build --configuration "$BUILD_CONFIGURATION" --show-bin-path)"

APP="$ROOT/dist/DropAgent.app"
BUNDLE_ID="local.dropagent"
if [[ "${DROPAGENT_VARIANT:-}" == "review" ]]; then
  APP="$ROOT/dist/DropAgent Review.app"
  BUNDLE_ID="local.dropagent.review"
fi
BIN="$BIN_DIR/DropAgent"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"
if [[ "$BUNDLE_ID" == "local.dropagent.review" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName DropAgent Review" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName DropAgent Review" "$APP/Contents/Info.plist"
fi
cp "$BIN" "$APP/Contents/MacOS/DropAgent"
chmod +x "$APP/Contents/MacOS/DropAgent"

ICON_SRC="$ROOT/scripts/make-icon.swift"
ICON_PNG="$ROOT/dist/DropAgent-1024.png"
ICONSET="$ROOT/dist/DropAgent.iconset"
ICNS="$APP/Contents/Resources/DropAgent.icns"
mkdir -p "$APP/Contents/Resources" "$ICONSET"
cp "$ROOT/../LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/../NOTICE" "$APP/Contents/Resources/NOTICE"
ditto "$BIN_DIR/SwiftTerm_SwiftTerm.bundle" "$APP/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
swift "$ICON_SRC" "$ICON_PNG"
sips -z 16 16     "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET" "$ICON_PNG"

ENT="$ROOT/App/DropAgent.entitlements"
IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)"

if [[ -n "${IDENTITY:-}" ]]; then
  codesign --force --sign "$IDENTITY" --options runtime --timestamp \
    --entitlements "$ENT" --identifier "$BUNDLE_ID" "$APP"
  echo "signed Developer ID: $IDENTITY"
else
  codesign --force --sign - --entitlements "$ENT" --identifier "$BUNDLE_ID" "$APP"
  echo "signed adhoc $BUNDLE_ID (no Developer ID Application identity)"
fi

echo "$APP"
