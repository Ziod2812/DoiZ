import QtQuick
import QtQuick.Controls
import ".."

Rectangle {
    id: root

    height: 46
    radius: 10

    color:
        Qt.rgba(
            Theme.surface.r,
            Theme.surface.g,
            Theme.surface.b,
            0.82
        )

    border.width: 1

    border.color:
        Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.20
        )

    property alias text: input.text
    property alias input: input

    signal accepted()

    Row {
        anchors.fill: parent

        anchors.leftMargin: 10
        anchors.rightMargin: 10

        spacing: 9

        Rectangle {
            width: 30
            height: 30

            radius: 6

            anchors.verticalCenter:
                parent.verticalCenter

            color:
                Theme.accent

            Text {
                anchors.centerIn: parent

                text: "⌕"

                color:
                    Theme.background

                font.family:
                    Theme.fontFamily

                font.pixelSize: 16

                font.bold: true
            }
        }

        TextField {
            id: input

            width:
                parent.width - 39

            height:
                parent.height

            anchors.verticalCenter:
                parent.verticalCenter

            background:
                Item {}

            color:
                Theme.foreground

            placeholderText:
                "Find something..."

            placeholderTextColor:
                Theme.muted

            font.family:
                Theme.fontFamily

            font.pixelSize: 11

            selectByMouse:
                true

            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0

            onAccepted:
                root.accepted()
        }
    }
}