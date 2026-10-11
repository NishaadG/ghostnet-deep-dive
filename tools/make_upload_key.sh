#!/usr/bin/env bash
# Run ONCE, yourself: creates the private upload key that signs the Play Store build.
# It asks for a password (you choose it) and stores the key and password in ~/.config/ghostnet/,
# outside the project, so they never go to GitHub. BACK UP that folder somewhere safe.
set -euo pipefail
DIR="$HOME/.config/ghostnet"
KEY="$DIR/upload.keystore"
KEYTOOL="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}/bin/keytool"
if [ -f "$KEY" ]; then echo "An upload key already exists at $KEY (not touching it)."; exit 0; fi
mkdir -p "$DIR" && chmod 700 "$DIR"
read -s -p "Choose a password for the upload key (at least 6 characters): " PASS; echo
read -s -p "Type it again: " PASS2; echo
[ "$PASS" = "$PASS2" ] || { echo "The passwords did not match."; exit 1; }
"$KEYTOOL" -genkeypair -keystore "$KEY" -alias ghostnet -keyalg RSA -keysize 2048 -validity 10000 \
	-storepass "$PASS" -keypass "$PASS" -dname "CN=GHOSTNET Deep Dive, O=GHOSTNET team" >/dev/null
printf 'GHOSTNET_KEY_PASSWORD=%q\n' "$PASS" > "$DIR/upload.env"
chmod 600 "$KEY" "$DIR/upload.env"
echo "Upload key created in $DIR. Back up that folder (for example to a USB stick or a password manager)."
