import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

Switch {
    id: control

    // Theme colors
    property color panelCol: Components.Theme.panelColor
    property color accentCol: Components.Theme.accentColor
    property color borderCol: Components.Theme.borderColor

    implicitWidth: Components.Theme.switchWidth
    implicitHeight: Components.Theme.switchHeight

    indicator: Rectangle {
        implicitWidth: Components.Theme.switchIndicatorWidth
        implicitHeight: Components.Theme.switchIndicatorHeight
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: Components.Theme.switchIndicatorHeight / 2
        color: control.checked ? control.accentCol : control.panelCol
        border.color: control.borderCol

        Rectangle {
            x: control.checked ? parent.width - width - 4 : 4
            y: 4
            width: Components.Theme.switchHandleSize
            height: Components.Theme.switchHandleSize
            radius: Components.Theme.switchHandleSize / 2
            color: "#FFFFFF"

            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
}
