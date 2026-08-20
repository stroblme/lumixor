import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

// Transport controls for a slideshow tab: play/pause, stop, and the image position slider.
// All state lives on the MediaTabContent instance passed in as `tab`; this row only
// renders it and drives the shared controllers.
RowLayout {
    id: transport

    property Item tab: null

    // Derived play state, also read by the tests to confirm the button follows the
    // controller instead of storing its own flag.
    readonly property bool slideshowPlayChecked: slideshowPlayPauseBtn.checked

    spacing: 8
    Layout.fillWidth: true

            // Slideshow controls - Play/Pause Icon Button
            Components.IconButton {
                id: slideshowPlayPauseBtn
                checked: tab.tabData ? (tab.activeSlideshowTabId === tab.tabData.tabId && slideshow.running) : false
                iconText: checked ? "⏸" : "▶"
                ToolTip.visible: hovered
                ToolTip.text: checked ? qsTr("Pause Slideshow") : qsTr("Start Slideshow")
                onClicked: {
                    if (!checked) {
                        if (playbackController.isPlaying()) {
                            playbackController.pause();
                        }
                        // Set slideshow to use this tab's media
                        if (tab.currentMediaModel && tab.currentMediaModel.count > 0) {
                            // Only set image list if this is a new slideshow (not resuming)
                            var isResumingSameTab = (tab.activeSlideshowTabId === tab.tabData.tabId);

                            // Track which tab is running the slideshow
                            tab.slideshowStarted(tab.tabData.tabId);

                            if (!isResumingSameTab) {
                                // New slideshow - set the image list
                                slideshow.setImageList(tab.currentMediaModel);

                                // If an image is pre-selected, start from that image
                                var startIndex = tab.tabData.currentIndex >= 0 ? tab.tabData.currentIndex : 0;
                                if (startIndex > 0) {
                                    slideshow.setCurrentIndex(startIndex);
                                }
                            }
                            slideshow.start(tab.slideshowDelaySeconds * 1000);
                            tab.statusMessage(isResumingSameTab ? "Slideshow resumed" : "Slideshow started (" + tab.slideshowDelaySeconds + " s per image)");
                        }
                    } else {
                        slideshow.pause();
                        // Don't clear tab.activeSlideshowTabId on pause so we can resume
                        tab.statusMessage("Slideshow paused");
                    }
                }
            }

            // Slideshow Stop Icon Button
            Components.IconButton {
                id: slideshowStopBtn
                iconText: "⏹"
                iconSize: 20
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Stop Slideshow")
                onClicked: {
                    // Stop and reset the slideshow
                    slideshow.reset();
                    tab.slideshowStopped();

                    // Clear the current path for preview
                    tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentPath", "");
                    tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentIndex", -1);

                    // Also stop in OutputWindow
                    if (outputWindow) {
                        outputWindow.stopMediaLayer(tab.tabData.tabId);
                    }

                    tab.statusMessage("Slideshow stopped");
                }
            }

            Label {
                text: qsTr("Delay: ") + tab.slideshowDelaySeconds + qsTr(" s")
                color: Components.Theme.textColor
                font.pixelSize: Components.Theme.fontSize
                Layout.alignment: Qt.AlignVCenter
            }

            // Slideshow Progress Slider
            Components.StyledSlider {
                id: slideshowProgressSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                from: 0
                to: tab.currentMediaModel ? Math.max(1, tab.currentMediaModel.count - 1) : 0
                value: tab.tabData && tab.tabData.currentIndex >= 0 ? tab.tabData.currentIndex : 0
                stepSize: 1
                snapMode: Slider.SnapAlways
                enabled: tab.currentMediaModel ? tab.currentMediaModel.count > 0 : false

                ToolTip.visible: hovered || pressed
                ToolTip.text: qsTr("Image ") + (Math.round(value) + 1) + " / " + (tab.currentMediaModel ? tab.currentMediaModel.count : 0)

                onPressedChanged: {
                    if (!pressed && tab.currentMediaModel && tab.currentMediaModel.count > 0) {
                        var targetIndex = Math.round(value);
                        if (targetIndex >= 0 && targetIndex < tab.currentMediaModel.count) {
                            var item = tab.currentMediaModel.get(targetIndex);
                            // Update the model
                            tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentPath", item.path);
                            tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentIndex", targetIndex);

                            // Sync with SlideshowController if this tab is the active slideshow
                            if (tab.activeSlideshowTabId === tab.tabData.tabId && slideshow) {
                                slideshow.setCurrentIndex(targetIndex);
                            }

                            // Update OutputWindow
                            if (outputWindow) {
                                var zOrder = tab.tabData.zOrder !== undefined ? tab.tabData.zOrder : tab.tabModelIndex;
                                outputWindow.setImageLayer(tab.tabData.tabId, item.path, tab.tabData.brightness, zOrder);
                            }

                            tab.statusMessage(qsTr("Jumped to image ") + (targetIndex + 1));
                        }
                    }
                }
            }

            // Slideshow position label
            Label {
                text: (tab.tabData && tab.tabData.currentIndex >= 0 ? (tab.tabData.currentIndex + 1) : 0) + "/" + (tab.currentMediaModel ? tab.currentMediaModel.count : 0)
                color: Components.Theme.subtleTextColor
                font.pixelSize: Components.Theme.fontSize
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 50
                horizontalAlignment: Text.AlignRight
            }
}
