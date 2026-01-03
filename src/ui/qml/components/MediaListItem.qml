import QtQuick 2.12
import QtQuick.Controls 2.12

Rectangle {
    id: control

    // Theme colors
    property color itemColor: typeof listItemColor !== "undefined" ? listItemColor : "#232323"
    property color highlightColor: typeof listItemHighlight !== "undefined" ? listItemHighlight : "#29434E"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color subtleTxtColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    // UI scaling - use globalUiScale context property (set at startup)
    property real scale: globalUiScale ? globalUiScale : 1.0

    // Content properties
    property string fileName: ""
    property bool isSelected: false

    // Signals
    signal clicked
    signal deleteClicked

    height: Math.round(40 * scale)
    color: isSelected ? highlightColor : itemColor
    radius: 3
    border.color: borderCol

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Math.round(8 * control.scale)
        text: control.fileName
        color: control.txtColor
        font.pixelSize: Math.round(13 * control.scale)
        elide: Text.ElideRight
        width: parent.width - Math.round(40 * control.scale)
    }

    // Delete button
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(8 * control.scale)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(20 * control.scale)
        height: Math.round(20 * control.scale)
        radius: Math.round(10 * control.scale)
        color: delMouseArea.containsMouse ? Qt.lighter(control.itemColor, 1.5) : "transparent"

        Text {
            anchors.centerIn: parent
            text: "×"
            color: control.subtleTxtColor
            font.pixelSize: Math.round(14 * control.scale)
        }

        MouseArea {
            id: delMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: control.deleteClicked()
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: Math.round(36 * control.scale)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onClicked: control.clicked()
    }
}
