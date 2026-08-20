import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

TabButton {
    id: control

    property color bgColor: Components.Theme.backgroundColor
    property color panelCol: Components.Theme.panelColor
    property color accentCol: Components.Theme.accentColor
    property color txtColor: Components.Theme.textColor
    property color subtleTxtColor: Components.Theme.subtleTextColor
    property color borderCol: Components.Theme.borderColor

    implicitWidth: Components.Theme.tabButtonMinWidth
    implicitHeight: Components.Theme.tabButtonHeight

    background: Rectangle {
        color: control.checked ? control.panelCol : (control.hovered ? Qt.lighter(control.bgColor, 1.2) : control.bgColor)
        border.color: control.checked ? control.accentCol : control.borderCol
        border.width: control.checked ? 2 : 1
        radius: Components.Theme.borderRadius
    }

    contentItem: Text {
        text: control.text
        color: control.checked ? control.txtColor : control.subtleTxtColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.pixelSize: Components.Theme.fontSizeLarge
    }
}
