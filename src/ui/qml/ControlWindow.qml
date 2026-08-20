import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "components" as Components
import "panels"

Window {
    id: controlRoot
    objectName: "controlRoot"
    visible: true
    visibility: Window.Maximized
    onClosing: {
        if (outputWindow && outputWindow.close)
            outputWindow.close();
    }

    width: 860
    height: 560
    minimumWidth: 680
    minimumHeight: 420

    // Read-only views of PreferencesController. Defaults live in AppConfig only.
    readonly property int slideshowDelaySeconds: preferences.slideshowIntervalSeconds
    readonly property int transitionDurationMs: preferences.transitionDurationMs
    readonly property int outputScreenIndex: preferences.outputScreenIndex
    readonly property string prefAccentColor: preferences.accentColor
    readonly property bool loopSlideshows: preferences.loopSlideshows
    readonly property bool loopVideos: preferences.loopVideos
    readonly property bool autoPlayNextVideo: preferences.autoPlayNextVideo

    // Moving the output is a side effect of the setting changing, not of the panel
    // emitting, so it belongs with the value.
    onOutputScreenIndexChanged: {
        if (outputWindow)
            outputWindow.moveToScreen(outputScreenIndex);
    }

    property string statusText: ""

    // The palette lives in the Theme singleton; only the accent is user-configurable,
    // so it is the one value driven in from PreferencesController.
    Binding {
        target: Components.Theme
        property: "accentColor"
        value: controlRoot.prefAccentColor
    }

    // Dynamic media tabs model: each entry is { tabId, tabType ("slideshow" or "video"), tabName, mediaModel (ListModel), brightness }
    // Tab IDs start from 0 and increment globally to avoid conflicts
    property int nextTabId: 0
    property var mediaTabs: ListModel {
        id: mediaTabsModel
    }

    // Counters for display names (Slideshow 1, Video 1, etc.)
    property int nextSlideshowNumber: 1
    property int nextVideoNumber: 1

    // Track which slideshow tab is currently running (tabId, or -1 if none)
    property int activeSlideshowTabId: -1

    // Row of a tab by its stable id. Row numbers shift when tabs are reordered or
    // closed, so they must never be cached.
    function indexOfTab(tabId) {
        if (tabId < 0)
            return -1;
        for (var i = 0; i < mediaTabsModel.count; ++i) {
            if (mediaTabsModel.get(i).tabId === tabId)
                return i;
        }
        return -1;
    }

    // Helper to get the currently active media tab (or null if on Preferences/Home)
    function getActiveMediaTab() {
        var idx = mainTabs.currentIndex - 2; // 0=Preferences, 1=Home, 2+=media tabs
        if (idx >= 0 && idx < mediaTabsModel.count) {
            return mediaTabsModel.get(idx);
        }
        return null;
    }

    // Add a new media tab
    function addMediaTab(tabType, tabName) {
        var newModel = Qt.createQmlObject('import QtQuick 2.12; ListModel {}', controlRoot);
        var name;
        var tabId = nextTabId;
        nextTabId++;

        if (tabType === "slideshow") {
            name = tabName || qsTr("Slideshow ") + nextSlideshowNumber;
            nextSlideshowNumber++;
        } else {
            name = tabName || qsTr("Video ") + nextVideoNumber;
            nextVideoNumber++;
        }
        // zOrder is the position in the tab list (0 = leftmost, higher = more to the right = on top)
        var zOrder = mediaTabsModel.count;
        mediaTabsModel.append({
            "tabId": tabId,
            "tabType": tabType,
            "tabName": name,
            "mediaModel": newModel,
            "brightness": 1.0,
            "volume": 1.0  // Audio volume for video tabs (0.0 to 1.0)
            ,
            "linkSliders": true  // Link volume and alpha sliders together
            ,
            "currentPath": "",
            "isPlaying": false,
            "currentIndex": -1,
            "zOrder": zOrder,
            "videoPosition": 0,
            "videoDuration": 0,
            "seekPosition": -1  // Set to >= 0 to request a seek
            ,
            "isSeeking": false   // True while user is dragging the seek slider
        });
        // Switch to the new tab
        mainTabs.currentIndex = mediaTabsModel.count + 1; // +2 for Preferences/Home, -1 for 0-based
        return mediaTabsModel.count - 1;
    }

    // Create a tab per media kind and fill it. Used by both import paths.
    function importIntoTabs(images, videos) {
        if (images.length > 0) {
            var slideshowTab = mediaTabsModel.get(addMediaTab("slideshow"));
            for (var i = 0; i < images.length; ++i)
                slideshowTab.mediaModel.append({"path": images[i]});
        }
        if (videos.length > 0) {
            var videoTab = mediaTabsModel.get(addMediaTab("video"));
            for (var j = 0; j < videos.length; ++j)
                videoTab.mediaModel.append({"path": videos[j]});
        }
    }

    // Move a media tab from one position to another
    function moveMediaTab(fromIndex, toIndex) {
        if (fromIndex === toIndex)
            return;
        if (fromIndex < 0 || fromIndex >= mediaTabsModel.count)
            return;
        if (toIndex < 0 || toIndex >= mediaTabsModel.count)
            return;

        mediaTabsModel.move(fromIndex, toIndex, 1);

        // Update zOrder for all tabs based on their new positions
        for (var i = 0; i < mediaTabsModel.count; i++) {
            mediaTabsModel.setProperty(i, "zOrder", i);
        }

        // Update OutputWindow's z-order for all layers immediately
        if (outputWindow) {
            for (var j = 0; j < mediaTabsModel.count; j++) {
                var tab = mediaTabsModel.get(j);
                if (tab.currentPath && tab.currentPath !== "") {
                    outputWindow.setMediaLayerZOrder(tab.tabId, j);
                }
            }
        }
    }

    // Remove a media tab by index
    function removeMediaTab(tabIndex) {
        if (tabIndex >= 0 && tabIndex < mediaTabsModel.count) {
            var tab = mediaTabsModel.get(tabIndex);
            var tabId = tab.tabId;
            var tabType = tab.tabType;

            // Stop playback and remove from OutputWindow
            if (outputWindow) {
                outputWindow.removeMediaLayer(tabId);
            }

            // If this was an active slideshow, stop the slideshow controller
            if (tabType === "slideshow" && activeSlideshowTabId === tabId) {
                slideshow.stop();
                activeSlideshowTabId = -1;
            }

            // Clear the media model
            if (tab.mediaModel) {
                tab.mediaModel.clear();
            }
            // Remove from shared model - OutputWindow will react automatically
            mediaTabsModel.remove(tabIndex);
            // Switch to Home tab if we closed the current tab
            if (mainTabs.currentIndex > mediaTabsModel.count + 1) {
                mainTabs.currentIndex = 1;
            }
        }
    }

    color: Components.Theme.backgroundColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Left side: tabs and their content, resizable via splitter
            ColumnLayout {
                id: leftSide
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: Math.min(320, controlRoot.width * 0.35)

                Rectangle {
                    id: mainPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    radius: Components.Theme.borderRadius
                    color: Components.Theme.panelColor
                    border.color: Components.Theme.borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Components.Theme.tabButtonHeight
                            Layout.topMargin: 4
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            spacing: 4

                            // Wrapper to contain TabBar and allow it to be clipped
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Components.Theme.tabButtonHeight
                                clip: true

                                TabBar {
                                    id: mainTabs
                                    width: parent.width
                                    height: parent.height
                                    currentIndex: 1 // Default to Home tab

                                    // Remove white background from TabBar
                                    background: Rectangle {
                                        color: "transparent"
                                    }

                                    // Fixed tabs - Preferences
                                    Components.StyledTabButton {
                                        id: preferencesTab
                                        text: qsTr("Preferences")
                                    }

                                    // Fixed tabs - Home (hidden when media tabs exist)
                                    Components.StyledTabButton {
                                        id: homeTab
                                        text: qsTr("Home")
                                        visible: mediaTabsModel.count === 0
                                        width: visible ? implicitWidth : 0
                                    }

                                    // Dynamic media tabs with drag-and-drop support
                                    Repeater {
                                        id: mediaTabsRepeater
                                        model: mediaTabsModel

                                        Components.DraggableTabButton {
                                            tabIndex: index
                                            tabName: model.tabName
                                            tabCount: mediaTabsModel.count
                                            siblings: mediaTabsRepeater

                                            // +2 for the Preferences and Home tabs, which
                                            // stay in the TabBar even when Home is hidden.
                                            onActivated: mainTabs.currentIndex = index + 2
                                            onCloseRequested: removeMediaTab(index)
                                            onMoveRequested: moveMediaTab(fromIndex, toIndex)
                                        }
                                    }
                                } // end TabBar
                            } // end Item wrapper for TabBar

                            // Add tab button (+) - outside TabBar for proper rendering
                            Components.IconButton {
                                id: addTabButton
                                width: 40
                                height: Components.Theme.tabButtonHeight
                                Layout.preferredWidth: 40
                                Layout.minimumWidth: 40
                                Layout.preferredHeight: Components.Theme.tabButtonHeight
                                iconText: "+"
                                iconSize: 18
                                hoverColor: Qt.lighter(Components.Theme.backgroundColor, 1.2)
                                onClicked: {
                                    addTabMenu.popup();
                                }

                                Menu {
                                    id: addTabMenu

                                    background: Rectangle {
                                        implicitWidth: 180
                                        color: Components.Theme.panelColor
                                        border.color: Components.Theme.borderColor
                                        radius: Components.Theme.borderRadius
                                    }

                                    Components.StyledMenuItem {
                                        text: qsTr("New Slideshow Tab")
                                        onTriggered: addMediaTab("slideshow")
                                    }
                                    Components.StyledMenuItem {
                                        text: qsTr("New Video Tab")
                                        onTriggered: addMediaTab("video")
                                    }
                                }
                            }
                        } // end RowLayout for TabBar and add button

                        StackLayout {
                            id: tabStack
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 8
                            currentIndex: mainTabs.currentIndex

                            // Preferences tab content (embedded, no separate window)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                PreferencesPanel {
                                    anchors.fill: parent

                                }
                            }

                            // Home tab content (hidden when media tabs exist via index mapping)
                            HomePanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                onAddFilesClicked: {
                                    var files = controlBridge.openFileDialog();
                                    if (files.length === 0)
                                        return;

                                    var images = [];
                                    var videos = [];
                                    for (var i = 0; i < files.length; ++i) {
                                        var type = mediaManager.getMediaType(files[i]);
                                        if (type === "image")
                                            images.push(files[i]);
                                        else if (type === "video")
                                            videos.push(files[i]);
                                    }

                                    importIntoTabs(images, videos);
                                    statusText = qsTr("Added %1 images and %2 videos").arg(images.length).arg(videos.length);
                                }

                                onAddFolderClicked: {
                                    var folder = controlBridge.openFolderDialog();
                                    if (folder === "")
                                        return;

                                    var images = mediaManager.getMediaPathsFromFolder(folder, "image");
                                    var videos = mediaManager.getMediaPathsFromFolder(folder, "video");

                                    importIntoTabs(images, videos);
                                    statusText = qsTr("Added %1 images and %2 videos from folder").arg(images.length).arg(videos.length);
                                }
                            }

                            // Dynamic media tab content
                            Repeater {
                                model: mediaTabsModel

                                MediaTabContent {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    tabModelIndex: index
                                    tabData: controlRoot.mediaTabs.get(index)
                                    mediaTabsModel: controlRoot.mediaTabs
                                    activeSlideshowTabId: controlRoot.activeSlideshowTabId
                                    slideshowDelaySeconds: controlRoot.slideshowDelaySeconds

                                    onStatusMessage: controlRoot.statusText = message
                                    onSlideshowStarted: controlRoot.activeSlideshowTabId = tabId
                                    onSlideshowStopped: controlRoot.activeSlideshowTabId = -1
                                }
                            }
                        }
                    }
                } // end ColumnLayout for mainPanel content
            } // end Rectangle (mainPanel)

            // Center panel: only the splitter
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                spacing: 8

                Components.VerticalSplitter {
                    reference: controlRoot.contentItem
                    panelWidth: controlRoot.rightSideWidth
                    maximumWidth: controlRoot.width / 2
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Layout.leftMargin: 3
                    Layout.rightMargin: 3

                    onWidthDragged: controlRoot.rightSideWidth = newWidth
                }
            }

            // Right side: embedded output preview with controls underneath
            ColumnLayout {
                id: rightSide
                Layout.fillHeight: true
                Layout.preferredWidth: controlRoot.rightSideWidth
                Layout.minimumWidth: 120
                Layout.maximumWidth: controlRoot.width / 2
                spacing: 8

                // Preview panel
                Rectangle {
                    id: previewPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 150
                    radius: Components.Theme.borderRadius
                    color: Components.Theme.panelColor
                    border.color: Components.Theme.borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Label {
                            text: qsTr("Output Preview")
                            color: Components.Theme.textColor
                            font.bold: true
                            font.pixelSize: Components.Theme.fontSize
                        }

                        // Container that maintains the output window's aspect ratio
                        PreviewPanel {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            mediaTabsModel: controlRoot.mediaTabs
                            autoPlayNextVideo: controlRoot.autoPlayNextVideo
                            loopVideos: controlRoot.loopVideos
                        }
                    }
                }

                SpectrometerPanel {
                    Layout.fillWidth: true
                    implicitHeight: 100
                }

                BlackoutPanel {
                    Layout.fillWidth: true
                    implicitHeight: 80
                }
            }
        }

        // Bottom status bar
        Components.Panel {
            Layout.fillWidth: true
            implicitHeight: 40

            Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                text: statusText
                color: Components.Theme.subtleTextColor
                font.pixelSize: Components.Theme.fontSize
                elide: Label.ElideRight
            }
        }
    }

    // Sync loop settings to SlideshowController
    onLoopSlideshowsChanged: {
        if (slideshow) {
            slideshow.loopEnabled = loopSlideshows;
        }
    }

    Component.onCompleted: {

        // Sync loop setting to slideshow controller
        if (slideshow) {
            slideshow.loopEnabled = loopSlideshows;
        }
    }

    Connections {
        target: slideshow
        function onCurrentImagePathChanged() {
            if (!slideshow.currentImagePath)
                return;
            var iPath = slideshow.currentImagePath;

            // Update the active slideshow tab's currentPath and sync to OutputWindow
            var tabIndex = indexOfTab(activeSlideshowTabId);
            if (tabIndex >= 0) {
                var tab = mediaTabsModel.get(tabIndex);

                // Update the model for preview
                mediaTabsModel.setProperty(tabIndex, "currentPath", iPath);

                // Find the index in the tab's media list
                var mediaModel = tab.mediaModel;
                if (mediaModel) {
                    for (var j = 0; j < mediaModel.count; ++j) {
                        if (mediaModel.get(j).path === iPath) {
                            mediaTabsModel.setProperty(tabIndex, "currentIndex", j);
                            break;
                        }
                    }
                }

                // Also update OutputWindow
                if (outputWindow) {
                    var zOrder = tab.zOrder !== undefined ? tab.zOrder : tabIndex;
                    var brightness = tab.brightness !== undefined ? tab.brightness : 1.0;
                    outputWindow.setImageLayer(activeSlideshowTabId, iPath, brightness, zOrder);
                }
            }
        }
        function onSlideshowEnded() {
            statusText = qsTr("Slideshow ended");
            // The slideshow has already stopped in the controller
            activeSlideshowTabId = -1;
        }
    }

    // Width of the right-side preview + controls column, adjustable via splitter
    property real rightSideWidth: Math.min(260, width / 2)
}
