import QtQuick 2.12
import QtQuick.Controls 2.12

Slider {
    id: control

    // Theme colors
    property color bgColor: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#78909C"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    property int handleSize: 28
    property int trackHeight: 8

    handle: Rectangle {
        x: control.leftPadding + (control.horizontal ? control.visualPosition * (control.availableWidth - width) : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : control.visualPosition * (control.availableHeight - height))
        width: control.handleSize
        height: control.handleSize
        radius: control.handleSize / 2
        color: control.pressed ? control.accentCol : control.bgColor
        border.color: control.accentCol
        border.width: 2
    }

    background: Rectangle {
        x: control.leftPadding + (control.horizontal ? 0 : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : 0)
        width: control.horizontal ? control.availableWidth : control.trackHeight
        height: control.horizontal ? control.trackHeight : control.availableHeight
        radius: control.trackHeight / 2
        color: control.borderCol

        Rectangle {
            width: control.horizontal ? control.visualPosition * parent.width : parent.width
            height: control.horizontal ? parent.height : (1 - control.visualPosition) * parent.height
            y: control.horizontal ? 0 : control.visualPosition * parent.height
            radius: control.trackHeight / 2
            color: control.accentCol
        }
    }
}
