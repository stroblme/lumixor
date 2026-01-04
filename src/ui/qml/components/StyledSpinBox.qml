import QtQuick 2.12
import QtQuick.Controls 2.12

SpinBox {
    id: control

    property color bgColor: typeof backgroundColor !== "undefined" ? backgroundColor : "#121212"
    property color panelCol: typeof panelColor !== "undefined" ? panelColor : "#1E1E1E"
    property color accentCol: typeof accentColor !== "undefined" ? accentColor : "#78909C"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color subtleTxtColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    implicitWidth: 120
    implicitHeight: 36

    contentItem: TextInput {
        z: 2
        text: control.textFromValue(control.value, control.locale)
        font.pixelSize: 13
        color: control.txtColor
        selectionColor: control.accentCol
        selectedTextColor: control.txtColor
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    up.indicator: Rectangle {
        x: control.mirrored ? 0 : parent.width - width
        height: parent.height
        implicitWidth: 28
        implicitHeight: 28
        radius: 4
        color: control.up.pressed ? control.accentCol : control.up.hovered ? Qt.lighter(control.panelCol, 1.3) : control.panelCol
        border.color: control.borderCol

        Text {
            text: "+"
            font.pixelSize: 14
            color: control.txtColor
            anchors.centerIn: parent
        }
    }

    down.indicator: Rectangle {
        x: control.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: 28
        implicitHeight: 28
        radius: 4
        color: control.down.pressed ? control.accentCol : control.down.hovered ? Qt.lighter(control.panelCol, 1.3) : control.panelCol
        border.color: control.borderCol

        Text {
            text: "-"
            font.pixelSize: 14
            color: control.txtColor
            anchors.centerIn: parent
        }
    }

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 36
        radius: 4
        color: control.bgColor
        border.color: control.borderCol
    }
}
