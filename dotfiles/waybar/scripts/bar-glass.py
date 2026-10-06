#!/usr/bin/env python3

import os
import re
import subprocess
import sys
from pathlib import Path

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
STYLE_FILE = CONFIG_HOME / "waybar" / "style.css"
STATE_FILE = CONFIG_HOME / "mycfg" / "bar-glass"

ALPHA = "0.20"

BEGIN = "/* doiz-bar-glass:begin */"
END = "/* doiz-bar-glass:end */"

BLOCK_RE = re.compile(
    re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?",
    re.S
)

BG_RE = re.compile(
    r"\.modules-left,\s*\.modules-center,\s*\.modules-right\s*\{[^}]*?"
    r"background:\s*rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,",
    re.S
)


def is_on():
    try:
        return STATE_FILE.read_text().strip() == "on"
    except OSError:
        return False


def set_state(on):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text("on\n" if on else "off\n")


def build_block(r, g, b):
    halo = (
        f"0 0 1px rgba({r}, {g}, {b}, 1.0), "
        f"0 0 3px rgba({r}, {g}, {b}, 1.0), "
        f"0 1px 5px rgba({r}, {g}, {b}, 0.9)"
    )

    return (
        f"{BEGIN}\n"
        ".modules-left,\n"
        ".modules-center,\n"
        ".modules-right {\n"
        f"    background: rgba({r}, {g}, {b}, {ALPHA});\n"
        "    box-shadow: none;\n"
        "}\n\n"
        "window#waybar label {\n"
        f"    text-shadow: {halo};\n"
        "}\n\n"
        "#tray image {\n"
        f"    -gtk-icon-shadow: {halo};\n"
        "}\n"
        f"{END}\n"
    )


def render(text):
    text = BLOCK_RE.sub("", text).rstrip("\n") + "\n"

    if is_on():
        match = BG_RE.search(text)

        if not match:
            return None

        r, g, b = match.groups()
        text += "\n" + build_block(r, g, b)

    return text


def apply():
    if not STYLE_FILE.is_file():
        print(f"Missing: {STYLE_FILE}", file=sys.stderr)
        return 1

    text = render(STYLE_FILE.read_text(encoding="utf-8"))

    if text is None:
        print("Bar background rule not found", file=sys.stderr)
        return 1

    tmp = STYLE_FILE.with_suffix(".css.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, STYLE_FILE)
    return 0


def reload_waybar():
    subprocess.run(
        ["pkill", "-USR2", "-x", "waybar"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        print("on" if is_on() else "off")
        return 0

    if cmd == "toggle":
        set_state(not is_on())
        code = apply()
        reload_waybar()
        return code

    if cmd in ("on", "off"):
        set_state(cmd == "on")
        code = apply()
        reload_waybar()
        return code

    if cmd == "apply":
        return apply()

    print("usage: bar-glass.py [status|toggle|on|off|apply]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
