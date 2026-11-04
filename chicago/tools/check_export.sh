#!/bin/sh
# Exports the Android .pck (what the phone gets, without the APK wrapper), runs it for 20 s under a virtual display
# with a new game and the touch UI, and fails on script or missing-resource errors.
# Usage: GODOT=<Godot 4.3-stable> chicago/tools/check_export.sh      (needs xvfb-run)
set -e
cd "$(dirname "$0")/.."
G=${GODOT:?set GODOT}
D=$(mktemp -d)
"$G" --headless --path . --export-pack "Android" "$D/game.pck" >/dev/null 2>&1
(cd "$D" && timeout -s INT 20 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --main-pack game.pck --rendering-driver opengl3 \
  --resolution 1280x720 -- --newgame --touch > run.log 2>&1 || true)
if grep -E "SCRIPT ERROR|Resource file not found|Failed to load|Parse Error" "$D/run.log"; then echo "EXPORT CHECK FAILED"; exit 1; fi
echo "export check ok ($(du -h "$D/game.pck" | cut -f1) pck)"
