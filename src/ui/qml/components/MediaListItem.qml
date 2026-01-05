import QtQuick 2.12
import QtQuick.Controls 2.12

Rectangle {
    id: control

    property string filePath: ""
    property bool isCurrentItem: false

    property color listItemCol: typeof listItemColor !== "undefined" ? listItemColor : "#232323"
    property color highlightCol: typeof listItemHighlight !== "undefined" ? listItemHighlight : "#29434E"
    property color txtColor: typeof textColor !== "undefined" ? textColor : "#E0E0E0"
    property color subtleTxtColor: typeof subtleTextColor !== "undefined" ? subtleTextColor : "#9E9E9E"
    property color borderCol: typeof borderColor !== "undefined" ? borderColor : "#333333"

    signal removeClicked
    signal itemClicked

    height: 40
    color: isCurrentItem ? highlightCol : listItemCol
    radius: 6
    border.color: borderCol

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        text: fileNameFromPath(control.filePath)
        color: control.txtColor
        elide: Text.ElideRight
        width: parent.width - 40
        font.pixelSize: 14

        function fileNameFromPath(p) {
            if (!p)
                return "";
            var s = String(p);
            var parts = s.split("/");
            return parts.length > 0 ? parts[parts.length - 1] : s;
        }
    }

    // Delete button
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: 10
        color: delMouseArea.containsMouse ? Qt.lighter(control.listItemCol, 1.5) : "transparent"

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
            onClicked: control.removeClicked()
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 36
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onClicked: control.itemClicked()
    }
}
