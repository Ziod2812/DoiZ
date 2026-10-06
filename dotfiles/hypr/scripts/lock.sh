#!/usr/bin/env bash
set -uo pipefail

if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

hyprlock
