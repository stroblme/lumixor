import QtQuick 2.12
import QtQuick.Controls 2.12

Switch {
    id: control

    // Theme colors
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    implicitWidth: 48
    implicitHeight: 26

    indicator: Rectangle {
        implicitWidth: 48
        implicitHeight: 26
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 13
        color: control.checked ? control.accentCol : control.panelCol
        border.color: control.borderCol

        Rectangle {
            x: control.checked ? parent.width - width - 4 : 4
            y: 4
            width: 18
            height: 18
            radius: 9
            color: "#FFFFFF"

            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
}
