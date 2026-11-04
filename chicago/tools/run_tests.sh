#!/bin/sh
# Imports the project, runs the headless test suite and fails on script errors.
# Usage: GODOT=/path/to/Godot_v4.3-stable_linux.x86_64 chicago/tools/run_tests.sh [--only=<file part>]
set -e
cd "$(dirname "$0")/.."
G=${GODOT:?set GODOT to a Godot 4.3-stable binary}
"$G" --headless --import --path . >/dev/null 2>&1 || true
LOG=$(mktemp)
"$G" --headless --path . res://tests/runner.tscn -- "$@" > "$LOG" 2>&1 || STATUS=$?
grep -E "^(OK|FAIL|TESTS)" "$LOG"
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" "$LOG"; then echo "SCRIPT ERRORS"; exit 1; fi
exit ${STATUS:-0}
