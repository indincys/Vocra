#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Vocra"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPARKLE_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle"
GENERATE_APPCAST="$SPARKLE_DIR/bin/generate_appcast"

VERSION="${1:-${VOCRA_VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>" >&2
  exit 2
fi

TAG="${VOCRA_TAG:-v$VERSION}"
BUILD_VERSION="${VOCRA_BUILD:-${GITHUB_RUN_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD)}}"
REPOSITORY="${GITHUB_REPOSITORY:-${VOCRA_GITHUB_REPOSITORY:-}}"
if [[ -z "$REPOSITORY" ]]; then
  ORIGIN_URL="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$ORIGIN_URL" =~ github.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    REPOSITORY="${BASH_REMATCH[1]}"
  fi
fi
if [[ -z "$REPOSITORY" ]]; then
  echo "Set GITHUB_REPOSITORY or VOCRA_GITHUB_REPOSITORY to owner/repo." >&2
  exit 2
fi

if [[ -z "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  echo "Set SPARKLE_PUBLIC_KEY to the public EdDSA key from Sparkle generate_keys." >&2
  exit 2
fi
if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "Set SPARKLE_PRIVATE_KEY to the private EdDSA key from Sparkle generate_keys." >&2
  exit 2
fi

FEED_URL="${SPARKLE_FEED_URL:-https://github.com/$REPOSITORY/releases/latest/download/appcast.xml}"
DOWNLOAD_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/$REPOSITORY/releases/download/$TAG/}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
RELEASE_DIR="$DIST_DIR/releases/$TAG"
ASSET_BASENAME="$APP_NAME-$VERSION"
DMG_PATH="$RELEASE_DIR/$ASSET_BASENAME.dmg"
NOTES_PATH="$RELEASE_DIR/$ASSET_BASENAME.md"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"

mkdir -p "$RELEASE_DIR"

SWIFT_CONFIGURATION=release \
VOCRA_VERSION="$VERSION" \
VOCRA_BUILD="$BUILD_VERSION" \
SPARKLE_FEED_URL="$FEED_URL" \
SPARKLE_PUBLIC_KEY="$SPARKLE_PUBLIC_KEY" \
"$ROOT_DIR/script/build_and_run.sh" --package

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
/usr/bin/hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${RELEASE_NOTES_FILE:-}" && -f "$RELEASE_NOTES_FILE" ]]; then
  cp "$RELEASE_NOTES_FILE" "$NOTES_PATH"
elif [[ ! -f "$NOTES_PATH" ]]; then
  cat >"$NOTES_PATH" <<NOTES
# $APP_NAME $VERSION

- See the GitHub release for details.
NOTES
fi

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  swift package --package-path "$ROOT_DIR" resolve
fi

printf '%s' "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --embed-release-notes \
  --maximum-versions 10 \
  -o "$APPCAST_PATH" \
  "$RELEASE_DIR"

if ! grep -Fq "sparkle:edSignature" "$APPCAST_PATH"; then
  echo "Generated appcast is missing sparkle:edSignature. Check SPARKLE_PUBLIC_KEY and SPARKLE_PRIVATE_KEY." >&2
  exit 1
fi

echo "DMG: $DMG_PATH"
echo "Appcast: $APPCAST_PATH"
echo "Feed URL: $FEED_URL"
