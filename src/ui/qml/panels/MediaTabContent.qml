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
    signal slideshowStarted(int tabId)
    signal slideshowStopped

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

                SlideshowTransport {
                    visible: isSlideshow
                    tab: tabContentItem
                }

                VideoTransport {
                    visible: !isSlideshow
                    tab: tabContentItem
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
                    fileName: Components.Utils.fileNameFromPath(model.path)
                    isSelected: ListView.isCurrentItem
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

                Components.LabeledVSlider {
                    visible: !isSlideshow
                    title: qsTr("Volume")
                    tooltipPrefix: qsTr("Volume: ")
                    value: tabData ? tabData.volume : 1.0

                    onSliderMoved: {
                        if (!tabData)
                            return;
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "volume", value);
                        if (outputWindow)
                            outputWindow.setVideoLayerVolume(tabData.tabId, value);

                        // Link to brightness
                        if (tabData.linkSliders && Math.abs(tabData.brightness - value) > 0.001) {
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "brightness", value);
                            if (outputWindow) {
                                outputWindow.setMediaLayerBrightness(tabData.tabId, value);
                                var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                if (tabData.currentPath)
                                    outputWindow.setVideoLayer(tabData.tabId, tabData.currentPath, value, tabData.isPlaying, zOrder);
                            }
                        }
                    }
                }

                Components.LabeledVSlider {
                    title: qsTr("Alpha")
                    tooltipPrefix: isSlideshow ? qsTr("Slideshow Alpha: ") : qsTr("Video Alpha: ")
                    value: tabData ? tabData.brightness : 1.0

                    onSliderMoved: {
                        if (!tabData)
                            return;

                        // Update brightness in model for preview
                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "brightness", value);

                        if (outputWindow) {
                            outputWindow.setMediaLayerBrightness(tabData.tabId, value);

                            var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                            var currentPath = tabData.currentPath;

                            // For slideshow, also check if this tab is the active slideshow
                            if (isSlideshow && activeSlideshowTabId === tabData.tabId && slideshow && slideshow.currentImagePath)
                                currentPath = slideshow.currentImagePath;

                            if (currentPath) {
                                if (isSlideshow)
                                    outputWindow.setImageLayer(tabData.tabId, currentPath, value, zOrder);
                                else
                                    outputWindow.setVideoLayer(tabData.tabId, currentPath, value, tabData.isPlaying, zOrder);
                            }
                        }

                        // If sliders are linked (video tabs only), sync the volume slider
                        if (!isSlideshow && tabData.linkSliders && Math.abs(tabData.volume - value) > 0.001) {
                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "volume", value);
                            if (outputWindow)
                                outputWindow.setVideoLayerVolume(tabData.tabId, value);
                        }
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
                color: linkToggleMouse.containsMouse ? Qt.lighter(Components.Theme.panelColor, 1.3) : Components.Theme.panelColor
                border.color: (tabData && tabData.linkSliders) ? Components.Theme.accentColor : Components.Theme.borderColor
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
                        color: Components.Theme.textColor
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
