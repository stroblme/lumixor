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

    // Content properties
    property string fileName: ""
    property bool isSelected: false

    // Signals
    signal clicked
    signal deleteClicked

    height: 40
    color: isSelected ? highlightColor : itemColor
    radius: 3
    border.color: borderCol

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        text: control.fileName
        color: control.txtColor
        elide: Text.ElideRight
        width: parent.width - 40
    }

    // Delete button
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: 10
        color: delMouseArea.containsMouse ? Qt.lighter(control.itemColor, 1.5) : "transparent"

        Text {
            anchors.centerIn: parent
            text: "×"
            color: control.subtleTxtColor
            font.pixelSize: 14
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
        anchors.rightMargin: 36
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onClicked: control.clicked()
    }
}
