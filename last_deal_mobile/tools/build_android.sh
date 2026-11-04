#!/bin/sh
# Збирає підписаний APK: tools/build_android.sh [вихідний.apk]
# Потрібні: godot 4.3 у PATH, шаблони експорту 4.3, python3 + cryptography.
# Якщо справжній Android SDK не встановлено (ANDROID_SDK_ROOT порожній), створюється
# мінімальна «оболонка» SDK з нашим apksigner (tools/android/apksigner, схема підпису v2).
set -e
cd "$(dirname "$0")/.."
OUT=${1:-build/LastDeal.apk}
mkdir -p "$(dirname "$OUT")"
SDK=${ANDROID_SDK_ROOT:-$HOME/.ld-android-sdk}
if [ -z "$ANDROID_SDK_ROOT" ]; then
  mkdir -p "$SDK/platform-tools" "$SDK/build-tools/34.0.0"
  printf '#!/bin/sh\necho "adb shim: no devices"\n' > "$SDK/platform-tools/adb"
  chmod +x "$SDK/platform-tools/adb"
  cp tools/android/apksigner "$SDK/build-tools/34.0.0/apksigner"
  chmod +x "$SDK/build-tools/34.0.0/apksigner"
fi
JAVA=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(which java)")")")}
CONF=${XDG_CONFIG_HOME:-$HOME/.config}/godot
mkdir -p "$CONF"
for f in editor_settings-4.3.tres editor_settings-4.tres; do
cat > "$CONF/$f" <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA"
EOT
done
# Тестовий ключ (НЕ для Google Play): tools/keys/ld-test.p12, alias lastdeal
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$PWD/tools/keys/ld-test.p12}
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-lastdeal}
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-lastdeal-test}
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Android" "$OUT"
python3 tools/android/apksigner verify --verbose "$OUT"
ls -la "$OUT"
