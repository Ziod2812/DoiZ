import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root

    property string path: ""
    property string thumbnail: ""
    property int position: 0
    property int total: 0

    height:
        frame.height +
        infoColumn.height +
        10

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
        if (!root.path || root.path.length === 0)
            return "No wallpaper selected"

        var parts =
            root.path.split("/")

        return parts[parts.length - 1]
    }

    Rectangle {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height:
            Math.round(
                width * 0.5625
            )

        radius: 8

        clip: true

        color:
            Qt.rgba(
                Theme.background.r,
                Theme.background.g,
                Theme.background.b,
                0.70
            )

        Image {
            id: previewImage

            anchors.fill: parent
            anchors.margins: 1

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

            sourceSize.width: 800
            sourceSize.height: 450

            opacity:
                status === Image.Ready
                ? 1
                : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        Text {
            anchors.centerIn:
                parent

            visible:
                previewImage.status !==
                Image.Ready

            text:
                previewImage.status ===
                Image.Loading
                ? "󰑓"
                : root.isVideo()
                    ? "󰎁"
                    : "󰸉"

            color:
                Theme.muted

            font.family:
                Theme.fontFamily

            font.pixelSize: 22
        }

        Rectangle {
            visible:
                root.isVideo() &&
                previewImage.status ===
                Image.Ready

            anchors.right:
                parent.right

            anchors.bottom:
                parent.bottom

            anchors.margins: 6

            width: 22
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

            radius: 8

            color: "transparent"

            border.width: 1

            border.color:
                Qt.rgba(
                    Theme.accent.r,
                    Theme.accent.g,
                    Theme.accent.b,
                    0.45
                )
        }
    }

    Column {
        id: infoColumn

        anchors.left:
            parent.left

        anchors.right:
            parent.right

        anchors.top:
            frame.bottom

        anchors.topMargin: 10

        spacing: 6

        Text {
            width: parent.width

            text:
                root.fileName()

            color:
                Theme.foreground

            font.family:
                Theme.fontFamily

            font.pixelSize: 12

            font.weight:
                Font.DemiBold

            elide:
                Text.ElideMiddle
        }

        Text {
            width: parent.width

            visible:
                root.path.length > 0

            text:
                (
                    root.isVideo()
                    ? "󰎁 Video wallpaper"
                    : "󰸉 Image wallpaper"
                ) +
                "  ·  " +
                root.position +
                " / " +
                root.total

            color:
                Theme.muted

            font.family:
                Theme.fontFamily

            font.pixelSize: 9

            elide:
                Text.ElideRight
        }
    }
}
