import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

GroupBox {
    id: control

    property color panelCol: Components.Theme.panelColor
    property color txtColor: Components.Theme.textColor
    property color borderCol: Components.Theme.borderColor

    label: Label {
        x: control.leftPadding
        width: control.availableWidth
        text: control.title
        color: control.txtColor
        font.bold: true
        font.pixelSize: Components.Theme.fontSize
        elide: Text.ElideRight
    }

    background: Rectangle {
        y: control.topPadding - control.bottomPadding / 2
        width: parent.width
        height: parent.height - control.topPadding + control.bottomPadding
        color: "transparent"
        border.color: control.borderCol
        radius: Components.Theme.borderRadius
    }
}
