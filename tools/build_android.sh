#!/usr/bin/env bash
# Builds the Android app with Godot 4.6.2.
#   tools/build_android.sh test      -> build/android/ghostnet-test.apk  (install on your own phone over USB)
#   tools/build_android.sh release   -> build/android/ghostnet.aab       (upload this to Google Play)
# The release build is signed with the upload key from tools/make_upload_key.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
CONFIG="$HOME/.config/ghostnet"
mkdir -p build/android "$CONFIG"

# Godot reads the Android SDK and Java locations from its editor settings, so point them at this Mac's copies.
SETTINGS="$HOME/Library/Application Support/Godot/editor_settings-4.6.tres"
[ -f "$SETTINGS" ] || "$GODOT" --headless --path . --quit >/dev/null 2>&1 || true
set_editor() {   # set_editor <key> <value>: replace the line, or add it under [resource]
	if grep -q "^$1 = " "$SETTINGS"; then
		sed -i '' "s|^$1 = .*|$1 = \"$2\"|" "$SETTINGS"
	else
		sed -i '' "s|^\[resource\]$|[resource]\n$1 = \"$2\"|" "$SETTINGS"
	fi
}
set_editor export/android/android_sdk_path "$ANDROID_HOME"
set_editor export/android/java_sdk_path "$JAVA_HOME"

case "${1:-test}" in
	test)
		# A throwaway debug key with Android's standard public debug values, made on first use.
		if [ ! -f "$CONFIG/debug.keystore" ]; then
			"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$CONFIG/debug.keystore" -alias androiddebugkey -keyalg RSA \
				-keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" >/dev/null
		fi
		export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$CONFIG/debug.keystore"
		export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
		export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
		"$GODOT" --headless --path . --export-debug "Android APK" build/android/ghostnet-test.apk
		echo "Test build: build/android/ghostnet-test.apk  (phone plugged in: adb install -r build/android/ghostnet-test.apk)"
		;;
	release)
		[ -f "$CONFIG/upload.env" ] || { echo "No upload key yet. Run tools/make_upload_key.sh first."; exit 1; }
		source "$CONFIG/upload.env"
		INSTALL=""
		[ -d android/build ] || INSTALL="--install-android-build-template"     # first release build: unpack the Gradle project
		export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$CONFIG/upload.keystore"
		export GODOT_ANDROID_KEYSTORE_RELEASE_USER=ghostnet
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$GHOSTNET_KEY_PASSWORD"
		"$GODOT" --headless --path . $INSTALL --export-release "Android" build/android/ghostnet.aab
		echo "Play Store build: build/android/ghostnet.aab"
		;;
	*) echo "usage: tools/build_android.sh [test|release]"; exit 1 ;;
esac
