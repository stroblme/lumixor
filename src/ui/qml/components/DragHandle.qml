import QtQuick 2.12
import "." as Components

Rectangle {
    id: control

    property color handleColor: Components.Theme.subtleTextColor

    readonly property real handleScale: Components.Theme.scaleFactor

    width: Math.round(8 * handleScale)
    height: Math.round(16 * handleScale)
    color: "transparent"

    Column {
        anchors.centerIn: parent
        spacing: Math.round(2 * control.handleScale)

        Repeater {
            model: 3
            Rectangle {
                width: Math.round(8 * control.handleScale)
                height: Math.round(2 * control.handleScale)
                radius: 1
                color: control.handleColor
            }
        }
    }
}
