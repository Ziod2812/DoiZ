#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${DOIZ_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

[ -d "$WALLPAPER_DIR" ] || exit 0

WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | shuf -n 1)"

[ -z "$WALLPAPER" ] && exit 0

"$SCRIPT_DIR/wallpaper.sh" "$WALLPAPER"
