#!/bin/sh
# Fails if any original Afterfall file differs from the last commit (the Chicago project must never edit them).
cd "$(dirname "$0")/../.."
git diff --quiet HEAD -- iso squad godot dist builds docs art scripts qa trading-bot README.md ASSETS_NEEDED.md *.mjs \
  && echo "legacy untouched" || { echo "LEGACY FILES CHANGED"; git diff --stat HEAD -- iso squad godot dist builds docs art scripts qa; exit 1; }
