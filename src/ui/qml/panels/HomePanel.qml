import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

// Welcome screen shown when no media tabs exist. Emits signals; ControlWindow
// opens the dialogs and creates the tabs.
Item {
    id: root

    signal addFilesClicked
    signal addFolderClicked

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: 20
        }
        Label {
            text: qsTr("Welcome to Lumixor")
            color: Components.Theme.textColor
            font.bold: true
            font.pixelSize: Components.Theme.fontSizeLarge
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: qsTr("Add media files to get started")
            color: Components.Theme.subtleTextColor
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
                onClicked: root.addFilesClicked()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Add images or videos - creates new tabs automatically")
            }

            Components.StyledButton {
                text: qsTr("Add Folder")
                Layout.preferredWidth: 140
                Layout.preferredHeight: 48
                onClicked: root.addFolderClicked()
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Recursively scan a folder - creates new tabs automatically")
            }
        }
    }
}
