#!/bin/sh
# UI-прохід із скриншотами: tools/run_ui_test.sh <днів> <папка_скриншотів> [WxH]
cd "$(dirname "$0")/.." || exit 1
DAYS=${1:-10}; SHOTS=${2:-}; RES=${3:-720x1280}
mkdir -p "$SHOTS" 2>/dev/null
exec xvfb-run -a -s "-screen 0 1400x1700x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution "$RES" -s res://tests/ui_smoke.gd -- --ld-test --days="$DAYS" --shots="$SHOTS"
