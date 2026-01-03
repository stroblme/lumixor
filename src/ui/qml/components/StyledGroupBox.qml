import QtQuick 2.12
import QtQuick.Controls 2.12

GroupBox {
    id: control

    // Theme colors
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    label: Label {
        text: control.title
        color: control.txtColor
    }

    background: Rectangle {
        radius: 6
        color: control.panelCol
        border.color: control.borderCol
    }
}
