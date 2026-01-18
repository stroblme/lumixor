import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtMultimedia 5.15
import "../components" as Components

Item {
    id: root

    // Theme colors - defaults that can be overridden by parent
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#78909C"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"
    property color listItemColor: "#232323"
    property color listItemHighlight: "#29434E"

    // Tab data
    property var tabData: null
    property var mediaModel: null
    property bool isSlideshow: tabData ? tabData.tabType === "slideshow" : false
    property int tabModelIndex: -1

    // External references (passed from parent)
    property var mediaTabsModel: null
    property var outputWindow: null
    property var slideshow: null
    property int activeSlideshowTabId: -1
    property int slideshowDelaySeconds: 5
    property bool loopVideos: true

    // Signals
    signal statusChanged(string message)
    signal slideshowStarted(int tabId, int tabIndex)
    signal slideshowPaused
    signal slideshowStopped

    // Helper functions
    function formatTime(ms) {
        if (isNaN(ms) || ms < 0)
            return "0:00";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" : "") + sec;
    }

    function fileNameFromPath(p) {
        if (!p)
            return "";
        var s = String(p);
        var parts = s.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : s;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Controls row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Slideshow Play/Pause Button
                Components.IconButton {
                    id: slideshowPlayPauseBtn
                    visible: root.isSlideshow
                    checkable: true
                    iconText: checked ? "⏸" : "▶"
                    ToolTip.visible: hovered
                    ToolTip.text: checked ? qsTr("Pause Slideshow") : qsTr("Start Slideshow")
                    bgColor: root.panelColor
                    pressedColor: root.accentColor
                    txtColor: root.textColor
                    borderCol: root.borderColor
                    onCheckedChanged: {
                        if (checked) {
                            startSlideshow();
                        } else {
                            pauseSlideshow();
                        }
                    }
                }

                // Slideshow Stop Button
                Components.IconButton {
                    id: slideshowStopBtn
                    visible: root.isSlideshow
                    iconText: "⏹"
                    iconSize: Components.Theme.iconSize
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Stop Slideshow")
                    bgColor: root.panelColor
                    pressedColor: root.accentColor
                    txtColor: root.textColor
                    borderCol: root.borderColor
                    onClicked: stopSlideshow()
                }

                Label {
                    visible: root.isSlideshow
                    text: qsTr("Delay: ") + root.slideshowDelaySeconds + qsTr(" s")
                    color: root.textColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.alignment: Qt.AlignVCenter
                }

                // Slideshow Progress Slider
                Components.StyledSlider {
                    id: slideshowProgressSlider
                    visible: root.isSlideshow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    from: 0
                    to: root.mediaModel ? Math.max(1, root.mediaModel.count - 1) : 0
                    value: root.tabData && root.tabData.currentIndex >= 0 ? root.tabData.currentIndex : 0
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    enabled: root.mediaModel && root.mediaModel.count > 0
                    bgColor: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor

                    ToolTip.visible: hovered || pressed
                    ToolTip.text: qsTr("Image ") + (Math.round(value) + 1) + " / " + (root.mediaModel ? root.mediaModel.count : 0)

                    onPressedChanged: {
                        if (!pressed && root.mediaModel && root.mediaModel.count > 0) {
                            jumpToSlideshowIndex(Math.round(value));
                        }
                    }
                }

                // Slideshow position label
                Label {
                    visible: root.isSlideshow
                    text: (root.tabData && root.tabData.currentIndex >= 0 ? (root.tabData.currentIndex + 1) : 0) + "/" + (root.mediaModel ? root.mediaModel.count : 0)
                    color: root.subtleTextColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignRight
                }

                // Video Play/Pause Button
                Components.IconButton {
                    id: dynamicPlayBtn
                    visible: !root.isSlideshow
                    checkable: true
                    checked: root.tabData ? root.tabData.isPlaying : false
                    iconText: checked ? "⏸" : "▶"
                    ToolTip.visible: hovered
                    ToolTip.text: checked ? qsTr("Pause Video") : qsTr("Play Video")
                    bgColor: root.panelColor
                    pressedColor: root.accentColor
                    txtColor: root.textColor
                    borderCol: root.borderColor
                    onClicked: toggleVideoPlayback()
                }

                // Video Stop Button
                Components.IconButton {
                    id: videoStopBtn
                    visible: !root.isSlideshow
                    iconText: "⏹"
                    iconSize: Components.Theme.iconSize
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Stop Video")
                    bgColor: root.panelColor
                    pressedColor: root.accentColor
                    txtColor: root.textColor
                    borderCol: root.borderColor
                    onClicked: stopVideo()
                }

                // Video Progress Slider
                Components.StyledSlider {
                    id: videoProgressSlider
                    visible: !root.isSlideshow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    from: 0
                    to: root.tabData && root.tabData.videoDuration > 0 ? root.tabData.videoDuration : 1000
                    enabled: root.tabData && root.tabData.currentPath !== ""
                    value: pressed ? value : (root.tabData ? root.tabData.videoPosition : 0)
                    bgColor: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor

                    ToolTip.visible: hovered || pressed
                    ToolTip.text: root.formatTime(value) + " / " + root.formatTime(root.tabData ? root.tabData.videoDuration : 0)

                    onPressedChanged: {
                        if (pressed) {
                            if (root.tabData) {
                                root.mediaTabsModel.setProperty(root.tabModelIndex, "isSeeking", true);
                            }
                        } else {
                            seekingClearTimer.start();
                        }
                    }

                    onMoved: seekVideo(Math.round(value))

                    Timer {
                        id: seekingClearTimer
                        interval: 200
                        onTriggered: {
                            if (root.tabData) {
                                root.mediaTabsModel.setProperty(root.tabModelIndex, "isSeeking", false);
                            }
                        }
                    }
                }

                // Video time label
                Label {
                    visible: !root.isSlideshow
                    text: root.formatTime(root.tabData ? root.tabData.videoPosition : 0) + "/" + root.formatTime(root.tabData ? root.tabData.videoDuration : 0)
                    color: root.subtleTextColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 80
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.preferredWidth: 8
                }

                // Add media buttons
                Components.StyledButton {
                    text: qsTr("Add Files")
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 44
                    bgColor: root.panelColor
                    pressedColor: root.accentColor
                    txtColor: root.textColor
                    borderCol: root.borderColor
                    onClicked: addFilesClicked()
                }

                Components.StyledButton {
                    text: qsTr("Add Folder")
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 44
                    bgColor: root.panelColor
                    pressedColor: root.accentColor
                    txtColor: root.textColor
                    borderCol: root.borderColor
                    onClicked: addFolderClicked()
                }
            }

            // Media list
            ListView {
                id: dynamicMediaList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.mediaModel
                currentIndex: root.tabData ? root.tabData.currentIndex : -1

                delegate: Components.MediaListItem {
                    width: dynamicMediaList.width
                    fileName: root.fileNameFromPath(model.path)
                    isSelected: dynamicMediaList.currentIndex === index
                    itemColor: root.listItemColor
                    highlightColor: root.listItemHighlight
                    txtColor: root.textColor
                    subtleTxtColor: root.subtleTextColor
                    borderCol: root.borderColor
                    onClicked: mediaItemClicked(index, model.path)
                    onDeleteClicked: root.mediaModel.remove(index)
                }

                ScrollBar.vertical: ScrollBar {}
            }
        }

        // Volume slider (video only)
        ColumnLayout {
            visible: !root.isSlideshow
            Layout.fillHeight: true
            Layout.preferredWidth: 60
            spacing: 8

            Label {
                text: qsTr("Volume")
                color: root.textColor
                font.pixelSize: Components.Theme.fontSize
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Components.StyledSlider {
                id: tabVolumeSlider
                orientation: Qt.Vertical
                from: 0.0
                to: 1.0
                value: root.tabData ? root.tabData.volume : 1.0
                Layout.fillHeight: true
                Layout.preferredWidth: 44
                Layout.alignment: Qt.AlignHCenter
                bgColor: root.panelColor
                accentCol: root.accentColor
                borderCol: root.borderColor

                ToolTip.visible: hovered || pressed
                ToolTip.text: qsTr("Volume: ") + Math.round(value * 100) + "%"

                onValueChanged: updateVolume(value)
            }

            Label {
                text: Math.round((root.tabData ? root.tabData.volume : 1.0) * 100) + "%"
                color: root.textColor
                font.pixelSize: Components.Theme.fontSize
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Brightness/Alpha slider
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 60
            spacing: 8

            Label {
                text: qsTr("Alpha")
                color: root.textColor
                font.pixelSize: Components.Theme.fontSize
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Components.StyledSlider {
                id: tabBrightnessSlider
                orientation: Qt.Vertical
                from: 0.0
                to: 1.0
                value: root.tabData ? root.tabData.brightness : 1.0
                Layout.fillHeight: true
                Layout.preferredWidth: 44
                Layout.alignment: Qt.AlignHCenter
                bgColor: root.panelColor
                accentCol: root.accentColor
                borderCol: root.borderColor

                ToolTip.visible: hovered || pressed
                ToolTip.text: (root.isSlideshow ? qsTr("Slideshow Alpha: ") : qsTr("Video Alpha: ")) + Math.round(value * 100) + "%"

                onValueChanged: updateBrightness(value)
            }

            Label {
                text: Math.round((root.tabData ? root.tabData.brightness : 1.0) * 100) + "%"
                color: root.textColor
                font.pixelSize: Components.Theme.fontSize
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Signal handlers - to be implemented by integrating code in parent
    signal addFilesRequested(string mediaType)
    signal addFolderRequested(string mediaType)

    // Helper functions
    function startSlideshow() {
        if (root.mediaModel && root.mediaModel.count > 0) {
            var isResumingSameTab = (root.activeSlideshowTabId === root.tabData.tabId);

            root.slideshowStarted(root.tabData.tabId, root.tabModelIndex);

            if (!isResumingSameTab && root.slideshow) {
                root.slideshow.setImageList(root.mediaModel);
                var startIndex = root.tabData.currentIndex >= 0 ? root.tabData.currentIndex : 0;
                if (startIndex > 0) {
                    root.slideshow.setCurrentIndex(startIndex);
                }
            }
            if (root.slideshow) {
                root.slideshow.start(root.slideshowDelaySeconds * 1000);
            }
            root.statusChanged(isResumingSameTab ? "Slideshow resumed" : "Slideshow started (" + root.slideshowDelaySeconds + " s per image)");
        }
    }

    function pauseSlideshow() {
        if (root.slideshow) {
            root.slideshow.pause();
        }
        root.slideshowPaused();
        root.statusChanged("Slideshow paused");
    }

    function stopSlideshow() {
        if (root.slideshow) {
            root.slideshow.reset();
        }
        slideshowPlayPauseBtn.checked = false;
        root.slideshowStopped();

        root.mediaTabsModel.setProperty(root.tabModelIndex, "currentPath", "");
        root.mediaTabsModel.setProperty(root.tabModelIndex, "currentIndex", -1);

        if (root.outputWindow) {
            root.outputWindow.stopMediaLayer(root.tabData.tabId);
        }
        root.statusChanged("Slideshow stopped");
    }

    function jumpToSlideshowIndex(targetIndex) {
        if (targetIndex >= 0 && targetIndex < root.mediaModel.count) {
            var item = root.mediaModel.get(targetIndex);
            root.mediaTabsModel.setProperty(root.tabModelIndex, "currentPath", item.path);
            root.mediaTabsModel.setProperty(root.tabModelIndex, "currentIndex", targetIndex);

            if (root.activeSlideshowTabId === root.tabData.tabId && root.slideshow) {
                root.slideshow.setCurrentIndex(targetIndex);
            }

            if (root.outputWindow) {
                var zOrder = root.tabData.zOrder !== undefined ? root.tabData.zOrder : root.tabModelIndex;
                root.outputWindow.setImageLayer(root.tabData.tabId, item.path, root.tabData.brightness, zOrder);
            }
            root.statusChanged(qsTr("Jumped to image ") + (targetIndex + 1));
        }
    }

    function toggleVideoPlayback() {
        var wasPlaying = root.tabData.isPlaying;

        if (!wasPlaying) {
            var row = root.tabData.currentIndex >= 0 ? root.tabData.currentIndex : dynamicMediaList.currentIndex;
            if (row < 0 && root.mediaModel && root.mediaModel.count > 0) {
                row = 0;
            }

            if (row < 0 || !root.mediaModel || root.mediaModel.count === 0) {
                root.statusChanged("No videos in list");
                dynamicPlayBtn.checked = false;
                return;
            }

            var item = root.mediaModel.get(row);
            var zOrder = root.tabData.zOrder !== undefined ? root.tabData.zOrder : root.tabModelIndex;

            root.mediaTabsModel.setProperty(root.tabModelIndex, "currentPath", item.path);
            root.mediaTabsModel.setProperty(root.tabModelIndex, "isPlaying", true);
            root.mediaTabsModel.setProperty(root.tabModelIndex, "currentIndex", row);

            if (root.outputWindow) {
                root.outputWindow.setVideoLayer(root.tabData.tabId, item.path, root.tabData.brightness, true, zOrder);
            }
            root.statusChanged("Playing video: " + item.path);
        } else {
            var pauseZOrder = root.tabData.zOrder !== undefined ? root.tabData.zOrder : root.tabModelIndex;
            root.mediaTabsModel.setProperty(root.tabModelIndex, "isPlaying", false);
            if (root.outputWindow) {
                root.outputWindow.setVideoLayer(root.tabData.tabId, root.tabData.currentPath, root.tabData.brightness, false, pauseZOrder);
            }
            root.statusChanged("Video paused");
        }
    }

    function stopVideo() {
        dynamicPlayBtn.checked = false;
        root.mediaTabsModel.setProperty(root.tabModelIndex, "currentPath", "");
        root.mediaTabsModel.setProperty(root.tabModelIndex, "isPlaying", false);
        root.mediaTabsModel.setProperty(root.tabModelIndex, "currentIndex", -1);

        if (root.outputWindow) {
            root.outputWindow.stopMediaLayer(root.tabData.tabId);
        }
        root.statusChanged("Video stopped");
    }

    function seekVideo(position) {
        if (root.tabData) {
            root.mediaTabsModel.setProperty(root.tabModelIndex, "videoPosition", position);
            root.mediaTabsModel.setProperty(root.tabModelIndex, "seekPosition", position);

            if (root.outputWindow) {
                root.outputWindow.seekVideoLayer(root.tabData.tabId, position);
            }
        }
    }

    function mediaItemClicked(index, path) {
        root.mediaTabsModel.setProperty(root.tabModelIndex, "currentIndex", index);

        if (root.isSlideshow) {
            root.mediaTabsModel.setProperty(root.tabModelIndex, "currentPath", path);
            if (root.activeSlideshowTabId === root.tabData.tabId && root.slideshow) {
                root.slideshow.setCurrentIndex(index);
            }
            if (root.outputWindow) {
                var zOrder = root.tabData.zOrder !== undefined ? root.tabData.zOrder : root.tabModelIndex;
                root.outputWindow.setImageLayer(root.tabData.tabId, path, root.tabData.brightness, zOrder);
            }
        } else {
            if (root.tabData.isPlaying) {
                root.mediaTabsModel.setProperty(root.tabModelIndex, "currentPath", path);
                root.mediaTabsModel.setProperty(root.tabModelIndex, "videoPosition", 0);
                if (root.outputWindow) {
                    var videoZOrder = root.tabData.zOrder !== undefined ? root.tabData.zOrder : root.tabModelIndex;
                    root.outputWindow.setVideoLayer(root.tabData.tabId, path, root.tabData.brightness, true, videoZOrder);
                }
            }
        }
    }

    function updateVolume(value) {
        if (root.tabData) {
            root.mediaTabsModel.setProperty(root.tabModelIndex, "volume", value);
            if (root.outputWindow) {
                root.outputWindow.setVideoLayerVolume(root.tabData.tabId, value);
            }
        }
    }

    function updateBrightness(value) {
        if (root.tabData) {
            root.mediaTabsModel.setProperty(root.tabModelIndex, "brightness", value);

            if (root.outputWindow) {
                root.outputWindow.setMediaLayerBrightness(root.tabData.tabId, value);

                var zOrder = root.tabData.zOrder !== undefined ? root.tabData.zOrder : root.tabModelIndex;
                var currentPath = root.tabData.currentPath;

                if (root.isSlideshow && root.activeSlideshowTabId === root.tabData.tabId && root.slideshow && root.slideshow.currentImagePath) {
                    currentPath = root.slideshow.currentImagePath;
                }

                if (currentPath) {
                    if (root.isSlideshow) {
                        root.outputWindow.setImageLayer(root.tabData.tabId, currentPath, value, zOrder);
                    } else {
                        root.outputWindow.setVideoLayer(root.tabData.tabId, currentPath, value, root.tabData.isPlaying, zOrder);
                    }
                }
            }
        }
    }

    function addFilesClicked() {
        root.addFilesRequested(root.isSlideshow ? "image" : "video");
    }

    function addFolderClicked() {
        root.addFolderRequested(root.isSlideshow ? "image" : "video");
    }
}
