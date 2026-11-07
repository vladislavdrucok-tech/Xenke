#!/bin/sh
# Builds the Android APK of FLOOR 13 (see CONTINUE.md for the one-time setup).
#   GODOT=<path to Godot 4.3 editor>  KEYSTORE=<release.keystore> KEY_ALIAS=... KEY_PASS=...  tools/build_apk.sh
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-/home/user/tools/godot/Godot_v4.3-stable_linux.x86_64}
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=${KEYSTORE:-/home/user/tools/keys/floor13.keystore}
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=${KEY_ALIAS:-floor13}
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${KEY_PASS:-floor13night}
VERSION=$(grep '^const VERSION' scripts/defs.gd | sed 's/.*"\(.*\)".*/\1/')
OUT=builds/Floor13-NightShift-$VERSION.apk
"$G" --headless --editor --quit --path . >/dev/null 2>&1 || true
"$G" --headless --path . -s res://tests/run_tests.gd | grep TESTS
rm -f "$OUT"
"$G" --headless --path . --export-release "Android" "$OUT" 2>&1 | grep -v "^$" | tail -5
ls -la "$OUT"
apksigner verify --print-certs "$OUT" | head -3
