import QtQuick 2.12
import QtQuick.Controls 2.12

TabButton {
    id: control

    // Theme colors
    property color bgColor: typeof backgroundColor !== "undefined" ? backgroundColor : "#121212"
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color subtleTxtColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    // UI scaling - use globalUiScale context property (set at startup)
    property real scale: globalUiScale ? globalUiScale : 1.0

    implicitWidth: Math.round(100 * scale)
    implicitHeight: Math.round(36 * scale)

    background: Rectangle {
        color: control.checked ? control.panelCol : (control.hovered ? Qt.lighter(control.bgColor, 1.2) : control.bgColor)
        border.color: control.checked ? control.accentCol : control.borderCol
        border.width: control.checked ? 2 : 1
        radius: 4
    }

    contentItem: Text {
        text: control.text
        color: control.checked ? control.txtColor : control.subtleTxtColor
        font.pixelSize: Math.round(13 * control.scale)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
