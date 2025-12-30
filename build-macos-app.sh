#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/Adobe Downloader.xcodeproj"
SCHEME="Adobe Downloader"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/Adobe Downloader.app"
OUTPUT_APP="$BUILD_DIR/Adobe Downloader.app"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: Xcode is required. Install Xcode and run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: project not found at $PROJECT_PATH"
  exit 1
fi

mkdir -p "$BUILD_DIR"

BUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "generic/platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
)

if [[ "${ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
  BUILD_ARGS+=(-allowProvisioningUpdates)
fi

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  BUILD_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

if [[ -n "${CODE_SIGN_STYLE:-}" ]]; then
  BUILD_ARGS+=("CODE_SIGN_STYLE=$CODE_SIGN_STYLE")
fi

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  BUILD_ARGS+=("CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")
fi

if [[ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]]; then
  BUILD_ARGS+=("PROVISIONING_PROFILE_SPECIFIER=$PROVISIONING_PROFILE_SPECIFIER")
fi

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild "${BUILD_ARGS[@]}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH"
  exit 1
fi

rm -rf "$OUTPUT_APP"
ditto "$APP_PATH" "$OUTPUT_APP"

echo "Built app: $OUTPUT_APP"
