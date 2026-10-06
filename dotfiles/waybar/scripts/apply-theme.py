#!/usr/bin/env python3
import configparser
import colorsys
import os
import re
import shutil
import signal
import subprocess
import sys
from pathlib import Path
from tempfile import NamedTemporaryFile

SCRIPT_DIR = Path(__file__).resolve().parent
WAYBAR_DIR = SCRIPT_DIR.parent
PROJECT_CONFIG = WAYBAR_DIR.parent.resolve()

THEME_DIR = PROJECT_CONFIG / "theme"
THEME_FILE = THEME_DIR / "theme.conf"

TEMPLATE_FILE = WAYBAR_DIR / "style.css.template"
STYLE_FILE = WAYBAR_DIR / "style.css"
CONFIG_FILE = WAYBAR_DIR / "config.jsonc"

BTOP_DIR = PROJECT_CONFIG / "btop"
BTOP_THEME_DIR = BTOP_DIR / "themes"
BTOP_THEME_FILE = BTOP_THEME_DIR / "doiz.theme"
BTOP_CONFIG_FILE = BTOP_DIR / "btop.conf"

CAVA_DIR = PROJECT_CONFIG / "cava"
CAVA_CONFIG_FILE = CAVA_DIR / "config"
CAVA_TERMINAL_FILE = CAVA_DIR / "config_terminal"

HYPR_BORDER_FILE = PROJECT_CONFIG / "hypr" / "local" / "theme-border.lua"

GTK_TEMPLATE_FILE = PROJECT_CONFIG / "gtk-3.0" / "gtk.css.template"
GTK_CSS_FILE = PROJECT_CONFIG / "gtk-3.0" / "gtk.css"

GTK_SCHEMA = "org.gnome.desktop.interface"
GTK_THEME_PREFIX = "DoiZ-Dyn-"
GTK_THEME_SLOTS = ("A", "B")

DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")

GTK_THEMES_DIR = DATA_HOME / "themes"
GTK3_SETTINGS_FILE = CONFIG_HOME / "gtk-3.0" / "settings.ini"
GTK4_SETTINGS_FILE = CONFIG_HOME / "gtk-4.0" / "settings.ini"
QT6CT_CONFIG_FILE = PROJECT_CONFIG / "qt6ct" / "qt6ct.conf"

ICON_THEME_PREFIX = "DoiZ-Icons-"
ICON_THEME_SLOTS = ("A", "B")
ICON_SOURCE_THEME = "Papirus"
ICON_SEARCH_DIRS = (Path.home() / ".icons", DATA_HOME / "icons", Path("/usr/share/icons"))
ICON_BLUE_MARKER = "#5294e2"
ICON_BLUE_SATURATION = 0.71
ICON_BLUE_LIGHTNESS = 0.60
ICON_BLUE_HUE_RANGE = (196.0, 228.0)
ICON_HEX_PATTERN = re.compile(r"#[0-9a-fA-F]{6}\b")

def clamp(value):
    return max(0, min(255, int(round(value))))

def rgb_to_hex(rgb):
    return "#{:02X}{:02X}{:02X}".format(
        clamp(rgb[0]),
        clamp(rgb[1]),
        clamp(rgb[2])
    )

def mix(a, b, amount):
    return (
        clamp(a[0] * (1 - amount) + b[0] * amount),
        clamp(a[1] * (1 - amount) + b[1] * amount),
        clamp(a[2] * (1 - amount) + b[2] * amount)
    )

def rgba(color, alpha):
    value = color.lstrip("#")

    r = int(value[0:2], 16)
    g = int(value[2:4], 16)
    b = int(value[4:6], 16)

    return f"rgba({r}, {g}, {b}, {alpha})"

def boost_color(rgb, mode="dark"):
    r, g, b = [x / 255.0 for x in rgb]

    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    if s < 0.18:
        s = 0.48
    elif s < 0.35:
        s = 0.55
    else:
        s = min(0.82, s * 1.35)

    if mode == "light":
        v = max(0.36, min(0.60, v))
    else:
        v = max(0.55, min(0.88, v + 0.12))

    r, g, b = colorsys.hsv_to_rgb(h, s, v)

    return (
        clamp(r * 255),
        clamp(g * 255),
        clamp(b * 255)
    )

def load_theme():
    parser = configparser.ConfigParser()

    if THEME_FILE.exists():
        parser.read(THEME_FILE)

    for section in (
        "theme",
        "colors",
        "dynamic",
        "targets"
    ):
        if not parser.has_section(section):
            parser.add_section(section)

    return parser

def write_atomic(path, content):
    path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    with NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False
    ) as temporary:
        temporary.write(content)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)

    os.replace(
        temporary_path,
        path
    )

def keep_dynamic_flag(parser):
    fresh = configparser.ConfigParser()

    try:
        fresh.read(THEME_FILE)
        value = fresh.get("dynamic", "enabled")
    except (configparser.Error, OSError):
        return

    if not parser.has_section("dynamic"):
        parser.add_section("dynamic")

    parser["dynamic"]["enabled"] = value

def save_theme(parser, colors, mode="dark"):
    parser["theme"]["name"] = "DoiZ"
    parser["theme"]["mode"] = mode

    for key, value in colors.items():
        parser["colors"][key] = value

    for key, value in (
        ("enabled", "true"),
        ("source", "wallpaper"),
        ("extractor", "colorthief"),
        ("update_on_wallpaper_change", "true")
    ):
        parser["dynamic"].setdefault(key, value)

    for key in ("waybar", "quickshell", "btop", "cava", "kitty", "rofi", "gtk"):
        parser["targets"].setdefault(key, "true")

    from io import StringIO

    keep_dynamic_flag(parser)

    output = StringIO()
    parser.write(output)

    write_atomic(
        THEME_FILE,
        output.getvalue()
    )

PALETTES = {
    "dark": {
        "background": (18, 20, 31),
        "surface": (31, 34, 49),
        "surface_alt": (49, 52, 69),
        "foreground": (235, 238, 250),
        "subtext": (205, 211, 230),
        "muted": (142, 150, 173),
        "blue": (137, 180, 250),
        "cyan": (122, 162, 247),
        "green": (166, 227, 161),
        "red": (243, 139, 168),
        "yellow": (230, 197, 138),
    },
    "light": {
        "background": (244, 245, 251),
        "surface": (230, 233, 244),
        "surface_alt": (213, 217, 234),
        "foreground": (27, 30, 46),
        "subtext": (62, 67, 90),
        "muted": (104, 111, 138),
        "blue": (40, 80, 190),
        "cyan": (20, 105, 170),
        "green": (30, 125, 75),
        "red": (185, 45, 85),
        "yellow": (150, 100, 10),
    },
}

WEIGHTS = {
    "dark": {
        "background": 0.82,
        "surface": 0.64,
        "surface_alt": 0.48,
        "foreground": 0.88,
        "subtext": 0.72,
        "muted": 0.60,
        "blue": 0.58,
        "cyan": 0.58,
        "green": 0.64,
        "red": 0.64,
        "yellow": 0.64,
    },
    "light": {
        "background": 0.95,
        "surface": 0.91,
        "surface_alt": 0.85,
        "foreground": 0.90,
        "subtext": 0.80,
        "muted": 0.70,
        "blue": 0.75,
        "cyan": 0.75,
        "green": 0.75,
        "red": 0.75,
        "yellow": 0.75,
    },
}

def hex_to_rgb(value):
    value = value.strip().lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16)
    )

def build_palette(dominant, mode):
    base = PALETTES[mode]
    accent = boost_color(dominant, mode)

    weights = WEIGHTS[mode]

    colors = {
        key: rgb_to_hex(mix(accent, base[key], weights[key]))
        for key in weights
    }

    accent_alt = mix(accent, (255, 255, 255), 0.24)

    if mode == "light":
        accent_dark = mix(accent, (255, 255, 255), 0.72)
    else:
        accent_dark = mix(accent, (0, 0, 0), 0.40)

    colors["accent"] = rgb_to_hex(accent)
    colors["accent_alt"] = rgb_to_hex(accent_alt)
    colors["accent_dark"] = rgb_to_hex(accent_dark)
    colors["dominant"] = rgb_to_hex(dominant)

    return colors

def extract_colors(wallpaper, mode="dark"):
    from colorthief import ColorThief

    dominant = ColorThief(str(wallpaper)).get_color(quality=10)

    return build_palette(dominant, mode)

def render_waybar(colors):
    if not TEMPLATE_FILE.is_file():
        print(
            f"Missing: {TEMPLATE_FILE}"
        )
        sys.exit(1)

    text = TEMPLATE_FILE.read_text(
        encoding="utf-8"
    )

    replacements = {
        "@BACKGROUND@":
            colors["background"],

        "@BACKGROUND_ALPHA@":
            rgba(
                colors["background"],
                "0.88"
            ),

        "@BACKGROUND_TOOLTIP@":
            rgba(
                colors["background"],
                "0.97"
            ),

        "@FOREGROUND@":
            colors["foreground"],

        "@SUBTEXT@":
            colors["subtext"],

        "@MUTED@":
            colors["muted"],

        "@ACCENT@":
            colors["accent"],

        "@ACCENT_ALT@":
            colors["accent_alt"],

        "@ACCENT_ALPHA@":
            rgba(
                colors["accent"],
                "0.28"
            ),

        "@ACCENT_ALT_ALPHA@":
            rgba(
                colors["accent_alt"],
                "0.85"
            ),

        "@ACCENT_ALT_HOVER@":
            rgba(
                colors["accent_alt"],
                "0.45"
            ),

        "@BLUE@":
            colors["blue"],

        "@CYAN@":
            colors["cyan"],

        "@GREEN@":
            colors["green"],

        "@RED@":
            colors["red"],

        "@YELLOW@":
            colors["yellow"]
    }

    for token, value in replacements.items():
        text = text.replace(
            token,
            value
        )

    glass = SCRIPT_DIR / "bar-glass.py"
    glass_text = None

    if glass.is_file():
        try:
            import importlib.util

            spec = importlib.util.spec_from_file_location(
                "doiz_bar_glass",
                glass
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            glass_text = module.render(text)
        except Exception:
            glass_text = None

    if glass_text is not None:
        text = glass_text

    write_atomic(
        STYLE_FILE,
        text
    )

def render_btop(colors):
    BTOP_THEME_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    theme = f'''theme[main_bg]="{colors["background"]}"
theme[main_fg]="{colors["foreground"]}"

theme[title]="{colors["foreground"]}"
theme[hi_fg]="{colors["accent"]}"

theme[selected_bg]="{colors["surface"]}"
theme[selected_fg]="{colors["accent"]}"

theme[inactive_fg]="{colors["muted"]}"
theme[graph_text]="{colors["subtext"]}"
theme[meter_bg]="{colors["surface_alt"]}"

theme[proc_misc]="{colors["blue"]}"
theme[cpu_box]="{colors["accent"]}"
theme[mem_box]="{colors["green"]}"
theme[net_box]="{colors["blue"]}"
theme[proc_box]="{colors["cyan"]}"
theme[div_line]="{colors["surface_alt"]}"

theme[temp_start]="{colors["green"]}"
theme[temp_mid]="{colors["yellow"]}"
theme[temp_end]="{colors["red"]}"

theme[cpu_start]="{colors["blue"]}"
theme[cpu_mid]="{colors["cyan"]}"
theme[cpu_end]="{colors["accent"]}"

theme[free_start]="{colors["green"]}"
theme[free_mid]="{colors["blue"]}"
theme[free_end]="{colors["accent"]}"

theme[cached_start]="{colors["blue"]}"
theme[cached_mid]="{colors["cyan"]}"
theme[cached_end]="{colors["accent"]}"

theme[available_start]="{colors["yellow"]}"
theme[available_mid]="{colors["red"]}"
theme[available_end]="{colors["red"]}"

theme[used_start]="{colors["green"]}"
theme[used_mid]="{colors["cyan"]}"
theme[used_end]="{colors["blue"]}"

theme[download_start]="{colors["blue"]}"
theme[download_mid]="{colors["cyan"]}"
theme[download_end]="{colors["accent"]}"

theme[upload_start]="{colors["accent"]}"
theme[upload_mid]="{colors["red"]}"
theme[upload_end]="{colors["red"]}"

theme[process_start]="{colors["blue"]}"
theme[process_mid]="{colors["cyan"]}"
theme[process_end]="{colors["accent"]}"

theme[read_start]="{colors["blue"]}"
theme[read_mid]="{colors["cyan"]}"
theme[read_end]="{colors["green"]}"

theme[write_start]="{colors["accent"]}"
theme[write_mid]="{colors["yellow"]}"
theme[write_end]="{colors["red"]}"

theme[proc_pause_bg]="{colors["surface"]}"
theme[proc_follow_bg]="{colors["surface_alt"]}"
theme[proc_banner_bg]="{colors["surface"]}"
theme[proc_banner_fg]="{colors["foreground"]}"

theme[followed_bg]="{colors["surface"]}"
theme[followed_fg]="{colors["accent"]}"
'''

    write_atomic(
        BTOP_THEME_FILE,
        theme
    )

CAVA_TERMINAL_COLOR_SECTION = """[color]
gradient = 0
background = default
foreground = '{foreground}'
"""

CAVA_FALLBACK_CONFIG = """[general]
framerate = 60
autosens = 1
sensitivity = 180

[input]
method = pipewire
source = auto

[output]
method = ncurses
channels = mono

[smoothing]
monstercat = 1
waves = 0
noise_reduction = 60
"""

CAVA_COLOR_SECTION_PATTERN = re.compile(
    r"^\[color\][^\n]*\n.*?(?=^\[|\Z)",
    re.MULTILINE | re.DOTALL
)

def cava_with_colors(text, colors):
    section = CAVA_TERMINAL_COLOR_SECTION.format(
        foreground=colors["accent"]
    )

    if CAVA_COLOR_SECTION_PATTERN.search(text):
        text = CAVA_COLOR_SECTION_PATTERN.sub(
            lambda _: section + "\n",
            text,
            count=1
        )
    else:
        text = text.rstrip() + "\n\n" + section

    return text.rstrip() + "\n"

def render_cava(colors):
    if CAVA_TERMINAL_FILE.is_file():
        base = CAVA_TERMINAL_FILE.read_text(encoding="utf-8")
    else:
        base = CAVA_FALLBACK_CONFIG

    write_atomic(
        CAVA_CONFIG_FILE,
        cava_with_colors(base, colors)
    )

def render_cava_terminal(colors):
    if not CAVA_TERMINAL_FILE.is_file():
        print(f"Cava terminal: missing {CAVA_TERMINAL_FILE}, skipped")
        return

    text = CAVA_TERMINAL_FILE.read_text(encoding="utf-8")

    write_atomic(
        CAVA_TERMINAL_FILE,
        cava_with_colors(text, colors)
    )

def find_user_pids(name):
    uid = os.getuid()
    pids = []

    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue

        try:
            if proc.stat().st_uid != uid:
                continue

            if (proc / "comm").read_text(encoding="utf-8").strip() != name:
                continue
        except OSError:
            continue

        pids.append(int(proc.name))

    return pids

def signal_user_processes(name, sig):
    count = 0

    for pid in find_user_pids(name):
        try:
            os.kill(pid, sig)
            count += 1
        except (ProcessLookupError, PermissionError):
            continue

    return count

def reload_cava_terminal():
    count = signal_user_processes("cava", signal.SIGUSR2)

    if count:
        print(f"Cava recolored: {count}")

def ensure_btop_config():
    BTOP_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    theme_path = str(
        BTOP_THEME_FILE.resolve()
    )

    if BTOP_CONFIG_FILE.exists():
        lines = BTOP_CONFIG_FILE.read_text(
            encoding="utf-8"
        ).splitlines()
    else:
        lines = []

    updated = []
    found = False

    for line in lines:
        stripped = line.strip()

        if (
            stripped.startswith(
                "color_theme"
            )
            and "=" in stripped
        ):
            updated.append(
                f'color_theme = "{theme_path}"'
            )

            found = True
        else:
            updated.append(line)

    if not found:
        updated.insert(
            0,
            f'color_theme = "{theme_path}"'
        )

    write_atomic(
        BTOP_CONFIG_FILE,
        "\n".join(
            updated
        ).rstrip() + "\n"
    )

def reload_btop():
    count = signal_user_processes("btop", signal.SIGUSR2)

    if count:
        print(f"Btop hot-reloaded: {count}")
    else:
        print("Btop: no running instance")

def waybar_pids():
    result = subprocess.run(
        ["pgrep", "-x", "waybar"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )

    return [
        int(pid) for pid in result.stdout.split()
        if pid.isdigit()
    ]

def process_start_epoch(pid):
    stat = Path(f"/proc/{pid}/stat").read_text()
    ticks = int(stat.rsplit(")", 1)[1].split()[19])
    boot = None

    for line in Path("/proc/stat").read_text().splitlines():
        if line.startswith("btime "):
            boot = int(line.split()[1])
            break

    if boot is None:
        raise OSError("btime missing")

    return boot + ticks / os.sysconf("SC_CLK_TCK")

def waybar_hot_reloads(pids):
    try:
        text = CONFIG_FILE.read_text(encoding="utf-8")
        config_mtime = CONFIG_FILE.stat().st_mtime
    except OSError:
        return False

    if not re.search(r'"reload_style_on_change"\s*:\s*true', text):
        return False

    for pid in pids:
        try:
            if process_start_epoch(pid) < config_mtime:
                return False
        except (OSError, ValueError, IndexError):
            return False

    return True

def reload_waybar():
    off_flag = Path(
        os.environ.get("XDG_STATE_HOME")
        or Path.home() / ".local" / "state"
    ) / "doiz" / "waybar-off"

    if off_flag.exists():
        return

    pids = waybar_pids()

    if not pids:
        return

    if waybar_hot_reloads(pids):
        return

    subprocess.run(
        ["pkill", "-x", "waybar"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    try:
        subprocess.Popen(
            [
                "waybar",
                "-c",
                str(CONFIG_FILE),
                "-s",
                str(STYLE_FILE)
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
    except FileNotFoundError:
        print("waybar not found, skipped")

def render_hypr_border(colors):
    value = colors["subtext"].lstrip("#").lower()

    write_atomic(
        HYPR_BORDER_FILE,
        "return {\n"
        f'    active = "rgba({value}de)",\n'
        f'    inactive = "rgba({value}de)",\n'
        "}\n"
    )

def reload_hypr():
    active = None
    inactive = None

    try:
        text = HYPR_BORDER_FILE.read_text(encoding="utf-8")
        active = re.search(r'active\s*=\s*"([^"]+)"', text)
        inactive = re.search(r'inactive\s*=\s*"([^"]+)"', text)
    except OSError:
        pass

    if active and inactive:
        expr = (
            "hl.config({ general = { col = { "
            f'active_border = "{active.group(1)}", '
            f'inactive_border = "{inactive.group(1)}" '
            "} } })"
        )

        try:
            result = subprocess.run(
                ["hyprctl", "eval", expr],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5
            )

            if result.returncode == 0:
                return
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    try:
        subprocess.run(
            ["hyprctl", "reload"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("hyprctl not available, skipped")

def on_color(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    return "#101218" if lum > 0.55 else "#FFFFFF"

def render_kitty(colors, mode):
    if mode == "light":
        ansi = [
            colors["foreground"], colors["red"], colors["green"],
            colors["yellow"], colors["blue"], colors["accent"],
            colors["cyan"], colors["surface_alt"],
            colors["muted"], colors["red"], colors["green"],
            colors["yellow"], colors["blue"], colors["accent"],
            colors["cyan"], colors["background"],
        ]
        opacity = "0.88"
    else:
        ansi = [
            colors["surface"], colors["red"], colors["green"],
            colors["yellow"], colors["blue"], colors["accent_alt"],
            colors["cyan"], colors["subtext"],
            colors["muted"], colors["red"], colors["green"],
            colors["yellow"], colors["blue"], colors["accent_alt"],
            colors["cyan"], colors["foreground"],
        ]
        opacity = "0.20"

    selection = rgb_to_hex(
        mix(hex_to_rgb(colors["background"]), hex_to_rgb(colors["accent"]), 0.35)
    )

    lines = [
        f"foreground {colors['foreground']}",
        f"background {colors['background']}",
        f"background_opacity {opacity}",
        "",
        f"cursor {colors['accent']}",
        f"cursor_text_color {colors['background']}",
        f"selection_foreground {colors['foreground']}",
        f"selection_background {selection}",
        "",
    ]

    lines += [f"color{i} {c}" for i, c in enumerate(ansi)]

    write_atomic(
        PROJECT_CONFIG / "kitty" / "theme.conf",
        "\n".join(lines) + "\n"
    )

def reload_kitty():
    subprocess.run(
        ["pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

def set_ini_keys(path, section, values):
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    header = f"[{section}]"
    out = []
    in_section = False
    seen_section = False
    pending = dict(values)

    def flush():
        for key, value in pending.items():
            out.append(f"{key}={value}")
        pending.clear()

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                flush()
            in_section = stripped == header
            seen_section = seen_section or in_section
            out.append(line)
            continue

        if in_section and "=" in line:
            key = line.split("=", 1)[0].strip()
            if key in pending:
                out.append(f"{key}={pending.pop(key)}")
                continue

        out.append(line)

    if in_section:
        flush()

    if not seen_section:
        out += [header]
        flush()

    write_atomic(path, "\n".join(out).rstrip() + "\n")

def render_qt6ct(colors, mode):
    def rgb(name):
        return hex_to_rgb(colors[name])

    def q(value):
        if isinstance(value, str):
            value = hex_to_rgb(value)
        return "#ff{:02x}{:02x}{:02x}".format(*value)

    white = (255, 255, 255)
    black = (0, 0, 0)
    fg, bg = rgb("foreground"), rgb("background")
    surface, alt = rgb("surface"), rgb("surface_alt")
    muted, accent = rgb("muted"), rgb("accent")

    def build(text, button_text):
        return [
            q(text), q(surface), q(mix(surface, white, 0.5)),
            q(mix(surface, white, 0.25)), q(mix(bg, black, 0.35)),
            q(alt), q(text), q(white), q(button_text),
            q(surface), q(bg), q(black), q(accent),
            q(on_color(colors["accent"])), q(rgb("blue")),
            q(rgb("accent_alt")), q(alt), q(black), q(surface),
            q(fg), q(muted), q(accent),
        ]

    active = ", ".join(build(fg, fg))
    disabled = ", ".join(build(muted, muted))

    scheme = PROJECT_CONFIG / "qt6ct" / "colors" / "doiz.conf"

    write_atomic(
        scheme,
        "[ColorScheme]\n"
        f"active_colors={active}\n"
        f"inactive_colors={active}\n"
        f"disabled_colors={disabled}\n"
    )

    set_ini_keys(
        PROJECT_CONFIG / "qt6ct" / "qt6ct.conf",
        "Appearance",
        {
            "custom_palette": "true",
            "color_scheme_path": str(scheme),
            "style": "Fusion",
        }
    )

def render_gtk_css(colors):
    if not GTK_TEMPLATE_FILE.is_file():
        return ""

    text = GTK_TEMPLATE_FILE.read_text(encoding="utf-8")

    replacements = {
        "@BACKGROUND@": colors["background"],
        "@FOREGROUND@": colors["foreground"],
        "@SUBTEXT@": colors["subtext"],
        "@MUTED@": colors["muted"],
        "@ACCENT@": colors["accent"],
        "@ACCENT_ALT@": colors["accent_alt"],
        "@SURFACE@": colors["surface"],
        "@BG_WINDOW@": rgba(colors["background"], "0.62"),
        "@BG_POPUP@": rgba(colors["background"], "0.96"),
        "@BG_CONTENT@": rgba(colors["background"], "0.35"),
        "@BG_FIELD@": rgba(colors["surface"], "0.55"),
        "@BG_SELECT@": rgba(colors["accent"], "0.55"),
        "@BORDER@": rgba(colors["accent_alt"], "0.70"),
        "@ACCENT_ALPHA@": rgba(colors["accent"], "0.30"),
        "@ACCENT_STRONG@": rgba(colors["accent"], "0.60"),
        "@MUTED_ALPHA@": rgba(colors["muted"], "0.55"),
    }

    for key, value in replacements.items():
        text = text.replace(key, value)

    return text

def gsettings_get(key):
    try:
        result = subprocess.run(
            ["gsettings", "get", GTK_SCHEMA, key],
            capture_output=True,
            text=True,
            timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""

    return result.stdout.strip().strip("'")

def gsettings_set(key, value):
    try:
        subprocess.run(
            ["gsettings", "set", GTK_SCHEMA, key, value],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("gsettings not available, GTK theme switch skipped")

def gtk_base_import(base, sys_mode):
    names = ["gtk-dark.css", "gtk.css"] if sys_mode == "dark" else ["gtk.css"]

    for root in (Path.home() / ".themes", GTK_THEMES_DIR, Path("/usr/share/themes")):
        for name in names:
            candidate = root / base / "gtk-3.0" / name

            if candidate.is_file():
                return candidate.as_uri()

    variant = "gtk-contained-dark.css" if sys_mode == "dark" else "gtk-contained.css"

    return f"resource:///org/gtk/libgtk/theme/Adwaita/{variant}"

def write_gtk_theme(name, base, sys_mode, css):
    theme_dir = GTK_THEMES_DIR / name

    write_atomic(
        theme_dir / "index.theme",
        "[Desktop Entry]\n"
        "Type=X-GNOME-Metatheme\n"
        f"Name={name}\n"
        "Comment=DoiZ dynamic GTK theme\n"
        "Encoding=UTF-8\n\n"
        "[X-GNOME-Metatheme]\n"
        f"GtkTheme={name}\n"
    )

    content = f'@import url("{gtk_base_import(base, sys_mode)}");\n\n{css}'

    write_atomic(theme_dir / "gtk-3.0" / "gtk.css", content)
    write_atomic(theme_dir / "gtk-3.0" / "gtk-dark.css", content)

def resolve_gtk_base(parser, sys_mode, override):
    current = gsettings_get("gtk-theme")
    stored = parser["theme"].get("gtk_base", "").strip()

    if override:
        return override

    if current and not current.startswith(GTK_THEME_PREFIX):
        return current

    if stored:
        return stored

    return "Adwaita-dark" if sys_mode == "dark" else "Adwaita"

def apply_gtk_theme(parser, colors, sys_mode, base_override=None):
    base = resolve_gtk_base(parser, sys_mode, base_override)
    current = gsettings_get("gtk-theme")

    slot = GTK_THEME_SLOTS[0]

    if current == GTK_THEME_PREFIX + GTK_THEME_SLOTS[0]:
        slot = GTK_THEME_SLOTS[1]

    name = GTK_THEME_PREFIX + slot

    write_gtk_theme(name, base, sys_mode, render_gtk_css(colors))
    write_atomic(GTK_CSS_FILE, "\n")

    parser["theme"]["gtk_base"] = base
    write_parser(parser)

    set_ini_keys(GTK3_SETTINGS_FILE, "Settings", {"gtk-theme-name": name})
    gsettings_set("gtk-theme", name)

def current_icon_themes():
    names = {gsettings_get("icon-theme")}
    parser = configparser.RawConfigParser(strict=False, interpolation=None)

    try:
        parser.read(GTK3_SETTINGS_FILE, encoding="utf-8")
        names.add(parser.get("Settings", "gtk-icon-theme-name", fallback="").strip())
    except (configparser.Error, OSError):
        pass

    return names

def find_icon_theme(name):
    for root in ICON_SEARCH_DIRS:
        candidate = root / name

        if (candidate / "index.theme").is_file():
            return candidate

    return None

def recolor_folder_hex(value, accent_hls):
    r, g, b = [x / 255.0 for x in hex_to_rgb(value)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    hue = h * 360.0

    if hue < ICON_BLUE_HUE_RANGE[0] or hue > ICON_BLUE_HUE_RANGE[1] or s < 0.3:
        return value

    accent_h, accent_l, accent_s = accent_hls
    new_s = min(1.0, s * accent_s / ICON_BLUE_SATURATION)
    new_l = min(0.95, l * accent_l / ICON_BLUE_LIGHTNESS)
    nr, ng, nb = colorsys.hls_to_rgb(accent_h, new_l, new_s)

    return rgb_to_hex((nr * 255, ng * 255, nb * 255)).lower()

def recolor_folder_svg(text, accent_hls):
    cache = {}

    def replace(match):
        key = match.group(0).lower()

        if key not in cache:
            cache[key] = recolor_folder_hex(key, accent_hls)

        return cache[key]

    return ICON_HEX_PATTERN.sub(replace, text)

def build_folder_icon_theme(source, target, base_name, name, accent_hls):
    if target.exists():
        shutil.rmtree(target)

    index = configparser.RawConfigParser(strict=False, interpolation=None)
    index.optionxform = str
    index.read(source / "index.theme", encoding="utf-8")

    directories = []

    for places in sorted(source.glob("*/places")):
        size_dir = places.parent.name
        rel = f"{size_dir}/places"

        if size_dir == "symbolic" or not index.has_section(rel):
            continue

        out = target / size_dir / "places"
        out.mkdir(parents=True, exist_ok=True)
        written = set()

        for entry in places.iterdir():
            if entry.is_symlink() or entry.suffix != ".svg":
                continue

            text = entry.read_text(encoding="utf-8", errors="ignore")

            if ICON_BLUE_MARKER not in text.lower():
                continue

            (out / entry.name).write_text(
                recolor_folder_svg(text, accent_hls),
                encoding="utf-8"
            )
            written.add(entry.name)

        places_real = Path(os.path.realpath(places))

        for entry in places.iterdir():
            if not entry.is_symlink():
                continue

            final = Path(os.path.realpath(entry))

            if final.parent == places_real and final.name in written:
                os.symlink(os.readlink(entry), out / entry.name)

        if not written:
            shutil.rmtree(target / size_dir)
            continue

        directories.append(rel)

    lines = [
        "[Icon Theme]",
        f"Name={name}",
        "Comment=DoiZ folder colors",
        f"Inherits={base_name}",
        "Directories=" + ",".join(directories),
        "",
    ]

    for rel in directories:
        lines.append(f"[{rel}]")
        lines += [f"{key}={value}" for key, value in index.items(rel)]
        lines.append("")

    write_atomic(target / "index.theme", "\n".join(lines))

    return bool(directories)

def apply_icon_theme(dominant, sys_mode):
    source = find_icon_theme(ICON_SOURCE_THEME)

    if source is None:
        return False

    if sys_mode == "dark":
        base_name = os.environ.get("DOIZ_ICON_DARK") or "Papirus-Dark"
    else:
        base_name = os.environ.get("DOIZ_ICON_LIGHT") or "Papirus-Light"

    if find_icon_theme(base_name) is None:
        base_name = ICON_SOURCE_THEME

    accent = boost_color(hex_to_rgb(dominant), "dark")
    h, l, s = colorsys.rgb_to_hls(*[x / 255.0 for x in accent])
    l = max(0.54, min(0.66, l))
    s = max(0.42, min(0.62, s))

    slot = ICON_THEME_SLOTS[0]

    if ICON_THEME_PREFIX + ICON_THEME_SLOTS[0] in current_icon_themes():
        slot = ICON_THEME_SLOTS[1]

    name = ICON_THEME_PREFIX + slot

    if not build_folder_icon_theme(source, DATA_HOME / "icons" / name, base_name, name, (h, l, s)):
        return False

    set_ini_keys(GTK3_SETTINGS_FILE, "Settings", {"gtk-icon-theme-name": name})
    set_ini_keys(GTK4_SETTINGS_FILE, "Settings", {"gtk-icon-theme-name": name})
    set_ini_keys(QT6CT_CONFIG_FILE, "Appearance", {"icon_theme": name})
    gsettings_set("icon-theme", name)

    return True

def usage():
    name = Path(sys.argv[0]).name
    print(f"Usage: {name} /path/to/wallpaper")
    print(f"       {name} --mode dark|light      (whole desktop)")
    print(f"       {name} --system dark|light    (GTK/Qt apps only; "
          "waybar, quickshell, btop, cava, kitty untouched)")
    print(f"       {name} --icons                (rebuild the folder icon colors)")
    print(f"       {name} ... --gtk-base THEME   (GTK theme to wrap)")
    sys.exit(1)

def write_parser(parser):
    from io import StringIO

    keep_dynamic_flag(parser)

    output = StringIO()
    parser.write(output)

    write_atomic(THEME_FILE, output.getvalue())

def save_system_mode(parser, sys_mode):
    parser["theme"]["system_mode"] = sys_mode
    write_parser(parser)

def pop_option(args, name):
    if name not in args:
        return None

    index = args.index(name)

    if index + 1 >= len(args):
        usage()

    value = args[index + 1]
    del args[index:index + 2]

    return value

def main():
    args = sys.argv[1:]
    gtk_base = pop_option(args, "--gtk-base")
    parser = load_theme()
    mode = parser["theme"].get("mode", "dark")

    if mode not in PALETTES:
        mode = "dark"

    sys_mode = parser["theme"].get("system_mode", mode)

    if sys_mode not in PALETTES:
        sys_mode = mode

    if args == ["--icons"]:
        dominant = parser["colors"].get("dominant", "#1B1C29")
        sys.exit(0 if apply_icon_theme(dominant, sys_mode) else 1)

    if len(args) == 2 and args[0] == "--system":
        if args[1] not in PALETTES:
            usage()

        dominant = hex_to_rgb(
            parser["colors"].get("dominant", "#1B1C29")
        )

        save_system_mode(parser, args[1])
        render_qt6ct(build_palette(dominant, args[1]), args[1])
        apply_gtk_theme(
            parser,
            build_palette(dominant, mode),
            args[1],
            gtk_base
        )
        apply_icon_theme(rgb_to_hex(dominant), args[1])

        print(f"System mode: {args[1]}")
        return

    if len(args) == 2 and args[0] == "--mode":
        if args[1] not in PALETTES:
            usage()

        mode = args[1]
        sys_mode = mode
        dominant = hex_to_rgb(
            parser["colors"].get("dominant", "#1B1C29")
        )
        colors = build_palette(dominant, mode)
        source = f"mode={mode}"

    elif len(args) == 1:
        if parser["dynamic"].get("enabled", "true").strip().lower() != "true":
            print("Wallpaper colors are turned off, theme left unchanged")
            sys.exit(0)

        wallpaper = Path(
            os.path.expandvars(os.path.expanduser(args[0]))
        ).resolve()

        if not wallpaper.is_file():
            print(f"Wallpaper not found: {wallpaper}")
            sys.exit(1)

        try:
            colors = extract_colors(wallpaper, mode)
        except Exception as error:
            print(f"Color extraction failed: {error}")
            sys.exit(1)

        source = str(wallpaper)

    else:
        usage()

    parser["theme"]["system_mode"] = sys_mode

    save_theme(parser, colors, mode)
    render_waybar(colors)
    render_btop(colors)
    render_cava(colors)
    render_cava_terminal(colors)
    render_kitty(colors, mode)
    render_hypr_border(colors)

    if sys_mode == mode:
        qt_colors = colors
    else:
        qt_colors = build_palette(
            hex_to_rgb(colors["dominant"]),
            sys_mode
        )

    render_qt6ct(qt_colors, sys_mode)
    apply_gtk_theme(parser, colors, sys_mode, gtk_base)
    apply_icon_theme(colors["dominant"], sys_mode)
    ensure_btop_config()

    reload_btop()
    reload_cava_terminal()
    reload_kitty()
    reload_waybar()
    reload_hypr()

    print(f"Source: {source}")
    print(f"Mode: {mode}")
    print(f"System mode: {sys_mode}")
    print(f"Accent: {colors['accent']}")
    print(f"Theme: {THEME_FILE}")

if __name__ == "__main__":
    main()
