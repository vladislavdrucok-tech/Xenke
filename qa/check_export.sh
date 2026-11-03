#!/bin/sh
# Checks a Godot project the way the phone gets it: export the Android pack, run it outside the editor for a few
# seconds, fail on any script or missing-resource error.   Usage: qa/check_export.sh iso|squad|godot
set -e
G=${GODOT:-/home/user/tools/godot/Godot_v4.3-stable_linux.x86_64}
D=$(mktemp -d)
(cd "$1" && "$G" --headless --path . --export-pack "Android" "$D/game.pck" >/dev/null 2>&1)
(cd "$D" && timeout -s INT 20 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --main-pack game.pck --rendering-driver opengl3 --resolution 960x442 > run.log 2>&1 || true)
if grep -E "SCRIPT ERROR|Resource file not found|Failed to load" "$D/run.log"; then echo "EXPORT CHECK FAILED: $1"; exit 1; fi
echo "export check ok: $1"
