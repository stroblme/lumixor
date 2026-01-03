import QtQuick 2.12
import QtQuick.Controls 2.12

SpinBox {
    id: control

    // Theme colors
    property color bgColor: typeof backgroundColor !== "undefined" ? backgroundColor : "#121212"
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#42A5F5"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color subtleTxtColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    implicitWidth: 120

    background: Rectangle {
        radius: 4
        color: control.bgColor
        border.color: control.borderCol
    }

    contentItem: TextInput {
        text: control.displayText
        font: control.font
        color: control.txtColor
        selectionColor: control.accentCol
        selectedTextColor: control.bgColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
    }

    up.indicator: Rectangle {
        x: control.mirrored ? 0 : control.width - width
        height: control.height
        implicitWidth: 38
        implicitHeight: 38
        color: control.up.pressed ? Qt.darker(control.panelCol, 1.2) : control.panelCol
        border.color: control.borderCol
        radius: 4

        Text {
            text: "+"
            font.pixelSize: 14
            color: control.subtleTxtColor
            anchors.centerIn: parent
        }
    }

    down.indicator: Rectangle {
        x: control.mirrored ? control.width - width : 0
        height: control.height
        implicitWidth: 38
        implicitHeight: 38
        color: control.down.pressed ? Qt.darker(control.panelCol, 1.2) : control.panelCol
        border.color: control.borderCol
        radius: 4

        Text {
            text: "-"
            font.pixelSize: 14
            color: control.subtleTxtColor
            anchors.centerIn: parent
        }
    }
}
