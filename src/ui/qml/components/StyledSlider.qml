import QtQuick 2.12
import QtQuick.Controls 2.12

Slider {
    id: control

    // Theme colors
    property color bgColor: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    // UI scaling - use globalUiScale context property (set at startup)
    property real scale: globalUiScale ? globalUiScale : 1.0

    property int handleSize: Math.round(28 * scale)
    property int trackHeight: Math.round(8 * scale)

    implicitHeight: Math.round(44 * scale)

    handle: Rectangle {
        x: control.orientation === Qt.Horizontal ? control.leftPadding + control.visualPosition * (control.availableWidth - width) : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.orientation === Qt.Horizontal ? control.topPadding + control.availableHeight / 2 - height / 2 : control.topPadding + control.visualPosition * (control.availableHeight - height)
        width: control.handleSize
        height: control.handleSize
        radius: control.handleSize / 2
        color: control.pressed ? control.accentCol : control.bgColor
        border.color: control.accentCol
        border.width: 2
    }

    background: Rectangle {
        x: control.orientation === Qt.Horizontal ? control.leftPadding : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.orientation === Qt.Horizontal ? control.topPadding + control.availableHeight / 2 - height / 2 : control.topPadding
        width: control.orientation === Qt.Horizontal ? control.availableWidth : control.trackHeight
        height: control.orientation === Qt.Horizontal ? control.trackHeight : control.availableHeight
        radius: control.trackHeight / 2
        color: control.borderCol

        Rectangle {
            width: control.orientation === Qt.Horizontal ? control.visualPosition * parent.width : parent.width
            height: control.orientation === Qt.Horizontal ? parent.height : (1 - control.visualPosition) * parent.height
            y: control.orientation === Qt.Horizontal ? 0 : control.visualPosition * parent.height
            radius: control.trackHeight / 2
            color: control.accentCol
        }
    }
}
