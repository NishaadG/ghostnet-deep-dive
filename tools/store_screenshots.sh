#!/usr/bin/env bash
# Makes the Google Play listing pictures in store/: six 1280 x 720 phone screenshots and the
# 1024 x 500 feature graphic. Needs a real window: run it while the screen is on and unlocked
# (macOS stops drawing windows when the display sleeps, and the pictures come out frozen).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot}"
TMP="$(mktemp -d)"
shot() {   # shot <out name> <frame to keep> <scene> <args...>
	local name=$1 frame=$2 scene=$3; shift 3
	mkdir -p "$TMP/$name"
	"$GODOT" --path . "$scene" --write-movie "$TMP/$name/f.png" --fixed-fps 30 --quit-after $((frame + 1)) -- "$@" real >/dev/null 2>&1
	cp "$TMP/$name/f$(printf %08d "$frame").png" "store/$name.png"
}
shot screenshot_1 110 res://tests/shots.tscn x=0 touch                         # launch and splash on the reef
shot screenshot_2 120 res://tests/shots.tscn x=9500 touch                      # piranhas in the Drowned City
shot screenshot_3 150 res://tests/shots.tscn x=31000 touch                     # electric ray in the Trench
shot screenshot_4 90 res://tests/menu_shot.tscn screen=cutscene scene=intro beat=3
shot screenshot_5 90 res://tests/menu_shot.tscn screen=cutscene scene=ending beat=4
shot screenshot_6 30 res://tests/menu_shot.tscn screen=workshop
shot feature_full 120 res://tools/feature_graphic.tscn
ffmpeg -loglevel error -y -i store/feature_full.png -vf "crop=1280:625:0:20,scale=1024:500:flags=lanczos" store/feature_1024x500.png
rm -f store/feature_full.png
rm -rf "$TMP"
echo "Store pictures written to store/. Look through them: the dives are random, so re-run for a better moment."
