import QtQuick 2.12
import QtQuick.Controls 2.12

Button {
    id: control

    // Theme colors - inherit from root or use defaults
    property color bgColor: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color hoverColor: Qt.lighter(bgColor, 1.25)
    property color pressedColor: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    // UI scaling
    property real scale: typeof uiScale !== "undefined" ? uiScale : 1.0

    property int radius: 6

    background: Rectangle {
        radius: control.radius
        implicitHeight: Math.round(44 * control.scale)
        border.color: control.borderCol
        color: control.down ? control.pressedColor : control.hovered ? control.hoverColor : control.bgColor
    }

    contentItem: Text {
        text: control.text
        color: control.txtColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Math.round(13 * control.scale)
    }
}
