import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Window {
    id: controlRoot
    objectName: "controlRoot"
    visible: true
    visibility: Window.Maximized
    onClosing: {
        if (outputWindow && outputWindow.close) outputWindow.close()
    }

    width: 860
    height: 560
    minimumWidth: 680
    minimumHeight: 420

    // Default values, overridden from PreferencesController when available
    property int slideshowDelaySeconds: preferences ? preferences.slideshowIntervalSeconds : 5
    property int transitionDurationMs: preferences ? preferences.transitionDurationMs : 200
    property int outputScreenIndex: preferences ? preferences.outputScreenIndex : 1

    property int m_loadedVideoIndex: -1
    property bool isBlack: false
    property bool wasVideoPlaying: false
    property bool wasSlideshowRunning: false
    property string statusText: ""

    // Dark theme colors for the control UI
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#42A5F5"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"
    property color listItemColor: "#232323"
    property color listItemHighlight: "#29434E"

    color: backgroundColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Top control bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 6
            color: panelColor
            border.color: borderColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Button {
                    id: btnAdd
                    text: "Add"
                    Layout.preferredWidth: 90
                    background: Rectangle {
                        radius: 6
                        implicitHeight: 32
                        border.color: borderColor
                        color: btnAdd.down || btnAdd.checked
                               ? accentColor
                               : btnAdd.hovered
                                 ? Qt.lighter(panelColor, 1.25)
                                 : panelColor
                    }
                    contentItem: Text {
                        text: btnAdd.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        var files = controlBridge.openFileDialog()
                        for (var i = 0; i < files.length; ++i) {
                            mediaManager.addMedia(files[i])
                        }
                    }
                }

                Button {
                    id: btnPlayToggle
                    checkable: true
                    text: "Play"
                    Layout.preferredWidth: 120
                    background: Rectangle {
                        radius: 6
                        implicitHeight: 32
                        border.color: borderColor
                        color: btnPlayToggle.down || btnPlayToggle.checked
                               ? accentColor
                               : btnPlayToggle.hovered
                                 ? Qt.lighter(panelColor, 1.25)
                                 : panelColor
                    }
                    contentItem: Text {
                        text: btnPlayToggle.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onCheckedChanged: {
                        if (checked) {
                            var row = listVideos.currentIndex
                            if (row < 0) {
                                btnPlayToggle.checked = false
                                statusText = "No video selected"
                                return
                            }
                            if (row !== m_loadedVideoIndex) {
                                var item = videoModel.get(row)
                                playbackController.loadMediaPath(item.path)
                                outputWindow.showVideo()
                                m_loadedVideoIndex = row
                                statusText = "Playing video: " + item.path
                            }
                            playbackController.play()
                            btnPlayToggle.text = "Pause"
                        } else {
                            playbackController.pause()
                            statusText = "Video paused"
                            btnPlayToggle.text = "Resume"
                        }
                    }
                }

                Button {
                    id: btnSlideshowToggle
                    checkable: true
                    text: "Start Slideshow"
                    Layout.preferredWidth: 160
                    background: Rectangle {
                        radius: 6
                        implicitHeight: 32
                        border.color: borderColor
                        color: btnSlideshowToggle.down || btnSlideshowToggle.checked
                               ? accentColor
                               : btnSlideshowToggle.hovered
                                 ? Qt.lighter(panelColor, 1.25)
                                 : panelColor
                    }
                    contentItem: Text {
                        text: btnSlideshowToggle.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onCheckedChanged: {
                        if (checked) {
                            if (playbackController.isPlaying()) playbackController.pause()
                            slideshow.start(slideshowDelaySeconds * 1000)
                            statusText = "Slideshow started (" + slideshowDelaySeconds + " s per image)"
                            btnSlideshowToggle.text = "Pause Slideshow"
                        } else {
                            slideshow.pause()
                            statusText = "Slideshow paused"
                            btnSlideshowToggle.text = "Resume Slideshow"
                        }
                    }
                }

                Slider {
                    id: brightnessSlider
                    from: 0.0
                    to: 1.0
                    value: 1.0
                    Layout.preferredWidth: 160
                    ToolTip.visible: hovered
                    ToolTip.text: "Brightness: " + Math.round(value * 100) + "%"
                    onValueChanged: {
                        // Pause media when fully black, resume if previously running when brightened
                        outputWindow.setBrightness(value)
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: btnSettings
                    text: "Settings"
                    Layout.preferredWidth: 90
                    background: Rectangle {
                        radius: 6
                        implicitHeight: 32
                        border.color: borderColor
                        color: btnSettings.down || btnSettings.checked
                               ? accentColor
                               : btnSettings.hovered
                                 ? Qt.lighter(panelColor, 1.25)
                                 : panelColor
                    }
                    contentItem: Text {
                        text: btnSettings.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    onClicked: {
                        var component = Qt.createComponent("qrc:/qml/PreferencesWindow.qml")
                        if (component.status === Component.Ready) {
                            var win = component.createObject(null, { "preferences": preferences })
                            if (win) {
                                win.show()
                            }
                        } else {
                            console.warn("Failed to load PreferencesWindow:", component.errorString())
                        }
                    }
                }
            }
        }

        // Main content area with lists
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: panelColor
            border.color: borderColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Images list
                ListView {
                    id: listImages
                    Layout.preferredWidth: controlRoot.width * 0.5
                    Layout.fillHeight: true
                    clip: true
                    model: imageModel
                    delegate: Rectangle {
                        width: listImages.width
                        height: 40
                        color: ListView.isCurrentItem ? listItemHighlight : listItemColor
                        radius: 3
                        border.color: borderColor
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            text: fileNameFromPath(model.path)
                            color: textColor
                            elide: Text.ElideRight
                            width: parent.width - 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                listImages.currentIndex = index
                                outputWindow.fadeToImage(model.path)
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar { }
                }

                // Videos list
                ListView {
                    id: listVideos
                    Layout.preferredWidth: controlRoot.width * 0.5
                    Layout.fillHeight: true
                    clip: true
                    model: videoModel
                    currentIndex: -1
                    delegate: Rectangle {
                        width: listVideos.width
                        height: 40
                        color: ListView.isCurrentItem ? listItemHighlight : listItemColor
                        radius: 3
                        border.color: borderColor
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            text: fileNameFromPath(model.path)
                            color: textColor
                            elide: Text.ElideRight
                            width: parent.width - 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { listVideos.currentIndex = index }
                        }
                    }
                    ScrollBar.vertical: ScrollBar { }
                }
            }
        }

        // Bottom status bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 6
            color: panelColor
            border.color: borderColor

            Label {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                text: statusText
                color: subtleTextColor
                elide: Label.ElideRight
            }
        }
    }

    ListModel { id: imageModel }
    ListModel { id: videoModel }

    function refreshLists() {
        imageModel.clear()
        videoModel.clear()
        for (var i = 0; i < mediaManager.count(); ++i) {
            var t = mediaManager.typeAt(i)
            var p = mediaManager.pathAt(i)
            if (t === "image") imageModel.append({ "path": p })
            else if (t === "video") videoModel.append({ "path": p })
        }
    }

    Component.onCompleted: refreshLists()

    Connections { target: mediaManager; onItemsChanged: refreshLists() }

    Connections {
        target: playbackController
        onMediaFinished: {
            statusText = "Media finished"
            btnPlayToggle.checked = false
            btnPlayToggle.text = "Play"
            m_loadedVideoIndex = -1
        }
    }

    function fileNameFromPath(p) {
        if (!p)
            return "";
        var s = String(p);
        var parts = s.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : s;
    }
}
