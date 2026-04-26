#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="Vocra"
APP_VARIANT="${VOCRA_APP_VARIANT:-dev}"
if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  APP_VARIANT="${VOCRA_APP_VARIANT:-release}"
fi

case "$APP_VARIANT" in
  dev)
    APP_NAME="${VOCRA_DEV_APP_NAME:-Vocra Dev}"
    EXECUTABLE_NAME="${VOCRA_DEV_EXECUTABLE_NAME:-VocraDev}"
    BUNDLE_ID="${VOCRA_DEV_BUNDLE_ID:-com.indincys.Vocra.dev}"
    DEFAULT_CODESIGN_IDENTITY="Vocra Local Development"
    ;;
  release)
    APP_NAME="Vocra"
    EXECUTABLE_NAME="Vocra"
    BUNDLE_ID="com.indincys.Vocra"
    DEFAULT_CODESIGN_IDENTITY="-"
    ;;
  *)
    echo "VOCRA_APP_VARIANT must be 'dev' or 'release'." >&2
    exit 2
    ;;
esac

MIN_SYSTEM_VERSION="26.0"
SWIFT_CONFIGURATION="${SWIFT_CONFIGURATION:-debug}"
MARKETING_VERSION="${VOCRA_VERSION:-0.1.0}"
BUILD_VERSION="${VOCRA_BUILD:-1}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon/Vocra.icns"

pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

swift build -c "$SWIFT_CONFIGURATION"
BUILD_BINARY="$(swift build -c "$SWIFT_CONFIGURATION" --show-bin-path)/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/Vocra.icns"
fi

SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path '*/Sparkle.framework' -type d -print -quit)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  /usr/bin/ditto "$SPARKLE_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"
fi

if ! otool -l "$APP_BINARY" | grep -Fq "@loader_path/../Frameworks"; then
  /usr/bin/codesign --remove-signature "$APP_BINARY" >/dev/null 2>&1 || true
  install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP_BINARY"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>Vocra</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -n "$SPARKLE_FEED_URL" && -n "$SPARKLE_PUBLIC_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SPARKLE_FEED_URL" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" "$INFO_PLIST"
fi

CODESIGN_IDENTITY="${VOCRA_CODESIGN_IDENTITY:-}"
if [[ -z "$CODESIGN_IDENTITY" ]]; then
  if [[ "$DEFAULT_CODESIGN_IDENTITY" != "-" ]] && security find-identity -p codesigning -v | grep -Fq "\"$DEFAULT_CODESIGN_IDENTITY\""; then
    CODESIGN_IDENTITY="$DEFAULT_CODESIGN_IDENTITY"
  else
    CODESIGN_IDENTITY="-"
  fi
fi

if [[ "$APP_VARIANT" == "dev" && "$CODESIGN_IDENTITY" == "-" ]]; then
  echo "warning: signing $APP_NAME ad-hoc; create a local 'Vocra Local Development' code-signing certificate to keep Accessibility permission stable across rebuilds." >&2
fi

/usr/bin/codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  --package|package)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
    exit 2
    ;;
esac
