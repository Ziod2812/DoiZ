#!/usr/bin/env python3

import re
import subprocess
import sys
import time

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
MAC = re.compile(r"(?:[0-9a-f]{2}:){5}[0-9a-f]{2}", re.I)
NETWORK = re.compile(
    r"^\s*(>)?\s*(.+?)\s{2,}(open|psk|8021x|wep)\s+(\S+)\s*$", re.I
)
SECURITY_LABEL = {"open": "", "psk": "WPA2", "8021x": "802.1X", "wep": "WEP"}


def run(args, timeout=15):
    try:
        r = subprocess.run(
            ["iwctl"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "", 1
    return ANSI.sub("", r.stdout + r.stderr), r.returncode


def find_device():
    out, _ = run(["device", "list"])
    fallback = None
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 2 or not MAC.fullmatch(parts[1]):
            continue
        if "station" in parts:
            return parts[0]
        if fallback is None:
            fallback = parts[0]
    return fallback


def signal_percent(token):
    if set(token) == {"*"}:
        return min(100, len(token) * 25)
    try:
        value = float(token)
    except ValueError:
        return 0
    if abs(value) > 200:
        value /= 100.0
    return max(0, min(100, int(2 * (value + 100))))


def escape_ssid(ssid):
    return ssid.replace("\\", "\\\\").replace(":", "\\:")


def station_info(device):
    out, _ = run(["station", device, "show"])
    state = re.search(r"^\s*State\s+(\S+)", out, re.M)
    network = re.search(r"^\s*Connected network\s+(.+?)\s*$", out, re.M)
    return (
        state.group(1) if state else "",
        network.group(1) if network else "",
    )


def cmd_list(rescan):
    device = find_device()
    if not device:
        return 0
    if rescan:
        run(["station", device, "scan"])
        time.sleep(1.5)
    out, _ = run(["station", device, "get-networks", "rssi-dbms"])
    if not any(NETWORK.match(line) for line in out.splitlines()):
        out, _ = run(["station", device, "get-networks"])
    for line in out.splitlines():
        m = NETWORK.match(line)
        if not m:
            continue
        marker, ssid, security, signal = m.groups()
        label = SECURITY_LABEL.get(security.lower(), "")
        print(
            "%s:%d:%s:%s"
            % (
                "yes" if marker else "no",
                signal_percent(signal),
                label,
                escape_ssid(ssid.strip()),
            )
        )
    return 0


def cmd_connect(ssid, passphrase=None):
    device = find_device()
    if not device or not ssid:
        return 1
    args = []
    if passphrase:
        args += ["--passphrase", passphrase]
    args += ["station", device, "connect", ssid]
    run(args, timeout=40)
    for _ in range(10):
        state, network = station_info(device)
        if state == "connected" and network == ssid:
            return 0
        time.sleep(0.5)
    return 1


def powered(device):
    out, _ = run(["device", device, "show"])
    m = re.search(r"Powered\s+(on|off)\b", out)
    return bool(m) and m.group(1) == "on"


def cmd_state():
    device = find_device()
    print("enabled" if device and powered(device) else "disabled")
    return 0


def cmd_toggle():
    device = find_device()
    if not device:
        return 1
    target = "off" if powered(device) else "on"
    _, rc = run(["device", device, "set-property", "Powered", target])
    return rc


def main(argv):
    if len(argv) < 2:
        return 2
    action = argv[1]
    if action == "list":
        return cmd_list(len(argv) > 2 and argv[2] == "rescan")
    if action == "connect":
        return cmd_connect(argv[2] if len(argv) > 2 else "")
    if action == "connect-pw":
        passphrase = sys.stdin.readline().rstrip("\n")
        return cmd_connect(argv[2] if len(argv) > 2 else "", passphrase)
    if action == "state":
        return cmd_state()
    if action == "toggle":
        return cmd_toggle()
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
