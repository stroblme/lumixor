import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Window {
    id: controlRoot
    objectName: "controlRoot"
    visible: true
    onClosing: {
        if (outputWindow && outputWindow.close) outputWindow.close()
    }
    width: 640
    height: 480
    minimumWidth: 500
    minimumHeight: 400

    property int m_loadedVideoIndex: -1
    property bool isBlack: false
    property bool wasVideoPlaying: false
    property bool wasSlideshowRunning: false
    property string statusText: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            spacing: 8

            Button {
                id: btnAdd
                text: "Add"
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
                onCheckedChanged: {
                    var seconds = 5
                    if (checked) {
                        if (playbackController.isPlaying()) playbackController.pause()
                        slideshow.start(seconds * 1000)
                        statusText = "Slideshow started (" + seconds + " s per image)"
                        btnSlideshowToggle.text = "Pause Slideshow"
                    } else {
                        slideshow.pause()
                        statusText = "Slideshow paused"
                        btnSlideshowToggle.text = "Resume Slideshow"
                    }
                }
            }

            Button {
                id: btnBlackout
                text: "Blackout"
                onClicked: {
                    isBlack = !isBlack
                    if (isBlack) {
                        wasVideoPlaying = playbackController.isPlaying()
                        if (wasVideoPlaying) playbackController.pause()
                        wasSlideshowRunning = slideshow.isRunning()
                        if (wasSlideshowRunning) slideshow.stop()
                        btnBlackout.text = "Unblackout"
                    } else {
                        if (wasVideoPlaying) playbackController.play()
                        if (wasSlideshowRunning) slideshow.start(5000)
                        btnBlackout.text = "Blackout"
                    }
                    outputWindow.setBlackout(isBlack)
                }
            }

            Label {
                id: statusLabel
                Layout.fillWidth: true
                text: statusText
                elide: Label.ElideRight
            }
        }

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Images list
            ListView {
                id: listImages
                Layout.preferredWidth: controlRoot.width * 0.5
                Layout.fillHeight: true
                model: imageModel
                delegate: Rectangle {
                    width: listImages.width
                    height: 40
                    color: "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.margins: 8
                        text: model.path
                        elide: Text.ElideRight
                        width: parent.width - 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { outputWindow.fadeToImage(model.path) }
                    }
                }
            }

            // Videos list
            ListView {
                id: listVideos
                Layout.preferredWidth: controlRoot.width * 0.5
                Layout.fillHeight: true
                model: videoModel
                currentIndex: -1
                delegate: Rectangle {
                    width: listVideos.width
                    height: 40
                    color: "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.margins: 8
                        text: model.path
                        elide: Text.ElideRight
                        width: parent.width - 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { listVideos.currentIndex = index }
                    }
                }
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
}
