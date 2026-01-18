import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

MenuItem {
    id: control

    // Theme colors
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 40
        color: control.highlighted ? Qt.lighter(control.panelCol, 1.3) : "transparent"
    }

    contentItem: Text {
        text: control.text
        color: control.txtColor
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        leftPadding: 10
        font.pixelSize: Components.Theme.fontSize
    }
}
