pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string home: Quickshell.env("HOME")

    readonly property string configHome:
        Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")

    readonly property string themeFile: root.configHome + "/theme/theme.conf"
    readonly property string dir: Quickshell.shellDir !== "" ? Quickshell.shellDir : root.configHome + "/quickshell/settings"
    readonly property string netScript: root.dir + "/../network/iwd.py"
    readonly property string setScript: root.configHome + "/hypr/scripts/doiz-set"
    readonly property string fontName: "JetBrainsMono Nerd Font"

    readonly property var pages: [
        { key: "system", title: "System", icon: "\uDB81\uDC93", file: "PageSystem.qml" },
        { key: "audio", title: "Audio", icon: "\uDB81\uDD7E", file: "PageAudio.qml" },
        { key: "display", title: "Display", icon: "\uDB80\uDF79", file: "PageDisplay.qml" },
        { key: "battery", title: "Battery", icon: "\uDB80\uDC79", file: "PagePower.qml" },
        { key: "network", title: "Network", icon: "\uDB81\uDDA9", file: "PageNetwork.qml" },
        { key: "bluetooth", title: "Bluetooth", icon: "\uDB80\uDCAF", file: "PageBluetooth.qml" },
        { key: "storage", title: "Storage", icon: "\uDB80\uDECA", file: "PageStorage.qml" },
        { key: "appearance", title: "Appearance", icon: "\uDB80\uDFD8", file: "PageAppearance.qml" },
        { key: "notifications", title: "Notifications", icon: "\uDB80\uDC9A", file: "PageNotifications.qml" },
        { key: "input", title: "Input", icon: "\uDB80\uDF0C", file: "PageInput.qml" },
        { key: "hyprland", title: "Apps & Hyprland", icon: "\uDB80\uDC3B", file: "PageHyprland.qml" },
        { key: "packages", title: "Packages", icon: "\uDB80\uDCD6", file: "PagePackages.qml" },
        { key: "configs", title: "Configs", icon: "\uDB80\uDE14", file: "PageConfigs.qml" }
    ]

    property color panelColor: "#f51a1d33"
    property color cardColor: "#942b2f52"
    property color hoverColor: "#b8383d6a"
    property color lineColor: "#4d6e76a0"
    property color titleColor: "#d6daed"
    property color textColor: "#a5abcd"
    property color mutedColor: "#6e76a0"
    property color accentColor: "#6d72a8"
    property color goodColor: "#81aa99"
    property color warnColor: "#aa978b"
    property color badColor: "#b2729e"
    property color infoColor: "#6a85cc"
    property color inkColor: "#1a1d33"
    property color trackColor: "#cc383d6a"
    property color orangeColor: "#c08a6a"
    property color stateColor: root.accentColor
    property bool typing: false
    property bool picking: false

    function run(args) {
        Quickshell.execDetached(["python3", root.setScript].concat(args))
    }

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function apply(data) {
        var lines = data.split("\n")
        var c = {}
        var inColors = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line === "[colors]") {
                inColors = true
                continue
            }

            if (line.indexOf("[") === 0) {
                inColors = false
                continue
            }

            if (!inColors)
                continue

            var sep = line.indexOf("=")

            if (sep < 0)
                continue

            c[line.substring(0, sep).trim()] = line.substring(sep + 1).trim()
        }

        function pick(key, fallback) {
            var t = c[key] || ""

            if (/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(t))
                return t

            return fallback
        }

        var bg = Qt.color(pick("background", "#1A1D33"))
        var sf = Qt.color(pick("surface", "#2B2F52"))
        var sa = Qt.color(pick("surface_alt", "#383D6A"))
        var mu = Qt.color(pick("muted", "#6E76A0"))

        root.panelColor = Qt.rgba(bg.r, bg.g, bg.b, 0.96)
        root.cardColor = Qt.rgba(sf.r, sf.g, sf.b, 0.92)
        root.hoverColor = Qt.rgba(sa.r, sa.g, sa.b, 0.72)
        root.lineColor = Qt.rgba(mu.r, mu.g, mu.b, 0.3)
        root.inkColor = bg
        root.trackColor = Qt.rgba(sa.r, sa.g, sa.b, 0.8)

        root.titleColor = pick("foreground", "#D6DAED")
        root.textColor = pick("subtext", "#A5ABCD")
        root.mutedColor = pick("muted", "#6E76A0")
        root.accentColor = pick("accent_alt", "#6D72A8")
        root.goodColor = pick("green", "#81AA99")
        root.warnColor = pick("yellow", "#AA978B")
        root.badColor = pick("red", "#B2729E")
        root.infoColor = pick("blue", "#6A85CC")
        root.orangeColor = pick("orange", root.warnColor)
    }

    Process {
        id: themeProcess

        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "doiz", root.themeFile]

        stdout: StdioCollector {
            onStreamFinished: root.apply(this.text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!themeProcess.running)
                themeProcess.running = true
        }
    }
}
