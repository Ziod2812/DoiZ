#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

GEOMETRY="$(slurp)"
[ -z "$GEOMETRY" ] && exit 0

FILE="$DIR/area-$(date +%Y-%m-%d_%H-%M-%S).png"
grim -g "$GEOMETRY" "$FILE"
wl-copy < "$FILE"
notify-send -a "DoiZ" "Screenshot saved" "$FILE"
