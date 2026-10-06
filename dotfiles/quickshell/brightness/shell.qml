import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property bool shown: true

    IpcHandler {
        target: "brightness"

        function toggle(): void {
            if (root.shown) {
                root.closePopup()
                return
            }

            root.shown = true
            root.refreshPopup()
        }

        function show(): void {
            root.shown = true
            root.refreshPopup()
        }

        function hide(): void {
            root.closePopup()
        }
    }

    property int levelValue: -1
    property bool dragging: false
    property int pendingLevel: -1

    property string deviceText: "--"
    property string classText: "--"
    property string currentText: "--"
    property string maxText: "--"

    property string themeFile:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/theme/theme.conf"

    property bool themeReady: false
    property bool brightnessChecked: false

    property bool ready:
        root.themeReady &&
        root.brightnessChecked

    property color panelColor
    property color cardColor
    property color trackColor
    property color lineColor
    property color titleColor
    property color textColor
    property color mutedColor
    property color accentColor
    property color accentAltColor
    property string fontName: "JetBrainsMono Nerd Font"

    Behavior on panelColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on cardColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on trackColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on lineColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on titleColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on textColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on mutedColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on accentColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on accentAltColor { enabled: root.ready; ColorAnimation { duration: 400 } }

    property bool available:
        root.levelValue >= 0

    property color iconColor:
        root.available
        ? root.accentAltColor
        : root.mutedColor

    property color stateColor:
        root.available
        ? root.accentColor
        : root.mutedColor

    property string statusText:
        !root.available
        ? "No backlight"
        : root.levelValue >= 100
          ? "Max"
          : root.levelValue >= 60
            ? "Bright"
            : root.levelValue >= 25
              ? "Medium"
              : "Dim"

    function loadBrightness() {
        if (!brightnessProcess.running)
            brightnessProcess.running = true
    }

    function loadTheme() {
        themeProcess.running = false
        themeProcess.running = true
    }

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function hexColor(hex, alpha) {
        return Qt.rgba(
            parseInt(hex.substring(1, 3), 16) / 255,
            parseInt(hex.substring(3, 5), 16) / 255,
            parseInt(hex.substring(5, 7), 16) / 255,
            alpha
        )
    }

    function brightnessIcon() {
        if (root.levelValue < 25)
            return "\uDB80\uDCDD"

        if (root.levelValue < 50)
            return "\uDB80\uDCDE"

        if (root.levelValue < 75)
            return "\uDB80\uDCDF"

        return "\uDB80\uDCE0"
    }

    function setLevel(value) {
        var v = Math.round(Number(value))

        if (!isFinite(v))
            return

        v = Math.max(1, Math.min(100, v))

        root.levelValue = v
        root.pendingLevel = v

        applyTimer.restart()
        closeTimer.restart()
    }

    function parseTheme(data) {
        var lines = data.split("\n")
        var section = ""
        var colors = {}

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line)
                continue

            if (line.charAt(0) === "[") {
                section = line.substring(1, line.length - 1)
                continue
            }

            if (section !== "colors")
                continue

            var separator = line.indexOf("=")

            if (separator < 0)
                continue

            colors[line.substring(0, separator).trim()] =
                line.substring(separator + 1).trim()
        }

        if (colors["background"])
            root.panelColor = root.hexColor(colors["background"], 0.95)

        if (colors["surface"])
            root.cardColor = root.hexColor(colors["surface"], 0.62)

        if (colors["surface_alt"])
            root.trackColor = root.hexColor(colors["surface_alt"], 0.35)

        if (colors["foreground"])
            root.titleColor = colors["foreground"]

        if (colors["subtext"])
            root.textColor = colors["subtext"]

        if (colors["muted"])
            root.mutedColor = colors["muted"]

        if (colors["accent"]) {
            root.accentColor = colors["accent"]
            root.lineColor = root.hexColor(colors["accent"], 0.25)
        }

        if (colors["accent_alt"])
            root.accentAltColor = colors["accent_alt"]

        root.themeReady = true
    }

    function parseBrightness(data) {
        var parts = data.trim().split(",")

        if (parts.length < 5) {
            root.levelValue = -1
            root.deviceText = "--"
            root.classText = "--"
            root.currentText = "--"
            root.maxText = "--"
            root.brightnessChecked = true
            return
        }

        var percent = parseInt(parts[3])

        if (
            !root.dragging &&
            !applyTimer.running &&
            !isNaN(percent)
        ) {
            root.levelValue = percent
        }

        root.deviceText = parts[0] || "--"
        root.classText = parts[1] || "--"
        root.currentText = parts[2] || "--"
        root.maxText = parts[4] || "--"
        root.brightnessChecked = true
    }

    function refreshPopup() {
        root.loadTheme()
        root.loadBrightness()
        closeTimer.restart()
    }

    function closePopup() {
        root.shown = false

        if (applyTimer.running) {
            applyTimer.stop()
            applyTimer.triggered()
        }

        Qt.quit()
    }

    PanelWindow {
        id: clickLayer

        visible: root.shown

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.namespace:
            "doiz-brightness-click-layer"

        WlrLayershell.layer:
            WlrLayer.Top

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closePopup()
            }
        }
    }

    PanelWindow {
        id: brightnessPanel

        visible: root.shown

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 8
        }

        implicitWidth: 320
        implicitHeight:
            contentColumn.implicitHeight + 24

        color: "transparent"

        WlrLayershell.namespace:
            "doiz-brightness"

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent

            color: root.panelColor
            radius: 8

            border.width: 1
            border.color:
                root.tint(
                    root.stateColor,
                    0.35
                )

            Behavior on border.color {
                enabled: root.ready

                ColorAnimation {
                    duration: 250
                }
            }

            opacity:
                root.ready
                ? 1
                : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type:
                        Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent

                onWheel: (wheel) => {
                    root.setLevel(
                        root.levelValue +
                        (wheel.angleDelta.y > 0 ? 5 : -5)
                    )
                }
            }

            Column {
                id: contentColumn

                x: 12
                y: 12

                width:
                    parent.width - 24

                spacing: 8

                Item {
                    width: parent.width
                    height: 40

                    Rectangle {
                        id: iconTile

                        anchors.left:
                            parent.left

                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 40
                        height: 40
                        radius: 6

                        color:
                            root.tint(
                                root.stateColor,
                                0.16
                            )

                        Text {
                            anchors.centerIn:
                                parent

                            text:
                                root.brightnessIcon()

                            color:
                                root.iconColor

                            font.family:
                                root.fontName

                            font.pixelSize: 21
                        }
                    }

                    Column {
                        anchors.left:
                            iconTile.right

                        anchors.leftMargin: 10

                        anchors.verticalCenter:
                            parent.verticalCenter

                        spacing: 2

                        Text {
                            text: "BRIGHTNESS"

                            color:
                                root.titleColor

                            font.family:
                                root.fontName

                            font.pixelSize: 13

                            font.weight:
                                Font.Bold
                        }

                        Text {
                            text:
                                root.statusText

                            color:
                                root.stateColor

                            font.family:
                                root.fontName

                            font.pixelSize: 10

                            font.weight:
                                Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors.right:
                            parent.right

                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 54
                        height: 40
                        radius: 6

                        color:
                            root.cardColor

                        Text {
                            anchors.centerIn:
                                parent

                            text:
                                root.levelValue >= 0
                                ? root.levelValue + "%"
                                : "--"

                            color:
                                root.stateColor

                            font.family:
                                root.fontName

                            font.pixelSize: 12

                            font.weight:
                                Font.Bold
                        }
                    }
                }

                Item {
                    id: sliderArea

                    width: parent.width
                    height: 20

                    Rectangle {
                        id: track

                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: parent.width
                        height: 6
                        radius: 3

                        color:
                            root.trackColor

                        Rectangle {
                            id: fill

                            width:
                                track.width *
                                Math.max(
                                    0,
                                    Math.min(
                                        1,
                                        root.levelValue / 100
                                    )
                                )

                            height: parent.height
                            radius: 3

                            color:
                                root.stateColor

                            Behavior on width {
                                enabled: !root.dragging

                                NumberAnimation {
                                    duration: 250
                                    easing.type:
                                        Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                enabled: root.ready

                                ColorAnimation {
                                    duration: 250
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 14
                        height: 14
                        radius: 7

                        x:
                            Math.max(
                                0,
                                Math.min(
                                    track.width - width,
                                    fill.width - width / 2
                                )
                            )

                        visible:
                            root.available

                        color:
                            root.stateColor

                        border.width: 2
                        border.color:
                            root.panelColor
                    }

                    MouseArea {
                        anchors.fill: parent

                        enabled:
                            root.available

                        function setFromX(x) {
                            root.setLevel(
                                x / track.width * 100
                            )
                        }

                        onPressed: (mouse) => {
                            root.dragging = true
                            setFromX(mouse.x)
                        }

                        onPositionChanged: (mouse) => {
                            if (pressed)
                                setFromX(mouse.x)
                        }

                        onReleased: {
                            root.dragging = false
                        }

                        onCanceled: {
                            root.dragging = false
                        }
                    }
                }

                Row {
                    id: statRow

                    width: parent.width
                    height: 44

                    spacing: 6

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            width:
                                (
                                    statRow.width - 12
                                ) / 3

                            height: 44

                            radius: 6

                            color:
                                root.cardColor

                            Column {
                                anchors.left:
                                    parent.left

                                anchors.right:
                                    parent.right

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing: 4

                                Text {
                                    width:
                                        parent.width

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text: [
                                        "LEVEL",
                                        "CURRENT",
                                        "MAX"
                                    ][index]

                                    color:
                                        root.mutedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 8

                                    font.weight:
                                        Font.DemiBold
                                }

                                Text {
                                    width:
                                        parent.width

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text: [
                                        root.levelValue >= 0
                                            ? root.levelValue + "%"
                                            : "--",
                                        root.currentText,
                                        root.maxText
                                    ][index]

                                    color: [
                                        root.stateColor,
                                        root.accentAltColor,
                                        root.accentAltColor
                                    ][index]

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 11

                                    font.weight:
                                        Font.Bold

                                    elide:
                                        Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Row {
                    id: presetRow

                    width: parent.width
                    height: 32

                    spacing: 6

                    Repeater {
                        model: [25, 50, 75, 100]

                        delegate: Rectangle {
                            width:
                                (
                                    presetRow.width - 18
                                ) / 4

                            height: 32

                            radius: 6

                            color:
                                Math.abs(
                                    root.levelValue - modelData
                                ) < 3
                                ? root.tint(
                                    root.stateColor,
                                    0.16
                                )
                                : root.cardColor

                            Behavior on color {
                                enabled: root.ready

                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    modelData + "%"

                                color:
                                    Math.abs(
                                        root.levelValue - modelData
                                    ) < 3
                                    ? root.stateColor
                                    : root.textColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent

                                enabled:
                                    root.available

                                onClicked: {
                                    root.setLevel(modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1

                    color:
                        root.lineColor
                }

                Column {
                    width: parent.width

                    spacing: 5

                    Row {
                        width: parent.width
                        height: 18

                        spacing: 8

                        Text {
                            width: 100

                            text: "DEVICE"

                            color:
                                root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 8

                            font.weight:
                                Font.DemiBold
                        }

                        Text {
                            width:
                                parent.width - 108

                            text:
                                root.deviceText

                            color:
                                root.textColor

                            font.family:
                                root.fontName

                            font.pixelSize: 10

                            font.weight:
                                Font.DemiBold

                            elide:
                                Text.ElideRight
                        }
                    }

                    Row {
                        width: parent.width
                        height: 18

                        spacing: 8

                        Text {
                            width: 100

                            text: "CLASS"

                            color:
                                root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 8

                            font.weight:
                                Font.DemiBold
                        }

                        Text {
                            width:
                                parent.width - 108

                            text:
                                root.classText

                            color:
                                root.textColor

                            font.family:
                                root.fontName

                            font.pixelSize: 10

                            font.weight:
                                Font.DemiBold

                            elide:
                                Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: refreshTimer

        interval: 1500
        repeat: true
        running: true

        onTriggered: {
            root.loadBrightness()
        }
    }

    Timer {
        id: applyTimer

        interval: 40
        repeat: false

        onTriggered: {
            if (root.pendingLevel > 0) {
                Quickshell.execDetached([
                    "brightnessctl",
                    "-c",
                    "backlight",
                    "set",
                    root.pendingLevel + "%"
                ])
            }
        }
    }

    Timer {
        id: closeTimer

        interval: 5000
        repeat: false
        running: true

        onTriggered: {
            if (!root.dragging)
                root.closePopup()
            else
                closeTimer.restart()
        }
    }

    Timer {
        id: themeRefreshTimer

        interval: 2000
        repeat: true
        running: true

        onTriggered: {
            root.loadTheme()
        }
    }

    Process {
        id: themeProcess

        command: [
            "sh",
            "-c",
            "if [ -f \"$1\" ]; then cat \"$1\"; fi",
            "doiz",
            root.themeFile
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseTheme(this.text)
            }
        }
    }

    Process {
        id: brightnessProcess

        command: [
            "sh",
            "-c",
            "brightnessctl -m -c backlight 2>/dev/null | head -n1"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBrightness(this.text)
            }
        }
    }

    Component.onCompleted: {
        root.loadTheme()
        root.loadBrightness()
    }
}