import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.folderlistmodel 2.15

Popup {
    id: filePicker

    property string title: "Select File"
    property var nameFilters: ["All files (*)"]
    property string currentFolder: "file://" + standardPaths.home
    property bool selectFolder: false
    property bool selectMultiple: false
    property var selectedFiles: []

    signal accepted
    signal rejected

    // Helper for home directory
    QtObject {
        id: standardPaths
        property string home: Qt.resolvedUrl("~").toString().replace("file://", "") || "/home"
    }

    modal: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.85, 800)
    height: Math.min(parent.height * 0.85, 600)
    padding: 0

    background: Rectangle {
        color: "#1e1e1e"
        border.color: "#3d3d3d"
        border.width: 1
        radius: 8
    }

    // Main content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        // Header / Title bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "#2d2d2d"
            radius: 8

            // Square off bottom corners
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 8

                Label {
                    text: filePicker.title
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "#ffffff"
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: "✕"
                    flat: true
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    onClicked: {
                        filePicker.rejected();
                        filePicker.close();
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#3d3d3d" : "transparent"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? "#ff6b6b" : "#888888"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Navigation bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "#252525"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Back button
                Button {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    flat: true
                    enabled: folderModel.folder !== "file:///"
                    onClicked: {
                        folderModel.folder = folderModel.parentFolder;
                    }
                    background: Rectangle {
                        color: parent.hovered && parent.enabled ? "#3d3d3d" : "transparent"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "←"
                        color: parent.enabled ? "#ffffff" : "#555555"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Home button
                Button {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    flat: true
                    onClicked: {
                        folderModel.folder = filePicker.currentFolder;
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#3d3d3d" : "transparent"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "🏠"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Path breadcrumb / input
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: "#1a1a1a"
                    border.color: pathInput.activeFocus ? "#0078d4" : "#3d3d3d"
                    border.width: 1
                    radius: 4

                    TextInput {
                        id: pathInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: 12
                        selectByMouse: true
                        text: folderModel.folder.toString().replace("file://", "")
                        onAccepted: {
                            var newPath = "file://" + text;
                            folderModel.folder = newPath;
                        }
                    }
                }
            }
        }

        // Quick access sidebar + file list
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Quick access sidebar
            Rectangle {
                Layout.preferredWidth: 160
                Layout.fillHeight: true
                color: "#1a1a1a"

                ListView {
                    id: quickAccessList
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    clip: true

                    model: ListModel {
                        ListElement {
                            name: "Home"
                            icon: "🏠"
                            path: "~"
                        }
                        ListElement {
                            name: "Desktop"
                            icon: "🖥️"
                            path: "~/Desktop"
                        }
                        ListElement {
                            name: "Documents"
                            icon: "📄"
                            path: "~/Documents"
                        }
                        ListElement {
                            name: "Downloads"
                            icon: "⬇️"
                            path: "~/Downloads"
                        }
                        ListElement {
                            name: "Pictures"
                            icon: "🖼️"
                            path: "~/Pictures"
                        }
                        ListElement {
                            name: "Videos"
                            icon: "🎬"
                            path: "~/Videos"
                        }
                        ListElement {
                            name: "Music"
                            icon: "🎵"
                            path: "~/Music"
                        }
                    }

                    delegate: ItemDelegate {
                        width: quickAccessList.width
                        height: 32

                        background: Rectangle {
                            color: parent.hovered ? "#2d2d2d" : "transparent"
                            radius: 4
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: model.icon
                                font.pixelSize: 14
                            }

                            Text {
                                text: model.name
                                color: "#cccccc"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: {
                            var expandedPath = model.path.replace("~", standardPaths.home);
                            folderModel.folder = "file://" + expandedPath;
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: "#3d3d3d"
            }

            // File list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1e1e1e"

                ListView {
                    id: fileListView
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 2

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    model: FolderListModel {
                        id: folderModel
                        folder: filePicker.currentFolder
                        showDirs: true
                        showFiles: !filePicker.selectFolder
                        showDotAndDotDot: false
                        showHidden: false
                        sortField: FolderListModel.Name
                        nameFilters: filePicker.selectFolder ? [] : filePicker.nameFilters
                    }

                    delegate: ItemDelegate {
                        width: fileListView.width
                        height: 36

                        property bool isSelected: {
                            var fullPath = "file://" + filePath;
                            return filePicker.selectedFiles.indexOf(fullPath) !== -1;
                        }

                        background: Rectangle {
                            color: isSelected ? "#0078d4" : (parent.hovered ? "#2d2d2d" : "transparent")
                            radius: 4
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Icon
                            Text {
                                text: fileIsDir ? "📁" : getFileIcon(fileName)
                                font.pixelSize: 16

                                function getFileIcon(name) {
                                    var ext = name.split('.').pop().toLowerCase();
                                    if (["jpg", "jpeg", "png", "gif", "bmp", "svg", "webp"].indexOf(ext) !== -1)
                                        return "🖼️";
                                    if (["mp4", "mkv", "avi", "mov", "webm"].indexOf(ext) !== -1)
                                        return "🎬";
                                    if (["mp3", "wav", "flac", "ogg", "m4a"].indexOf(ext) !== -1)
                                        return "🎵";
                                    if (["pdf"].indexOf(ext) !== -1)
                                        return "📕";
                                    if (["txt", "md"].indexOf(ext) !== -1)
                                        return "📝";
                                    if (["zip", "tar", "gz", "7z", "rar"].indexOf(ext) !== -1)
                                        return "�";
                                    return "📄";
                                }
                            }

                            // Name
                            Text {
                                text: fileName
                                color: isSelected ? "#ffffff" : "#cccccc"
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            // Size (for files only)
                            Text {
                                text: fileIsDir ? "" : formatSize(fileSize)
                                color: isSelected ? "#dddddd" : "#888888"
                                font.pixelSize: 11
                                Layout.preferredWidth: 70
                                horizontalAlignment: Text.AlignRight

                                function formatSize(bytes) {
                                    if (bytes < 1024)
                                        return bytes + " B";
                                    if (bytes < 1024 * 1024)
                                        return (bytes / 1024).toFixed(1) + " KB";
                                    if (bytes < 1024 * 1024 * 1024)
                                        return (bytes / (1024 * 1024)).toFixed(1) + " MB";
                                    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
                                }
                            }
                        }

                        onClicked: {
                            if (fileIsDir) {
                                folderModel.folder = "file://" + filePath;
                            } else {
                                var fullPath = "file://" + filePath;
                                if (filePicker.selectMultiple) {
                                    var idx = filePicker.selectedFiles.indexOf(fullPath);
                                    if (idx === -1) {
                                        filePicker.selectedFiles = filePicker.selectedFiles.concat([fullPath]);
                                    } else {
                                        var arr = filePicker.selectedFiles.slice();
                                        arr.splice(idx, 1);
                                        filePicker.selectedFiles = arr;
                                    }
                                } else {
                                    filePicker.selectedFiles = [fullPath];
                                }
                            }
                        }

                        onDoubleClicked: {
                            if (fileIsDir) {
                                folderModel.folder = "file://" + filePath;
                            } else {
                                filePicker.selectedFiles = ["file://" + filePath];
                                filePicker.accepted();
                                filePicker.close();
                            }
                        }
                    }

                    // Empty state
                    Label {
                        anchors.centerIn: parent
                        text: "This folder is empty"
                        color: "#666666"
                        font.pixelSize: 14
                        visible: fileListView.count === 0
                    }
                }
            }
        }

        // Footer with filter and buttons
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "#252525"
            radius: 8

            // Square off top corners
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // File name input (for save dialogs)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: "#1a1a1a"
                    border.color: fileNameInput.activeFocus ? "#0078d4" : "#3d3d3d"
                    border.width: 1
                    radius: 4
                    visible: !filePicker.selectFolder

                    TextInput {
                        id: fileNameInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: 12
                        selectByMouse: true
                        text: filePicker.selectedFiles.length > 0 ? filePicker.selectedFiles[0].toString().split('/').pop() : ""
                    }
                }

                // Filter dropdown
                ComboBox {
                    id: filterCombo
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 32
                    model: filePicker.nameFilters
                    visible: !filePicker.selectFolder

                    background: Rectangle {
                        color: "#1a1a1a"
                        border.color: parent.pressed ? "#0078d4" : "#3d3d3d"
                        border.width: 1
                        radius: 4
                    }

                    contentItem: Text {
                        text: filterCombo.displayText
                        color: "#cccccc"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                    visible: filePicker.selectFolder
                }

                // Cancel button
                Button {
                    text: "Cancel"
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 32
                    onClicked: {
                        filePicker.rejected();
                        filePicker.close();
                    }
                    background: Rectangle {
                        color: parent.pressed ? "#2d2d2d" : (parent.hovered ? "#3d3d3d" : "#2a2a2a")
                        border.color: "#4d4d4d"
                        border.width: 1
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#cccccc"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Open/Select button
                Button {
                    text: filePicker.selectFolder ? "Select Folder" : "Open"
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 32
                    enabled: filePicker.selectedFiles.length > 0 || filePicker.selectFolder
                    onClicked: {
                        if (filePicker.selectFolder) {
                            filePicker.selectedFiles = [folderModel.folder];
                        }
                        filePicker.accepted();
                        filePicker.close();
                    }
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#005a9e" : (parent.hovered ? "#1e8ad4" : "#0078d4")) : "#2a2a2a"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "#ffffff" : "#666666"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Reset selection when opening
    onOpened: {
        selectedFiles = [];
        folderModel.folder = currentFolder;
    }
}
