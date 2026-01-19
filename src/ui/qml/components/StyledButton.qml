import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

Button {
    id: control

    // Theme colors - inherit from root or use defaults
    property color bgColor: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color hoverColor: Qt.lighter(bgColor, 1.25)
    property color pressedColor: typeof accentColor !== "undefined" ? accentColor : "#78909C"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

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
