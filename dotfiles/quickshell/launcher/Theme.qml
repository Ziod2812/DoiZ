pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string configHome:
        Quickshell.env("XDG_CONFIG_HOME") ||
        (
            Quickshell.env("HOME") +
            "/.config"
        )

    readonly property string themeFile:
        root.configHome +
        "/theme/theme.conf"

    property string backgroundValue: "#1A1D33"
    property string surfaceValue: "#252A42"
    property string accentValue: "#6D72A8"
    property string foregroundValue: "#D6DAED"
    property string subtextValue: "#A5ABCD"
    property string mutedValue: "#6E76A0"
    property string blueValue: "#6A85CC"
    property string cyanValue: "#617BCA"
    property string greenValue: "#81AA99"
    property string redValue: "#B2729E"
    property string yellowValue: "#AA978B"
    property string accentAltValue: "#8589C0"
    property string accentDarkValue: "#414461"

    readonly property color background:
        root.backgroundValue

    readonly property color surface:
        root.surfaceValue

    readonly property color accent:
        root.accentValue

    readonly property color foreground:
        root.foregroundValue

    readonly property color subtext:
        root.subtextValue

    readonly property color muted:
        root.mutedValue

    readonly property color blue:
        root.blueValue

    readonly property color cyan:
        root.cyanValue

    readonly property color green:
        root.greenValue

    readonly property color red:
        root.redValue

    readonly property color yellow:
        root.yellowValue

    readonly property color panel:
        root.backgroundValue

    readonly property color panelAlt:
        root.surfaceValue

    readonly property color selected:
        root.accentValue

    readonly property color border:
        root.accentValue

    readonly property string fontFamily:
        "JetBrainsMono Nerd Font"

    readonly property int fontSize: 10

    function readColor(text, key, fallback) {
        var lines =
            String(text || "").split("\n")

        var prefix =
            key.toLowerCase()

        for (var i = 0; i < lines.length; i++) {
            var line =
                lines[i].trim()

            if (
                line.length === 0 ||
                line.charAt(0) === "#" ||
                line.charAt(0) === ";"
            ) {
                continue
            }

            var separator =
                line.indexOf("=")

            if (separator < 0)
                continue

            var name =
                line
                    .substring(0, separator)
                    .trim()
                    .toLowerCase()

            if (name !== prefix)
                continue

            var value =
                line
                    .substring(separator + 1)
                    .trim()

            if (
                /^#[0-9a-fA-F]{6}$/.test(value) ||
                /^#[0-9a-fA-F]{8}$/.test(value)
            ) {
                return value
            }
        }

        return fallback
    }

    function applyTheme(text) {
        root.backgroundValue =
            root.readColor(
                text,
                "background",
                "#1A1D33"
            )

        root.surfaceValue =
            root.readColor(
                text,
                "surface",
                "#252A42"
            )

        root.accentValue =
            root.readColor(
                text,
                "accent",
                "#6D72A8"
            )

        root.foregroundValue =
            root.readColor(
                text,
                "foreground",
                "#D6DAED"
            )

        root.subtextValue =
            root.readColor(
                text,
                "subtext",
                "#A5ABCD"
            )

        root.mutedValue =
            root.readColor(
                text,
                "muted",
                "#6E76A0"
            )

        root.blueValue =
            root.readColor(
                text,
                "blue",
                "#6A85CC"
            )

        root.cyanValue =
            root.readColor(
                text,
                "cyan",
                "#617BCA"
            )

        root.greenValue =
            root.readColor(
                text,
                "green",
                "#81AA99"
            )

        root.redValue =
            root.readColor(
                text,
                "red",
                "#B2729E"
            )

        root.yellowValue =
            root.readColor(
                text,
                "yellow",
                "#AA978B"
            )

        root.accentAltValue =
            root.readColor(
                text,
                "accent_alt",
                "#8589C0"
            )

        root.accentDarkValue =
            root.readColor(
                text,
                "accent_dark",
                "#414461"
            )
    }

    FileView {
        id: themeFile

        path:
            root.themeFile

        watchChanges:
            true

        onFileChanged: {
            themeFile.reload()
        }

        onLoaded: {
            root.applyTheme(
                themeFile.text()
            )
        }
    }

    Component.onCompleted: {
        themeFile.reload()
    }
}