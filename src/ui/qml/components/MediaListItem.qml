import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

Rectangle {
    id: control

    // Primary property: fileName for display
    property string fileName: ""
    // Alternative property: filePath (for backward compatibility)
    property string filePath: ""
    property bool isSelected: false

    // Theme colors, overridable per instance
    property color itemColor: Components.Theme.listItemColor
    property color highlightColor: Components.Theme.listItemHighlight
    property color txtColor: Components.Theme.textColor
    property color subtleTxtColor: Components.Theme.subtleTextColor
    property color borderCol: Components.Theme.borderColor

    signal clicked
    signal deleteClicked

    height: Components.Theme.listItemHeight
    color: isSelected ? highlightColor : itemColor
    radius: Components.Theme.borderRadius
    border.color: borderCol

    // Display name: prefer fileName, fall back to extracting from filePath
    readonly property string displayName: fileName !== "" ? fileName : Components.Utils.fileNameFromPath(filePath)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        text: control.displayName
        color: control.txtColor
        elide: Text.ElideRight
        width: parent.width - 48
        font.pixelSize: Components.Theme.fontSize
    }

    // Delete button
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        color: delMouseArea.containsMouse ? Qt.lighter(control.itemColor, 1.5) : "transparent"

        Text {
            anchors.centerIn: parent
            text: "×"
            color: control.subtleTxtColor
            font.pixelSize: Components.Theme.fontSizeLarge
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
        anchors.rightMargin: 40
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onClicked: control.clicked()
    }

}
