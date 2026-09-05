#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-N6Z827248H}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-a045ac5a-5692-4437-bc68-385c149ce1ac}"
KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
ARCHIVE_PATH="$ROOT/build/GgotgalpiDemo.xcarchive"
EXPORT_PATH="$ROOT/build/export"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Missing App Store Connect API key at $KEY_PATH" >&2
  exit 1
fi

mkdir -p "$ROOT/build"

xcodebuild archive \
  -project GgotgalpiDemo.xcodeproj \
  -scheme GgotgalpiDemo \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  DEVELOPMENT_TEAM=7H8779959T \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

echo "Archive exported to $EXPORT_PATH"
