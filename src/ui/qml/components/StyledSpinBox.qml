import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

SpinBox {
    id: control

    property color bgColor: Components.Theme.backgroundColor
    property color panelCol: Components.Theme.panelColor
    property color accentCol: Components.Theme.accentColor
    property color txtColor: Components.Theme.textColor
    property color subtleTxtColor: Components.Theme.subtleTextColor
    property color borderCol: Components.Theme.borderColor

    implicitWidth: Components.Theme.spinBoxWidth
    implicitHeight: Components.Theme.spinBoxHeight

    contentItem: TextInput {
        z: 2
        text: control.textFromValue(control.value, control.locale)
        font.pixelSize: Components.Theme.fontSize
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
        implicitWidth: Components.Theme.spinBoxButtonWidth
        implicitHeight: Components.Theme.spinBoxButtonWidth
        radius: Components.Theme.borderRadius
        color: control.up.pressed ? control.accentCol : control.up.hovered ? Qt.lighter(control.panelCol, 1.3) : control.panelCol
        border.color: control.borderCol

        Text {
            text: "+"
            font.pixelSize: Components.Theme.fontSize
            color: control.txtColor
            anchors.centerIn: parent
        }
    }

    down.indicator: Rectangle {
        x: control.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: Components.Theme.spinBoxButtonWidth
        implicitHeight: Components.Theme.spinBoxButtonWidth
        radius: Components.Theme.borderRadius
        color: control.down.pressed ? control.accentCol : control.down.hovered ? Qt.lighter(control.panelCol, 1.3) : control.panelCol
        border.color: control.borderCol

        Text {
            text: "-"
            font.pixelSize: Components.Theme.fontSize
            color: control.txtColor
            anchors.centerIn: parent
        }
    }

    background: Rectangle {
        implicitWidth: Components.Theme.spinBoxWidth
        implicitHeight: Components.Theme.spinBoxHeight
        radius: Components.Theme.borderRadius
        color: control.bgColor
        border.color: control.borderCol
    }
}
