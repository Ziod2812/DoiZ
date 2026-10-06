import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    readonly property var scr: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    property real centerX: -1
    property real triggerW: 360
    property real barBottom: 44
    property bool lyricsOn: true
    property bool popupEnabled: true
    property real baseW: 440
    readonly property real popupW: root.lyricsOn ? root.baseW + 250 : root.baseW
    property real popupH: 190

    property real curX: -1
    property real curY: -1
    property bool shown: false
    property bool forced: false

    property color panelColor: "#f51a1d33"
    property color cardColor: "#942b2f52"
    property color lineColor: "#4d6e76a0"
    property color titleColor: "#d6daed"
    property color textColor: "#a5abcd"
    property color mutedColor: "#6e76a0"
    property color accentColor: "#6d72a8"
    property color inkColor: "#1a1d33"

    readonly property var player: pickPlayer(Mpris.players.values)

    function pickPlayer(list) {
        var first = null

        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]

            if (first === null)
                first = list[i]
        }

        return first
    }

    readonly property real screenW: root.scr ? root.scr.width : 1920
    readonly property real screenX: root.scr ? root.scr.x : 0
    readonly property real screenY: root.scr ? root.scr.y : 0
    readonly property real trigCenter: root.centerX >= 0 ? root.centerX : root.screenW / 2 + 100
    readonly property real trigLeft: root.trigCenter - root.triggerW / 2
    readonly property real popLeft: Math.max(8, Math.min(root.screenW - root.popupW - 8, root.trigCenter - root.popupW / 2))

    ListModel {
        id: lyricModel
    }

    property bool lyricSynced: false
    property string lyricKey: ""
    property string lyricState: "idle"
    readonly property string trackKey: root.player ? (root.player.trackArtist + "|" + root.player.trackTitle) : ""

    readonly property int lyricIndex: {
        if (!root.lyricSynced || root.player === null)
            return -1

        var pos = root.player.position
        var idx = -1

        for (var i = 0; i < lyricModel.count; i++) {
            if (lyricModel.get(i).t <= pos + 0.25)
                idx = i
            else
                break
        }

        return idx
    }

    function loadLyrics() {
        if (!root.player || root.trackKey === root.lyricKey || lyricProc.running)
            return

        root.lyricKey = root.trackKey
        root.lyricState = "loading"
        lyricModel.clear()
        lyricProc.command = [
            "python3",
            root.cfgHome + "/hypr/scripts/doiz-lyrics",
            root.player.trackArtist || "",
            root.player.trackTitle || "",
            root.player.trackAlbum || "",
            String(root.player.length || 0)
        ]
        lyricProc.running = true
    }

    onTrackKeyChanged: {
        root.lyricKey = ""

        if (root.shown && root.lyricsOn)
            lyricTimer.restart()
    }

    onShownChanged: {
        if (root.shown && root.lyricsOn)
            lyricTimer.restart()
    }

    onLyricsOnChanged: {
        if (root.lyricsOn && root.shown)
            lyricTimer.restart()
    }

    Timer {
        id: lyricTimer

        interval: 400

        onTriggered: root.loadLyrics()
    }

    Process {
        id: lyricProc

        stdout: StdioCollector {
            onStreamFinished: {
                lyricModel.clear()
                root.lyricSynced = false

                try {
                    var o = JSON.parse(this.text)

                    if (o.synced && o.synced.length > 0) {
                        for (var i = 0; i < o.synced.length; i++)
                            lyricModel.append({ t: o.synced[i][0], line: o.synced[i][1] })

                        root.lyricSynced = true
                        root.lyricState = "ok"
                    } else if (o.plain && o.plain.length > 0) {
                        var rows = o.plain.split("\n")

                        for (var j = 0; j < rows.length; j++)
                            lyricModel.append({ t: -1, line: rows[j] })

                        root.lyricState = "ok"
                    } else {
                        root.lyricState = "none"
                    }
                } catch (e) {
                    root.lyricState = "none"
                }

                if (root.trackKey !== root.lyricKey)
                    lyricTimer.restart()
            }
        }
    }

    function fmt(sec) {
        var t = Math.max(0, Math.floor(sec || 0))
        var m = Math.floor(t / 60)
        var s = t % 60

        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function parseConf(text) {
        var lines = text.split("\n")

        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split("=")

            if (p.length !== 2)
                continue

            var v = parseFloat(p[1])

            if (isNaN(v))
                continue

            if (p[0].trim() === "center")
                root.centerX = v
            else if (p[0].trim() === "width")
                root.triggerW = v
        }
    }

    function parseTheme(text) {
        var c = {}
        var inColors = false
        var lines = text.split("\n")

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

            var sep = line.indexOf("=")

            if (inColors && sep > 0)
                c[line.substring(0, sep).trim()] = line.substring(sep + 1).trim()
        }

        function pick(key, fb) {
            return /^#[0-9a-fA-F]{6}$/.test(c[key] || "") ? c[key] : fb
        }

        var bg = Qt.color(pick("background", "#1A1D33"))
        var sf = Qt.color(pick("surface", "#2B2F52"))
        var mu = Qt.color(pick("muted", "#6E76A0"))

        root.panelColor = Qt.rgba(bg.r, bg.g, bg.b, 0.96)
        root.cardColor = Qt.rgba(sf.r, sf.g, sf.b, 0.92)
        root.lineColor = Qt.rgba(mu.r, mu.g, mu.b, 0.3)
        root.inkColor = bg
        root.titleColor = pick("foreground", "#D6DAED")
        root.textColor = pick("subtext", "#A5ABCD")
        root.mutedColor = pick("muted", "#6E76A0")
        root.accentColor = pick("accent_alt", "#6D72A8")
    }

    readonly property bool inTrigger:
        root.curY >= 0 && root.curY <= root.barBottom
        && root.curX >= root.trigLeft && root.curX <= root.trigLeft + root.triggerW

    readonly property bool inPopup:
        root.curY >= root.barBottom - 4 && root.curY <= root.barBottom + root.popupH + 6
        && root.curX >= root.popLeft - 4 && root.curX <= root.popLeft + root.popupW + 4

    readonly property bool hot: root.popupEnabled && root.player !== null && (root.inTrigger || (root.shown && root.inPopup) || root.forced)

    onHotChanged: {
        if (root.hot) {
            closeTimer.stop()

            if (!root.shown)
                openTimer.restart()
        } else {
            openTimer.stop()

            if (root.shown)
                closeTimer.restart()
        }
    }

    Timer {
        id: openTimer

        interval: 120

        onTriggered: root.shown = true
    }

    Timer {
        id: closeTimer

        interval: 350

        onTriggered: root.shown = false
    }

    IpcHandler {
        target: "mediapopup"

        function toggle(): void {
            root.forced = !root.forced
        }

        function here(): void {
            root.centerX = root.curX - root.screenX
            Quickshell.execDetached([
                "sh",
                "-c",
                "mkdir -p \"$1/mycfg\"; printf 'center=%s\\nwidth=%s\\n' \"$2\" \"$3\" > \"$1/mycfg/mediapopup.conf\"",
                "doiz",
                root.cfgHome,
                String(Math.round(root.centerX)),
                String(Math.round(root.triggerW))
            ])
        }

        function width(w: int): void {
            root.triggerW = w
        }
    }

    Process {
        id: confProc

        command: ["sh", "-c", "cat \"$1/mycfg/mediapopup.conf\" 2>/dev/null", "doiz", root.cfgHome]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseConf(this.text)
        }
    }

    Process {
        id: envProc

        command: ["sh", "-c", "cat \"$1/mycfg/doiz-settings.env\" 2>/dev/null", "doiz", root.cfgHome]

        stdout: StdioCollector {
            onStreamFinished: {
                var on = true
                var lines = this.text.split("\n")

                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "media_popup=0")
                        on = false
                }

                root.popupEnabled = on

                if (!on)
                    root.forced = false
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!envProc.running)
                envProc.running = true
        }
    }

    Process {
        id: themeProc

        command: ["sh", "-c", "cat \"$1/theme/theme.conf\" 2>/dev/null", "doiz", root.cfgHome]

        stdout: StdioCollector {
            onStreamFinished: root.parseTheme(this.text)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!themeProc.running)
                themeProc.running = true
        }
    }

    Process {
        id: cursorProc

        command: ["hyprctl", "-j", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text)

                    root.curX = o.x - root.screenX
                    root.curY = o.y - root.screenY
                } catch (e) {
                    root.curY = -1
                }
            }
        }
    }

    Timer {
        interval: root.shown ? 80 : 110
        repeat: true
        running: root.player !== null
        triggeredOnStart: true

        onTriggered: {
            if (!cursorProc.running)
                cursorProc.running = true
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.shown && root.player !== null && root.player.isPlaying

        onTriggered: root.player.positionChanged()
    }

    PanelWindow {
        id: win

        screen: root.scr
        visible: root.shown || fade.running || card.opacity > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
        }

        margins {
            top: root.barBottom - 2
            left: root.popLeft
        }

        implicitWidth: root.popupW
        implicitHeight: root.popupH + 12

        WlrLayershell.namespace: "doiz-media-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card

            width: root.popupW
            height: root.popupH
            y: root.shown ? 2 : -8
            radius: 10
            color: root.panelColor
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
            opacity: root.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    id: fade

                    duration: 140
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: art

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 150
                radius: 10
                clip: true
                color: root.cardColor

                Image {
                    id: cover

                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 400
                    sourceSize.height: 400
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "󰀥"
                    color: root.accentColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 44
                }
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 16
                anchors.right: lyricsPanel.visible ? lyricsPanel.left : parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 18
                spacing: 4

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackTitle : ""
                    color: root.titleColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackArtist : ""
                    color: root.accentColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackAlbum : ""
                    color: root.mutedColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: lyricsPanel

                visible: root.lyricsOn
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                width: 220
                radius: 8
                color: root.cardColor
                clip: true

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: root.lyricState !== "ok"
                    text: root.lyricState === "loading" ? "Loading lyrics..." : "No lyrics found"
                    color: root.mutedColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

                ListView {
                    id: lyricList

                    anchors.fill: parent
                    anchors.margins: 10
                    visible: root.lyricState === "ok"
                    model: lyricModel
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    highlightRangeMode: root.lyricSynced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                    preferredHighlightBegin: height / 2 - 18
                    preferredHighlightEnd: height / 2 + 18
                    highlightMoveDuration: 250
                    currentIndex: Math.max(0, root.lyricIndex)

                    delegate: Text {
                        required property string line
                        required property int index

                        width: ListView.view.width
                        wrapMode: Text.WordWrap
                        text: line === "" ? "\u266a" : line
                        color: root.lyricSynced && index === root.lyricIndex ? root.titleColor : root.mutedColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: root.lyricSynced && index === root.lyricIndex ? 13 : 11
                        font.weight: root.lyricSynced && index === root.lyricIndex ? Font.Bold : Font.Normal
                    }
                }
            }

            Item {
                id: seek

                anchors.left: art.right
                anchors.leftMargin: 16
                anchors.right: root.lyricsOn ? lyricsPanel.left : parent.right
                anchors.rightMargin: 16
                anchors.bottom: controls.top
                anchors.bottomMargin: 10
                height: 26

                readonly property real len: root.player ? root.player.length : 0
                readonly property real pos: root.player ? root.player.position : 0
                readonly property real ratio: len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0

                Rectangle {
                    id: seekBar

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    height: 6
                    radius: 3
                    color: root.cardColor

                    Rectangle {
                        width: parent.width * seek.ratio
                        height: parent.height
                        radius: 3
                        color: root.accentColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -6
                        anchors.bottomMargin: -6
                        enabled: root.player !== null && root.player.canSeek && seek.len > 0
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * seek.len
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: root.fmt(seek.pos)
                    color: root.mutedColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: root.fmt(seek.len)
                    color: root.mutedColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                }
            }

            Row {
                id: controls

                anchors.left: art.right
                anchors.leftMargin: 16
                anchors.right: root.lyricsOn ? lyricsPanel.left : parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                spacing: 8

                Repeater {
                    model: [
                        { glyph: "󰒝", act: "shuffle" },
                        { glyph: "󰒮", act: "prev" },
                        { glyph: "", act: "play" },
                        { glyph: "󰒭", act: "next" },
                        { glyph: "󰑖", act: "loop" }
                    ]

                    delegate: Rectangle {
                        id: btn

                        required property var modelData

                        readonly property bool main: btn.modelData.act === "play"
                        readonly property bool on:
                            root.player !== null
                            && ((btn.modelData.act === "shuffle" && root.player.shuffle)
                                || (btn.modelData.act === "loop" && root.player.loopState !== MprisLoopState.None))
                            || (btn.modelData.act === "lyrics" && root.lyricsOn)

                        width: btn.main ? 54 : 32
                        height: 36
                        radius: 8
                        color: btn.main
                               ? root.accentColor
                               : btn.on
                                 ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                                 : area.containsMouse ? root.lineColor : root.cardColor

                        Text {
                            anchors.centerIn: parent
                            text: btn.main
                                  ? (root.player && root.player.isPlaying ? "󰏤" : "󰐊")
                                  : btn.modelData.act === "loop" && root.player
                                    ? (root.player.loopState === MprisLoopState.Track ? "󰑘"
                                       : root.player.loopState === MprisLoopState.None ? "󰑗" : "󰑖")
                                  : btn.modelData.glyph
                            color: btn.main ? root.inkColor : root.titleColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: btn.main ? 20 : 15
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                var p = root.player
                                var a = btn.modelData.act

                                if (a === "lyrics") {
                                    root.lyricsOn = !root.lyricsOn
                                    return
                                }

                                if (!p)
                                    return

                                if (a === "play")
                                    p.togglePlaying()
                                else if (a === "prev")
                                    p.previous()
                                else if (a === "next")
                                    p.next()
                                else if (a === "shuffle" && p.shuffleSupported)
                                    p.shuffle = !p.shuffle
                                else if (a === "loop" && p.loopSupported)
                                    p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                    : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                                    : MprisLoopState.None
                            }
                        }
                    }
                }
            }
        }
    }
}
