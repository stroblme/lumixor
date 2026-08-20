import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

// Transport controls for a video tab: play/pause, stop, and the seek slider.
// All state lives on the MediaTabContent instance passed in as `tab`; this row only
// renders it and drives the shared controllers.
RowLayout {
    id: transport

    property Item tab: null

    spacing: 8
    Layout.fillWidth: true

            // Video controls - Play/Pause Icon Button
            Components.IconButton {
                id: dynamicPlayBtn
                checked: tab.tabData ? tab.tabData.isPlaying : false
                iconText: checked ? "⏸" : "▶"
                ToolTip.visible: hovered
                ToolTip.text: checked ? qsTr("Pause Video") : qsTr("Play Video")
                onClicked: {
                    var wasPlaying = tab.tabData.isPlaying;

                    if (!wasPlaying) {
                        // Start playing
                        // Use model's currentIndex if available, otherwise use list selection or default to 0
                        var row = tab.tabData.currentIndex;

                        // If still no selection, auto-select the first one
                        if (row < 0 && tab.currentMediaModel && tab.currentMediaModel.count > 0) {
                            row = 0;
                        }

                        if (row < 0 || !tab.currentMediaModel || tab.currentMediaModel.count === 0) {
                            tab.statusMessage("No videos in list");
                            return;
                        }

                        var item = tab.currentMediaModel.get(row);
                        var tabId = tab.tabData.tabId;
                        var brightness = tab.tabData.brightness;
                        var zOrder = tab.tabData.zOrder !== undefined ? tab.tabData.zOrder : tab.tabModelIndex;

                        // Update the model for preview
                        tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentPath", item.path);
                        tab.mediaTabsModel.setProperty(tab.tabModelIndex, "isPlaying", true);
                        tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentIndex", row);

                        // Also update OutputWindow
                        if (outputWindow) {
                            outputWindow.setVideoLayer(tabId, item.path, brightness, true, zOrder);
                        }

                        tab.statusMessage("Playing video: " + item.path);
                    } else {
                        // Pausing
                        var pauseZOrder = tab.tabData.zOrder !== undefined ? tab.tabData.zOrder : tab.tabModelIndex;
                        tab.mediaTabsModel.setProperty(tab.tabModelIndex, "isPlaying", false);
                        if (outputWindow) {
                            outputWindow.setVideoLayer(tab.tabData.tabId, tab.tabData.currentPath, tab.tabData.brightness, false, pauseZOrder);
                        }
                        tab.statusMessage("Video paused");
                    }
                }
            }

            // Video Stop Icon Button
            Components.IconButton {
                id: videoStopBtn
                iconText: "⏹"
                iconSize: 20
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Stop Video")
                onClicked: {
                    // Stop video playback (the play button follows isPlaying below)
                    // Clear the current path and state for preview
                    tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentPath", "");
                    tab.mediaTabsModel.setProperty(tab.tabModelIndex, "isPlaying", false);
                    tab.mediaTabsModel.setProperty(tab.tabModelIndex, "currentIndex", -1);

                    // Also stop in OutputWindow
                    if (outputWindow) {
                        outputWindow.stopMediaLayer(tab.tabData.tabId);
                    }

                    tab.statusMessage("Video stopped");
                }
            }

            // Video Progress Slider
            Components.StyledSlider {
                id: videoProgressSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                from: 0
                to: tab.tabData && tab.tabData.videoDuration > 0 ? tab.tabData.videoDuration : 1000
                enabled: tab.tabData ? tab.tabData.currentPath !== "" : false

                // Follow the model except while the user is dragging the handle.
                Binding {
                    target: videoProgressSlider
                    property: "value"
                    value: tab.tabData ? tab.tabData.videoPosition : 0
                    when: !videoProgressSlider.pressed
                }

                ToolTip.visible: hovered || pressed
                ToolTip.text: Components.Utils.formatTime(value) + " / " + Components.Utils.formatTime(tab.tabData ? tab.tabData.videoDuration : 0)

                onPressedChanged: {
                    if (pressed) {
                        // Mark that we're seeking so MediaPlayer stops updating position
                        if (tab.tabData) {
                            tab.mediaTabsModel.setProperty(tab.tabModelIndex, "isSeeking", true);
                        }
                    } else {
                        // When released, clear seeking flag after a short delay
                        if (tab.tabData) {
                            seekingClearTimer.start();
                        }
                    }
                }

                onMoved: {
                    // Called when user moves the slider (drag or click)
                    if (tab.tabData) {
                        var seekPos = Math.round(value);

                        // Update the model position immediately
                        tab.mediaTabsModel.setProperty(tab.tabModelIndex, "videoPosition", seekPos);

                        // Seek in preview
                        tab.mediaTabsModel.setProperty(tab.tabModelIndex, "seekPosition", seekPos);

                        // Also seek in OutputWindow
                        if (outputWindow) {
                            outputWindow.seekVideoLayer(tab.tabData.tabId, seekPos);
                        }
                    }
                }

                Timer {
                    id: seekingClearTimer
                    interval: 200
                    onTriggered: {
                        if (tab.tabData) {
                            tab.mediaTabsModel.setProperty(tab.tabModelIndex, "isSeeking", false);
                        }
                    }
                }
            }

            // Video time label
            Label {
                text: Components.Utils.formatTime(tab.tabData ? tab.tabData.videoPosition : 0) + "/" + Components.Utils.formatTime(tab.tabData ? tab.tabData.videoDuration : 0)
                color: Components.Theme.subtleTextColor
                font.pixelSize: Components.Theme.fontSize
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 80
                horizontalAlignment: Text.AlignRight
            }
}
