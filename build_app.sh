#!/bin/bash
# Build WindowSwitcher and package it into a signed .app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="窗口闪切"
EXEC_NAME="WindowSwitcher"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "▸ Compiling (release)…"
swift build -c release

echo "▸ Assembling ${APP_BUNDLE}…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${EXEC_NAME}" "${APP_BUNDLE}/Contents/MacOS/${EXEC_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
else
  echo "  (no Resources/AppIcon.icns — run ./make_icon.sh first)"
fi

# Prefer a stable local identity (so Accessibility survives rebuilds); fall back
# to ad-hoc. Run ./setup_signing.sh once to create the identity.
SIGN_IDENTITY="WindowSwitcher Local Signing"
if security find-certificate -c "${SIGN_IDENTITY}" >/dev/null 2>&1; then
  echo "▸ Signing with \"${SIGN_IDENTITY}\"…"
  codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
else
  echo "▸ Ad-hoc signing (run ./setup_signing.sh for a rebuild-stable identity)…"
  codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "✓ Built ${APP_BUNDLE}"
echo "  Run it with:  open \"${APP_BUNDLE}\""
echo "  First launch: grant Accessibility in System Settings, then press ⌥Tab."
