import QtQuick
import ".."

Row {
    id: root

    spacing: 3
    height: 42

    property int currentMode: 0
    signal modeSelected(int mode)

    Repeater {
        model: [
            { label: "󰀻  Apps", mode: 0 },
            { label: "󰆍  Run", mode: 1 },
            { label: "󰖯  Windows", mode: 2 },
            { label: "󰸉  Wallpaper", mode: 3 }
        ]

        delegate: Rectangle {
            required property var modelData

            property bool hovered: false

            width:
                Math.max(
                    92,
                    (root.width - 9) / 4
                )

            height: 36
            radius: 7

            color:
                root.currentMode === modelData.mode
                ? Qt.rgba(
                    Theme.accent.r,
                    Theme.accent.g,
                    Theme.accent.b,
                    0.16
                )
                : hovered
                    ? Qt.rgba(
                        Theme.accent.r,
                        Theme.accent.g,
                        Theme.accent.b,
                        0.08
                    )
                    : "transparent"

            border.width:
                root.currentMode === modelData.mode
                ? 1
                : 0

            border.color:
                Qt.rgba(
                    Theme.accent.r,
                    Theme.accent.g,
                    Theme.accent.b,
                    0.35
                )

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
            }

            Text {
                anchors.centerIn: parent

                text:
                    modelData.label

                color:
                    root.currentMode === modelData.mode
                    ? Theme.accent
                    : hovered
                        ? Theme.foreground
                        : Theme.muted

                font.family:
                    Theme.fontFamily

                font.pixelSize: 10

                font.weight:
                    root.currentMode === modelData.mode
                    ? Font.Bold
                    : Font.Normal
            }

            MouseArea {
                anchors.fill: parent

                hoverEnabled: true

                cursorShape:
                    Qt.PointingHandCursor

                onEntered: {
                    parent.hovered = true
                }

                onExited: {
                    parent.hovered = false
                }

                onClicked: {
                    root.modeSelected(
                        modelData.mode
                    )
                }
            }
        }
    }
}