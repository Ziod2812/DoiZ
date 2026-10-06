import QtQuick
import QtQuick.Controls
import ".."

Rectangle {
    id: root

    property string path: ""
    property string thumbnail: ""
    property bool selected: false
    property bool hovered: false

    readonly property real previewRatio: 0.58

    signal triggered()

    width: 170
    height: 124

    radius: 10
    clip: true

    color:
        root.selected
        ? Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.18
        )
        : root.hovered
            ? Qt.rgba(
                Theme.accent.r,
                Theme.accent.g,
                Theme.accent.b,
                0.08
            )
            : "transparent"

    border.width:
        root.selected
        ? 1
        : 0

    border.color:
        Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.40
        )

    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    function isVideo() {
        var value =
            String(root.path || "").toLowerCase()

        var dot =
            value.lastIndexOf(".")

        if (dot < 0)
            return false

        var ext =
            value.substring(dot + 1)

        return [
            "mp4",
            "webm",
            "mkv",
            "mov",
            "avi"
        ].indexOf(ext) >= 0
    }

    function fileName() {
        if (
            !root.path ||
            root.path.length === 0
        ) {
            return "Wallpaper"
        }

        var parts =
            root.path.split("/")

        return parts.length > 0
            ? parts[parts.length - 1]
            : "Wallpaper"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6

        spacing: 5

        Item {
            id: previewFrame

            width: parent.width

            height:
                Math.round(
                    width * root.previewRatio
                )

            clip: true

            Rectangle {
                anchors.fill: parent

                radius: 7

                color:
                    Qt.rgba(
                        Theme.background.r,
                        Theme.background.g,
                        Theme.background.b,
                        0.70
                    )
            }

            Image {
                id: wallpaperImage

                x: 1
                y: 1

                width:
                    parent.width - 2

                height:
                    parent.height - 2

                source:
                    root.path.length === 0
                    ? ""
                    : root.isVideo()
                        ? (
                            root.thumbnail.length > 0
                            ? "file://" + root.thumbnail
                            : ""
                        )
                        : "file://" + root.path

                fillMode:
                    Image.PreserveAspectCrop

                asynchronous: true

                smooth: true

                cache: true

                sourceSize.width: 360
                sourceSize.height: 240
            }

            Rectangle {
                anchors.fill:
                    wallpaperImage

                radius: 6

                color:
                    Qt.rgba(
                        Theme.background.r,
                        Theme.background.g,
                        Theme.background.b,
                        root.selected
                        ? 0.0
                        : 0.14
                    )
            }

            Rectangle {
                anchors.fill: parent

                radius: 7

                color: "transparent"

                border.width: 1

                border.color:
                    root.selected
                    ? Qt.rgba(
                        Theme.accent.r,
                        Theme.accent.g,
                        Theme.accent.b,
                        0.55
                    )
                    : Qt.rgba(
                        Theme.foreground.r,
                        Theme.foreground.g,
                        Theme.foreground.b,
                        0.10
                    )
            }

            Text {
                anchors.centerIn:
                    parent

                visible:
                    root.path.length === 0 ||
                    (
                        root.isVideo() &&
                        root.thumbnail.length === 0
                    ) ||
                    wallpaperImage.status ===
                    Image.Error

                text:
                    root.isVideo()
                    ? "󰎁"
                    : "󰸉"

                color:
                    Theme.muted

                font.family:
                    Theme.fontFamily

                font.pixelSize: 24
            }

            Rectangle {
                visible:
                    root.isVideo() &&
                    wallpaperImage.status ===
                    Image.Ready

                anchors.right:
                    parent.right

                anchors.bottom:
                    parent.bottom

                anchors.margins: 5

                width: 20
                height: 16

                radius: 8

                color:
                    Qt.rgba(
                        Theme.background.r,
                        Theme.background.g,
                        Theme.background.b,
                        0.72
                    )

                Text {
                    anchors.centerIn:
                        parent

                    text: "󰐊"

                    color:
                        Theme.foreground

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 11
                }
            }

            Rectangle {
                anchors.fill: parent

                radius: 7

                visible:
                    wallpaperImage.status ===
                    Image.Loading

                color:
                    Qt.rgba(
                        Theme.background.r,
                        Theme.background.g,
                        Theme.background.b,
                        0.45
                    )

                Text {
                    anchors.centerIn:
                        parent

                    text: "󰑓"

                    color:
                        Theme.muted

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 16
                }
            }
        }

        Text {
            width: parent.width
            height: 14

            text:
                root.fileName()

            color:
                root.selected
                ? Theme.foreground
                : Theme.subtext

            font.family:
                Theme.fontFamily

            font.pixelSize: 9

            font.weight:
                Font.DemiBold

            elide:
                Text.ElideRight

            horizontalAlignment:
                Text.AlignLeft

            verticalAlignment:
                Text.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent

        z: 100

        hoverEnabled: true

        cursorShape:
            Qt.PointingHandCursor

        onEntered: {
            root.hovered = true
        }

        onExited: {
            root.hovered = false
        }

        onClicked: {
            root.triggered()
        }
    }
}
