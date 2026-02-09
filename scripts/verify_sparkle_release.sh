#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag> [appcast_url]"
  echo "Example: $0 v3.0.16"
  exit 1
fi

TAG="$1"
APPCAST_URL="${2:-https://raw.githubusercontent.com/conmeara/nozzle/main/appcast.xml}"
SHORT_VERSION="${TAG#v}"

TMP_DIR="$(mktemp -d /tmp/nozzle-sparkle-verify.XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

APPCAST_FILE="$TMP_DIR/appcast.xml"
ZIP_FILE="$TMP_DIR/nozzle.app.zip"
APP_PATH="$TMP_DIR/nozzle.app"
ZIP_URL="https://github.com/conmeara/nozzle/releases/download/${TAG}/nozzle.app.zip"

echo "==> Fetching appcast: $APPCAST_URL"
curl -fsSL "$APPCAST_URL" -o "$APPCAST_FILE"

echo "==> Verifying appcast entry for $SHORT_VERSION"
if ! rg -q "<title>${SHORT_VERSION}</title>" "$APPCAST_FILE"; then
  echo "ERROR: appcast does not contain <title>${SHORT_VERSION}</title>"
  exit 1
fi

if ! rg -q "sparkle:shortVersionString=\"${SHORT_VERSION}\"" "$APPCAST_FILE"; then
  echo "ERROR: appcast missing sparkle:shortVersionString=${SHORT_VERSION}"
  exit 1
fi

if ! rg -q "releases/download/${TAG}/nozzle\\.app\\.zip" "$APPCAST_FILE"; then
  echo "ERROR: appcast missing nozzle.app.zip URL for tag ${TAG}"
  exit 1
fi

echo "==> Downloading release zip: $ZIP_URL"
curl -fL "$ZIP_URL" -o "$ZIP_FILE"
unzip -q "$ZIP_FILE" -d "$TMP_DIR"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: release archive does not contain nozzle.app at top level"
  exit 1
fi

echo "==> Verifying signed app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv "$APP_PATH"

ENTITLEMENTS="$(codesign -d --entitlements - "$APP_PATH" 2>&1)"
echo "==> Checking Sparkle entitlements"
if echo "$ENTITLEMENTS" | rg -q '\$\('; then
  echo "ERROR: unresolved entitlement variable found in signed app:"
  echo "$ENTITLEMENTS"
  exit 1
fi

if ! echo "$ENTITLEMENTS" | rg -q "com\\.conmeara\\.nozzleai-spks"; then
  echo "ERROR: missing Sparkle mach service entitlement: com.conmeara.nozzleai-spks"
  exit 1
fi

if ! echo "$ENTITLEMENTS" | rg -q "com\\.conmeara\\.nozzleai-spki"; then
  echo "ERROR: missing Sparkle mach service entitlement: com.conmeara.nozzleai-spki"
  exit 1
fi

echo "PASS: Sparkle release checks succeeded for ${TAG}"
