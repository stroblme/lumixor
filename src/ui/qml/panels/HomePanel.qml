import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

Item {
    id: root

    // Theme colors - passed from parent
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#78909C"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"

    // Signals
    signal addFilesClicked(var files)
    signal addFolderClicked(string folder)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Label {
            text: qsTr("Welcome to Lumixor")
            color: root.textColor
            font.bold: true
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: qsTr("Add media files to get started")
            color: root.subtleTextColor
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: 20
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Components.StyledButton {
                text: qsTr("Add Files")
                Layout.preferredWidth: 140
                Layout.preferredHeight: 48
                bgColor: root.panelColor
                pressedColor: root.accentColor
                txtColor: root.textColor
                borderCol: root.borderColor
                onClicked: root.addFilesClicked("")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Add images or videos - creates new tabs automatically")
            }

            Components.StyledButton {
                text: qsTr("Add Folder")
                Layout.preferredWidth: 140
                Layout.preferredHeight: 48
                bgColor: root.panelColor
                pressedColor: root.accentColor
                txtColor: root.textColor
                borderCol: root.borderColor
                onClicked: root.addFolderClicked("")
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Recursively scan a folder - creates new tabs automatically")
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
