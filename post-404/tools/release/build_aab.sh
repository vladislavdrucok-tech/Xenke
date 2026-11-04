#!/bin/sh
# Time Post — build build/timepost.aab for Google Play (macOS/Linux).
# Usage: GODOT=/path/to/Godot_v4.7.2 sh tools/release/build_aab.sh
set -e
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/../.."
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$HOME/timepost-upload.keystore}
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-timepost}
if [ -z "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" ]; then
  printf "Keystore password: "; stty -echo; read GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; stty echo; echo
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
fi
mkdir -p build
"$GODOT" --headless --path . --install-android-build-template --export-release "Android Play (AAB)" build/timepost.aab
ls -la build/timepost.aab && echo "OK: upload build/timepost.aab to Play Console"
