#!/bin/sh
# Exports the game pack the way the phone gets it and runs it outside the editor for a few
# seconds (menu → tutorial → shift via the screenshot tour); fails on any script/resource error.
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-/home/user/tools/godot/Godot_v4.3-stable_linux.x86_64}
D=$(mktemp -d)
"$G" --headless --path . --export-pack "Android" "$D/game.pck" >/dev/null 2>&1
(cd "$D" && timeout -s INT 200 xvfb-run -a -s "-screen 0 1280x1024x24" "$G" --main-pack game.pck --rendering-driver opengl3 --resolution 360x780 -- --shots="$D/shots" > run.log 2>&1 || true)
if grep -E "SCRIPT ERROR|Resource file not found|Failed to load|Parse Error" "$D/run.log"; then echo "EXPORT CHECK FAILED"; exit 1; fi
ls "$D/shots" | wc -l | xargs echo "screenshots:"
echo "export check ok ($D)"
