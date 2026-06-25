#!/bin/bash
# Render the app icon and package it into Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Building (need the --icon renderer)…"
swift build -c release >/dev/null

SRC="/tmp/icon_1024.png"
.build/release/WindowSwitcher --icon "$SRC" 2>/dev/null
# The GUI process lingers briefly after writing; wait for the file then stop it.
for _ in $(seq 1 20); do [ -f "$SRC" ] && break; sleep 0.2; done
pkill -x WindowSwitcher 2>/dev/null || true

echo "▸ Generating iconset…"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
gen() { sips -z "$2" "$2" "$SRC" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png      16
gen icon_16x16@2x.png   32
gen icon_32x32.png      32
gen icon_32x32@2x.png   64
gen icon_128x128.png    128
gen icon_128x128@2x.png 256
gen icon_256x256.png    256
gen icon_256x256@2x.png 512
gen icon_512x512.png    512
cp "$SRC" "$ICONSET/icon_512x512@2x.png"   # 1024

echo "▸ Building .icns…"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "✓ Wrote Resources/AppIcon.icns"
