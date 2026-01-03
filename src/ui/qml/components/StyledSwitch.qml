import QtQuick 2.12
import QtQuick.Controls 2.12

Switch {
    id: control

    // Theme colors
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    indicator: Rectangle {
        implicitWidth: 48
        implicitHeight: 26
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 13
        color: control.checked ? control.accentCol : control.borderCol
        border.color: control.checked ? control.accentCol : control.borderCol

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            y: 2
            width: 22
            height: 22
            radius: 11
            color: control.panelCol

            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
}
