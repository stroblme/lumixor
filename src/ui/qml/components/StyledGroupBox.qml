import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

GroupBox {
    id: control

    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

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
