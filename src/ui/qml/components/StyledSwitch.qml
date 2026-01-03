import QtQuick 2.12
import QtQuick.Controls 2.12

Switch {
    id: control

    // Theme colors
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    // UI scaling
    property real scale: typeof uiScale !== "undefined" ? uiScale : 1.0

    indicator: Rectangle {
        implicitWidth: Math.round(48 * control.scale)
        implicitHeight: Math.round(26 * control.scale)
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: Math.round(13 * control.scale)
        color: control.checked ? control.accentCol : control.borderCol
        border.color: control.checked ? control.accentCol : control.borderCol

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            y: 2
            width: Math.round(22 * control.scale)
            height: Math.round(22 * control.scale)
            radius: Math.round(11 * control.scale)
            color: control.panelCol

            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
}
