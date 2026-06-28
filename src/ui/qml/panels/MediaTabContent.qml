import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

// Per-tab media controls (slideshow or video): playback buttons, progress and
// alpha/volume sliders, the media list, and the link toggle. Extracted from
// ControlWindow. Backend objects (outputWindow, slideshow, playbackController,
// mediaManager, controlBridge) are global QML context properties.
Item {
    id: tabContentItem

    // Theme colors - passed from parent
    property color panelColor: "#1E1E1E"
    property color accentColor: "#78909C"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"
    property color listItemColor: "#232323"
    property color listItemHighlight: "#29434E"

    // Tab data - passed from parent
    property int tabModelIndex: -1
    property var tabData: null
    property var mediaTabsModel: null
    property bool isSlideshow: tabData ? tabData.tabType === "slideshow" : false
    property var currentMediaModel: tabData ? tabData.mediaModel : null

    // Active-slideshow id mirrored from ControlWindow (read-only here)
    property int activeSlideshowTabId: -1
    property int slideshowDelaySeconds: 5

    // Signals back to ControlWindow
    signal statusMessage(string message)
    signal slideshowStarted(int tabId, int tabIndex)
    signal slideshowStopped

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

                // Slideshow controls - Play/Pause Icon Button
                Components.IconButton {
                    id: slideshowPlayPauseBtn
                    visible: isSlideshow
                    checkable: true
                    iconText: checked ? "⏸" : "▶"
                    bgColor: panelColor
                    pressedColor: accentColor
                    txtColor: textColor
                    borderCol: borderColor
                    ToolTip.visible: hovered
                    ToolTip.text: checked ? qsTr("Pause Slideshow") : qsTr("Start Slideshow")
                    onCheckedChanged: {
                        if (checked) {
                            if (playbackController.isPlaying()) {
                                playbackController.pause();
                            }
                            // Set slideshow to use this tab's media
                            if (currentMediaModel && currentMediaModel.count > 0) {
                                // Only set image list if this is a new slideshow (not resuming)
                                var isResumingSameTab = (activeSlideshowTabId === tabData.tabId);

                                // Track which tab is running the slideshow
                                tabContentItem.slideshowStarted(tabData.tabId, tabContentItem.tabModelIndex);

                                if (!isResumingSameTab) {
                                    // New slideshow - set the image list
                                    slideshow.setImageList(currentMediaModel);

                                    // If an image is pre-selected, start from that image
                                    var startIndex = tabData.currentIndex >= 0 ? tabData.currentIndex : 0;
                                    if (startIndex > 0) {
                                        slideshow.setCurrentIndex(startIndex);
                                    }
                                }
                                slideshow.start(slideshowDelaySeconds * 1000);
                                tabContentItem.statusMessage(isResumingSameTab ? "Slideshow resumed" : "Slideshow started (" + slideshowDelaySeconds + " s per image)");
                            }
                        } else {
                            slideshow.pause();
                            // Don't clear activeSlideshowTabId on pause so we can resume
                            tabContentItem.statusMessage("Slideshow paused");
                        }
                    }
                }

                // Slideshow Stop Icon Button
                Components.IconButton {
                    id: slideshowStopBtn
                    visible: isSlideshow
                    iconText: "⏹"
                    iconSize: 20
                    bgColor: panelColor
                    pressedColor: accentColor
                    txtColor: textColor
                    borderCol: borderColor
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Stop Slideshow")
                    onClicked: {
                        // Stop and reset the slideshow
                        slideshow.reset();
                        slideshowPlayPauseBtn.checked = false;
                        tabContentItem.slideshowStopped();

                        // Clear the current path for preview
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", "");
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", -1);

                        // Also stop in OutputWindow
                        if (outputWindow) {
                            outputWindow.stopMediaLayer(tabData.tabId);
                        }

                        // Clear list selection
                        dynamicMediaList.currentIndex = -1;
                        tabContentItem.statusMessage("Slideshow stopped");
                    }
                }

                Label {
                    visible: isSlideshow
                    text: qsTr("Delay: ") + slideshowDelaySeconds + qsTr(" s")
                    color: textColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.alignment: Qt.AlignVCenter
                }

                // Slideshow Progress Slider
                Components.StyledSlider {
                    id: slideshowProgressSlider
                    visible: isSlideshow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    from: 0
                    to: currentMediaModel ? Math.max(1, currentMediaModel.count - 1) : 0
                    value: tabData && tabData.currentIndex >= 0 ? tabData.currentIndex : 0
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    enabled: currentMediaModel && currentMediaModel.count > 0
                    bgColor: panelColor
                    accentCol: accentColor
                    borderCol: borderColor

                    ToolTip.visible: hovered || pressed
                    ToolTip.text: qsTr("Image ") + (Math.round(value) + 1) + " / " + (currentMediaModel ? currentMediaModel.count : 0)

                    onPressedChanged: {
                        if (!pressed && currentMediaModel && currentMediaModel.count > 0) {
                            var targetIndex = Math.round(value);
                            if (targetIndex >= 0 && targetIndex < currentMediaModel.count) {
                                var item = currentMediaModel.get(targetIndex);
                                // Update the model
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", item.path);
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", targetIndex);
                                dynamicMediaList.currentIndex = targetIndex;

                                // Sync with SlideshowController if this tab is the active slideshow
                                if (activeSlideshowTabId === tabData.tabId && slideshow) {
                                    slideshow.setCurrentIndex(targetIndex);
                                }

                                // Update OutputWindow
                                if (outputWindow) {
                                    var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                    outputWindow.setImageLayer(tabData.tabId, item.path, tabData.brightness, zOrder);
                                }

                                tabContentItem.statusMessage(qsTr("Jumped to image ") + (targetIndex + 1));
                            }
                        }
                    }
                }

                // Slideshow position label
                Label {
                    visible: isSlideshow
                    text: (tabData && tabData.currentIndex >= 0 ? (tabData.currentIndex + 1) : 0) + "/" + (currentMediaModel ? currentMediaModel.count : 0)
                    color: subtleTextColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignRight
                }

                // Video controls - Play/Pause Icon Button
                Components.IconButton {
                    id: dynamicPlayBtn
                    visible: !isSlideshow
                    checkable: true
                    checked: tabData ? tabData.isPlaying : false
                    iconText: checked ? "⏸" : "▶"
                    bgColor: panelColor
                    pressedColor: accentColor
                    txtColor: textColor
                    borderCol: borderColor
                    ToolTip.visible: hovered
                    ToolTip.text: checked ? qsTr("Pause Video") : qsTr("Play Video")
                    onClicked: {
                        var wasPlaying = tabData.isPlaying;

                        if (!wasPlaying) {
                            // Start playing
                            // Use model's currentIndex if available, otherwise use list selection or default to 0
                            var row = tabData.currentIndex >= 0 ? tabData.currentIndex : dynamicMediaList.currentIndex;

                            // If still no selection, auto-select the first one
                            if (row < 0 && currentMediaModel && currentMediaModel.count > 0) {
                                row = 0;
                            }

                            if (row < 0 || !currentMediaModel || currentMediaModel.count === 0) {
                                tabContentItem.statusMessage("No videos in list");
                                checked = false;
                                return;
                            }

                            var item = currentMediaModel.get(row);
                            var tabId = tabData.tabId;
                            var brightness = tabData.brightness;
                            var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;

                            // Update the model for preview
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", item.path);
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isPlaying", true);
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", row);

                            // Also update OutputWindow
                            if (outputWindow) {
                                outputWindow.setVideoLayer(tabId, item.path, brightness, true, zOrder);
                            }

                            tabContentItem.statusMessage("Playing video: " + item.path);
                        } else {
                            // Pausing
                            var pauseZOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isPlaying", false);
                            if (outputWindow) {
                                outputWindow.setVideoLayer(tabData.tabId, tabData.currentPath, tabData.brightness, false, pauseZOrder);
                            }
                            tabContentItem.statusMessage("Video paused");
                        }
                    }
                }

                // Video Stop Icon Button
                Components.IconButton {
                    id: videoStopBtn
                    visible: !isSlideshow
                    iconText: "⏹"
                    iconSize: 20
                    bgColor: panelColor
                    pressedColor: accentColor
                    txtColor: textColor
                    borderCol: borderColor
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Stop Video")
                    onClicked: {
                        // Stop video playback
                        dynamicPlayBtn.checked = false;

                        // Clear the current path and state for preview
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", "");
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isPlaying", false);
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", -1);

                        // Also stop in OutputWindow
                        if (outputWindow) {
                            outputWindow.stopMediaLayer(tabData.tabId);
                        }

                        // Clear list selection
                        dynamicMediaList.currentIndex = -1;
                        tabContentItem.statusMessage("Video stopped");
                    }
                }

                // Video Progress Slider
                Components.StyledSlider {
                    id: videoProgressSlider
                    visible: !isSlideshow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    from: 0
                    to: tabData && tabData.videoDuration > 0 ? tabData.videoDuration : 1000
                    enabled: tabData && tabData.currentPath !== ""
                    bgColor: panelColor
                    accentCol: accentColor
                    borderCol: borderColor

                    // Only update from model when not being dragged
                    value: pressed ? value : (tabData ? tabData.videoPosition : 0)

                    ToolTip.visible: hovered || pressed
                    ToolTip.text: formatTime(value) + " / " + formatTime(tabData ? tabData.videoDuration : 0)

                    function formatTime(ms) {
                        if (isNaN(ms) || ms < 0)
                            return "0:00";
                        var totalSec = Math.floor(ms / 1000);
                        var min = Math.floor(totalSec / 60);
                        var sec = totalSec % 60;
                        return min + ":" + (sec < 10 ? "0" : "") + sec;
                    }

                    onPressedChanged: {
                        if (pressed) {
                            // Mark that we're seeking so MediaPlayer stops updating position
                            if (tabData) {
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isSeeking", true);
                            }
                        } else {
                            // When released, clear seeking flag after a short delay
                            if (tabData) {
                                seekingClearTimer.start();
                            }
                        }
                    }

                    onMoved: {
                        // Called when user moves the slider (drag or click)
                        if (tabData) {
                            var seekPos = Math.round(value);
                            console.log("Video seek requested to: " + seekPos);

                            // Update the model position immediately
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "videoPosition", seekPos);

                            // Seek in preview
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "seekPosition", seekPos);

                            // Also seek in OutputWindow
                            if (outputWindow) {
                                outputWindow.seekVideoLayer(tabData.tabId, seekPos);
                            }
                        }
                    }

                    Timer {
                        id: seekingClearTimer
                        interval: 200
                        onTriggered: {
                            if (tabData) {
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isSeeking", false);
                            }
                        }
                    }
                }

                // Video time label
                Label {
                    visible: !isSlideshow
                    text: videoProgressSlider.formatTime(tabData ? tabData.videoPosition : 0) + "/" + videoProgressSlider.formatTime(tabData ? tabData.videoDuration : 0)
                    color: subtleTextColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 80
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 8
                }

                // Add media buttons
                Components.StyledButton {
                    text: qsTr("Add Files")
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 44
                    bgColor: panelColor
                    pressedColor: accentColor
                    txtColor: textColor
                    borderCol: borderColor
                    onClicked: {
                        var files = controlBridge.openFileDialog();
                        var expectedType = isSlideshow ? "image" : "video";
                        var addedCount = 0;
                        for (var i = 0; i < files.length; ++i) {
                            var type = mediaManager.getMediaType(files[i]);
                            if (type === expectedType) {
                                currentMediaModel.append({
                                    "path": files[i]
                                });
                                addedCount++;
                            }
                        }
                        if (addedCount > 0) {
                            tabContentItem.statusMessage(qsTr("Added %1 files").arg(addedCount));
                        }
                    }
                }

                Components.StyledButton {
                    text: qsTr("Add Folder")
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 44
                    bgColor: panelColor
                    pressedColor: accentColor
                    txtColor: textColor
                    borderCol: borderColor
                    onClicked: {
                        var folder = controlBridge.openFolderDialog();
                        if (folder !== "") {
                            var expectedType = isSlideshow ? "image" : "video";
                            var paths = mediaManager.getMediaPathsFromFolder(folder, expectedType);
                            for (var i = 0; i < paths.length; ++i) {
                                currentMediaModel.append({
                                    "path": paths[i]
                                });
                            }
                            tabContentItem.statusMessage(qsTr("Added %1 files from folder").arg(paths.length));
                        }
                    }
                }
            }

            // Media list
            ListView {
                id: dynamicMediaList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: currentMediaModel
                // Sync list selection with currently playing index
                currentIndex: tabData ? tabData.currentIndex : -1
                delegate: Components.MediaListItem {
                    width: dynamicMediaList.width
                    fileName: fileNameFromPath(model.path)
                    isSelected: ListView.isCurrentItem
                    itemColor: listItemColor
                    highlightColor: listItemHighlight
                    txtColor: textColor
                    subtleTxtColor: subtleTextColor
                    borderCol: borderColor
                    onClicked: {
                        // Update the model's currentIndex (list will sync automatically via binding)
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", index);

                        if (isSlideshow) {
                            // Update currentPath in model for preview
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", model.path);
                            // Sync with SlideshowController if this tab is the active slideshow
                            if (activeSlideshowTabId === tabData.tabId && slideshow) {
                                slideshow.setCurrentIndex(index);
                            }
                            // Also update OutputWindow
                            if (outputWindow) {
                                var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                outputWindow.setImageLayer(tabData.tabId, model.path, tabData.brightness, zOrder);
                            }
                        } else {
                            // For video: if currently playing, switch to the clicked video
                            if (tabData.isPlaying) {
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", model.path);
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "videoPosition", 0);
                                // Update OutputWindow
                                if (outputWindow) {
                                    var videoZOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                    outputWindow.setVideoLayer(tabData.tabId, model.path, tabData.brightness, true, videoZOrder);
                                }
                            }
                        }
                    }
                    onDeleteClicked: {
                        currentMediaModel.remove(index);
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }

        // Combined sliders + link button (video tabs only)
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: isSlideshow ? 50 : 100
            Layout.maximumWidth: isSlideshow ? 50 : 100
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Volume slider column
                ColumnLayout {
                    visible: !isSlideshow
                    Layout.fillHeight: true
                    Layout.preferredWidth: 45
                    spacing: 8

                    Label {
                        text: qsTr("Volume")
                        color: textColor
                        font.pixelSize: Components.Theme.fontSize
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Components.StyledSlider {
                        id: tabVolumeSlider
                        orientation: Qt.Vertical
                        from: 0.0
                        to: 1.0
                        value: tabData ? tabData.volume : 1.0
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 36
                        bgColor: panelColor
                        accentCol: accentColor
                        borderCol: borderColor
                        ToolTip.visible: hovered || pressed
                        ToolTip.text: qsTr("Volume: ") + Math.round(value * 100) + "%"

                        onValueChanged: {
                            if (!tabData)
                                return;
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "volume", value);
                            if (outputWindow) {
                                outputWindow.setVideoLayerVolume(tabData.tabId, value);
                            }
                            // Link to brightness
                            if (tabData.linkSliders && Math.abs(tabData.brightness - value) > 0.001) {
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "brightness", value);
                                if (outputWindow) {
                                    outputWindow.setMediaLayerBrightness(tabData.tabId, value);
                                    var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                    if (tabData.currentPath) {
                                        outputWindow.setVideoLayer(tabData.tabId, tabData.currentPath, value, tabData.isPlaying, zOrder);
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        text: Math.round((tabData ? tabData.volume : 1.0) * 100) + "%"
                        color: textColor
                        font.pixelSize: Components.Theme.fontSize
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Brightness/alpha slider column
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 45
                    spacing: 8

                    Label {
                        text: qsTr("Alpha")
                        color: textColor
                        font.pixelSize: Components.Theme.fontSize
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Components.StyledSlider {
                        id: tabBrightnessSlider
                        orientation: Qt.Vertical
                        from: 0.0
                        to: 1.0
                        value: tabData ? tabData.brightness : 1.0
                        Layout.fillHeight: true
                        Layout.preferredWidth: 36
                        Layout.alignment: Qt.AlignHCenter
                        bgColor: panelColor
                        accentCol: accentColor
                        borderCol: borderColor
                        ToolTip.visible: hovered || pressed
                        ToolTip.text: (isSlideshow ? qsTr("Slideshow Alpha: ") : qsTr("Video Alpha: ")) + Math.round(value * 100) + "%"

                        onValueChanged: {
                            if (tabData) {
                                // Update brightness in model for preview
                                mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "brightness", value);

                                // Also update OutputWindow
                                if (outputWindow) {
                                    outputWindow.setMediaLayerBrightness(tabData.tabId, value);

                                    var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                    var currentPath = tabData.currentPath;

                                    // For slideshow, also check if this tab is the active slideshow
                                    if (isSlideshow && activeSlideshowTabId === tabData.tabId && slideshow && slideshow.currentImagePath) {
                                        currentPath = slideshow.currentImagePath;
                                    }

                                    if (currentPath) {
                                        if (isSlideshow) {
                                            outputWindow.setImageLayer(tabData.tabId, currentPath, value, zOrder);
                                        } else {
                                            outputWindow.setVideoLayer(tabData.tabId, currentPath, value, tabData.isPlaying, zOrder);
                                        }
                                    }
                                }

                                // If sliders are linked (video tabs only), sync the volume slider
                                if (!isSlideshow && tabData.linkSliders && Math.abs(tabData.volume - value) > 0.001) {
                                    mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "volume", value);
                                    // Also update OutputWindow volume
                                    if (outputWindow) {
                                        outputWindow.setVideoLayerVolume(tabData.tabId, value);
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        text: Math.round((tabData ? tabData.brightness : 1.0) * 100) + "%"
                        color: textColor
                        font.pixelSize: Components.Theme.fontSize
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            } // end RowLayout with two sliders

            // Wide link/unlink button below both sliders
            Rectangle {
                id: linkToggleButton
                visible: !isSlideshow
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Components.Theme.borderRadius
                color: linkToggleMouse.containsMouse ? Qt.lighter(panelColor, 1.3) : panelColor
                border.color: (tabData && tabData.linkSliders) ? accentColor : borderColor
                border.width: (tabData && tabData.linkSliders) ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    // Center the label horizontally and vertically
                    Item {
                        Layout.fillWidth: true
                    }
                    Label {
                        text: (tabData && tabData.linkSliders) ? qsTr("Unlink") : qsTr("Link")
                        color: textColor
                        font.pixelSize: Components.Theme.fontSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: linkToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (tabData) {
                            var newValue = !tabData.linkSliders;
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "linkSliders", newValue);
                        }
                    }
                }

                ToolTip.visible: linkToggleMouse.containsMouse
                ToolTip.text: (tabData && tabData.linkSliders) ? qsTr("Sliders linked - click to unlink") : qsTr("Sliders unlinked - click to link")
            }
        }
    }
}
