import QtQuick 2.12

Rectangle {
    id: control

    property color handleColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"

    width: 8
    height: 16
    color: "transparent"

    Column {
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: 3
            Rectangle {
                width: 8
                height: 2
                radius: 1
                color: control.handleColor
            }
        }
    }
}
