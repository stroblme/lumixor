import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

Button {
    id: control

    // Theme colors, overridable per instance
    property color bgColor: Components.Theme.panelColor
    property color hoverColor: Qt.lighter(bgColor, 1.25)
    property color pressedColor: Components.Theme.accentColor
    property color txtColor: Components.Theme.textColor
    property color borderCol: Components.Theme.borderColor

    property string iconText: ""
    property int iconSize: Components.Theme.iconSize
    property int radius: Components.Theme.borderRadius

    implicitWidth: Components.Theme.buttonWidth
    implicitHeight: Components.Theme.buttonHeight

    background: Rectangle {
        radius: control.radius
        implicitHeight: Components.Theme.buttonHeight
        border.color: control.borderCol
        color: control.down ? control.pressedColor : control.hovered ? control.hoverColor : control.bgColor
    }

    contentItem: Text {
        text: control.text
        color: control.txtColor
        font.pixelSize: Components.Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
