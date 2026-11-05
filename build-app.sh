#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="FocusBar"
BUNDLE_DIR="$SCRIPT_DIR/build/${APP_NAME}.app"

echo "Building ${APP_NAME} (release)..."
swift build -c release --disable-sandbox

BIN_PATH="$(swift build -c release --disable-sandbox --show-bin-path)/${APP_NAME}"

echo "Assembling ${BUNDLE_DIR}..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BIN_PATH" "$BUNDLE_DIR/Contents/MacOS/${APP_NAME}"
cp "$SCRIPT_DIR/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
if [[ -f "$SCRIPT_DIR/Resources/FocusBar.icns" ]]; then
    cp "$SCRIPT_DIR/Resources/FocusBar.icns" "$BUNDLE_DIR/Contents/Resources/FocusBar.icns"
fi
printf "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

echo "Signing ${BUNDLE_DIR} (ad-hoc)..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "Built: $BUNDLE_DIR"

if [[ "${1:-}" == "--install" ]]; then
    INSTALL_DIR="${2:-$HOME/Applications}"
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/${APP_NAME}.app"
    cp -R "$BUNDLE_DIR" "$INSTALL_DIR/${APP_NAME}.app"
    echo "Installed to: $INSTALL_DIR/${APP_NAME}.app"
fi
