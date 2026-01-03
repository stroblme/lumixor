import QtQuick 2.12

Rectangle {
    id: control

    property color handleColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"

    // UI scaling - access from preferences context property or use default
    property real scale: typeof preferences !== "undefined" && preferences ? preferences.uiScale : 1.0

    width: Math.round(8 * scale)
    height: Math.round(16 * scale)
    color: "transparent"

    Column {
        anchors.centerIn: parent
        spacing: Math.round(2 * control.scale)

        Repeater {
            model: 3
            Rectangle {
                width: Math.round(8 * control.scale)
                height: Math.round(2 * control.scale)
                radius: 1
                color: control.handleColor
            }
        }
    }
}
