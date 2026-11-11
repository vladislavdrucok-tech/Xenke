#!/bin/sh
# Deep Bounce: signed release APK and AAB through the Godot Gradle build.
#   tools/android/build_release.sh [apk|aab|both]      (run from deep_bounce/)
# Needs: Godot 4.5.1 + export templates, JDK 17+, Android SDK with platforms;android-36 and build-tools;36.0.0,
# and the release key passed in the environment (never stored in the repository):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
set -e
WHAT=${1:-both}
G=${GODOT:-godot}
cd "$(dirname "$0")/../.."
VERSION=$(sed -n 's/^version\/name="\(.*\)"/\1/p' export_presets.cfg)
mkdir -p build
"$G" --headless --path . --import >/dev/null 2>&1 || true

prepare_template() {
	# The Godot 4.5.1 template compiles against API 35; Google Play now requires target API 36.
	if [ -f android/build/config.gradle ]; then
		sed -i "s/compileSdk         : 35/compileSdk         : 36/; s/buildTools         : '35.0.0'/buildTools         : '36.0.0'/" android/build/config.gradle
		grep -q "android.suppressUnsupportedCompileSdk" android/build/gradle.properties || \
			echo "android.suppressUnsupportedCompileSdk=36" >> android/build/gradle.properties
	fi
}

export_one() {   # $1 = 0 (apk) / 1 (aab), $2 = output path
	sed -i "s/^gradle_build\/export_format=.*/gradle_build\/export_format=$1/" export_presets.cfg
	if [ ! -f android/build/config.gradle ]; then
		"$G" --headless --path . --install-android-build-template --export-release "Android" "$2" || true
		prepare_template
	fi
	prepare_template
	"$G" --headless --path . --export-release "Android" "$2"
}

if [ "$WHAT" = "apk" ] || [ "$WHAT" = "both" ]; then export_one 0 "build/DeepBounce-$VERSION.apk"; fi
if [ "$WHAT" = "aab" ] || [ "$WHAT" = "both" ]; then export_one 1 "build/DeepBounce-$VERSION.aab"; fi
sed -i "s/^gradle_build\/export_format=.*/gradle_build\/export_format=0/" export_presets.cfg
ls -la build/DeepBounce-$VERSION.*
