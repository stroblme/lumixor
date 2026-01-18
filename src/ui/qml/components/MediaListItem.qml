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

    // Theme colors - support both naming conventions
    property color itemColor: typeof listItemColor !== "undefined" ? listItemColor : "#232323"
    property color highlightColor: typeof listItemHighlight !== "undefined" ? listItemHighlight : "#29434E"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color subtleTxtColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    signal clicked
    signal deleteClicked

    height: Components.Theme.listItemHeight
    color: isSelected ? highlightColor : itemColor
    radius: Components.Theme.borderRadius
    border.color: borderCol

    // Display name: prefer fileName, fall back to extracting from filePath
    readonly property string displayName: fileName !== "" ? fileName : fileNameFromPath(filePath)

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

    function fileNameFromPath(p) {
        if (!p)
            return "";
        var s = String(p);
        var parts = s.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : s;
    }
}
