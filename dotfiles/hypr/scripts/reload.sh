#!/usr/bin/env bash
set -uo pipefail

hyprctl reload
pkill -SIGUSR2 waybar 2>/dev/null || true
notify-send -a "DoiZ" "Hyprland" "Config reloaded"
