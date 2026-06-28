import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtMultimedia 5.15
import Qt.labs.platform 1.1 as Platform
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

    // Default values, overridden from PreferencesController when available
    property int slideshowDelaySeconds: preferences ? preferences.slideshowIntervalSeconds : 5
    property int transitionDurationMs: preferences ? preferences.transitionDurationMs : 200
    property int outputScreenIndex: preferences ? preferences.outputScreenIndex : 1

    // UI customization from preferences
    property string prefAccentColor: preferences ? preferences.accentColor : "#78909C"

    // Loop/repeat settings for media tabs
    property bool loopSlideshows: true  // After last image, continue with first
    property bool loopVideos: true      // After last video, continue with first

    // Auto-play setting from preferences
    property bool autoPlayNextVideo: preferences ? preferences.autoPlayNextVideo : true

    property bool isBlack: false
    property bool wasVideoPlaying: false
    property bool wasSlideshowRunning: false
    property string statusText: ""

    // Per-media brightness controls (1.0 = full brightness, 0.0 = blackout)
    property real slideshowBrightness: 1.0
    property real videoBrightness: 1.0

    // Theme colors - dark theme with accent color override from preferences
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: prefAccentColor
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"
    property color listItemColor: "#232323"
    property color listItemHighlight: "#29434E"

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
    property int activeSlideshowTabIndex: -1

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
                activeSlideshowTabIndex = -1;
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

    // Add media to the currently active tab (or create a new tab if needed)
    function addMediaToActiveTab(paths, mediaType) {
        var activeTab = getActiveMediaTab();

        // Filter paths by type
        var filteredPaths = [];
        for (var i = 0; i < paths.length; i++) {
            var path = paths[i];
            var type = mediaManager.getMediaType(path);
            if (type === mediaType) {
                filteredPaths.push(path);
            }
        }

        if (filteredPaths.length === 0)
            return 0;

        // If no active media tab or wrong type, create a new one
        if (!activeTab || activeTab.tabType !== mediaType) {
            var tabIdx = addMediaTab(mediaType);
            activeTab = mediaTabsModel.get(tabIdx);
        }

        // Add paths to the tab's model
        for (var j = 0; j < filteredPaths.length; j++) {
            activeTab.mediaModel.append({
                "path": filteredPaths[j]
            });
        }

        return filteredPaths.length;
    }

    color: backgroundColor

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
                    color: panelColor
                    border.color: borderColor

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

                                        Components.StyledTabButton {
                                            id: mediaTabButton
                                            // Visual offset for drag animation
                                            transform: Translate {
                                                x: mediaTabButton.visualOffset
                                                Behavior on x {
                                                    NumberAnimation {
                                                        duration: 200
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }

                                            property int tabIndex: index
                                            property real visualOffset: 0
                                            property bool beingDragged: false

                                            // Calculate visual offset based on drag state
                                            states: [
                                                State {
                                                    name: "dragging"
                                                    when: mediaTabButton.beingDragged
                                                    PropertyChanges {
                                                        target: mediaTabButton
                                                        z: 100
                                                        opacity: 0.8
                                                    }
                                                }
                                            ]

                                            transitions: [
                                                Transition {
                                                    from: "*"
                                                    to: "dragging"
                                                    NumberAnimation {
                                                        properties: "opacity"
                                                        duration: 100
                                                    }
                                                },
                                                Transition {
                                                    from: "dragging"
                                                    to: "*"
                                                    NumberAnimation {
                                                        properties: "opacity"
                                                        duration: 100
                                                    }
                                                }
                                            ]

                                            contentItem: RowLayout {
                                                spacing: 4

                                                // Drag handle indicator
                                                Rectangle {
                                                    width: 8
                                                    height: 16
                                                    color: "transparent"
                                                    Column {
                                                        anchors.centerIn: parent
                                                        spacing: 2
                                                        Repeater {
                                                            model: 3
                                                            Rectangle {
                                                                width: 8
                                                                height: 2
                                                                radius: 1
                                                                color: subtleTextColor
                                                            }
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: model.tabName
                                                    font.pixelSize: Components.Theme.fontSize
                                                    color: mediaTabButton.checked ? textColor : subtleTextColor
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                // Close button
                                                Rectangle {
                                                    width: Components.Theme.iconSize
                                                    height: Components.Theme.iconSize
                                                    radius: Components.Theme.iconSize / 2
                                                    color: closeMouseArea.containsMouse ? Qt.lighter(panelColor, 1.5) : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "×"
                                                        color: subtleTextColor
                                                        font.pixelSize: Components.Theme.fontSize
                                                        font.bold: true
                                                    }
                                                    MouseArea {
                                                        id: closeMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: {
                                                            removeMediaTab(index);
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: dragArea
                                                anchors.fill: parent
                                                anchors.rightMargin: 20 // Leave space for close button

                                                property real dragStartGlobalX: 0
                                                property real lastGlobalX: 0
                                                property bool isDragging: false
                                                property int targetIndex: -1

                                                onPressed: {
                                                    // Store global position for accurate tracking
                                                    var globalPos = mapToGlobal(mouse.x, mouse.y);
                                                    dragStartGlobalX = globalPos.x;
                                                    lastGlobalX = globalPos.x;
                                                    isDragging = false;
                                                    targetIndex = mediaTabButton.tabIndex;
                                                }

                                                onPositionChanged: {
                                                    if (!pressed)
                                                        return;

                                                    var globalPos = mapToGlobal(mouse.x, mouse.y);
                                                    var totalDeltaX = globalPos.x - dragStartGlobalX;

                                                    // Start dragging after threshold
                                                    if (!isDragging && Math.abs(totalDeltaX) > 10) {
                                                        isDragging = true;
                                                        mediaTabButton.beingDragged = true;
                                                    }

                                                    if (isDragging) {
                                                        // Update visual position of dragged tab - follows mouse 1:1
                                                        mediaTabButton.visualOffset = totalDeltaX;

                                                        // Calculate target position
                                                        var tabWidth = mediaTabButton.width;
                                                        var currentIndex = mediaTabButton.tabIndex;
                                                        var draggedPositions = totalDeltaX / tabWidth;

                                                        // Determine new target index
                                                        var newTargetIndex = currentIndex + Math.round(draggedPositions);
                                                        newTargetIndex = Math.max(0, Math.min(mediaTabsModel.count - 1, newTargetIndex));

                                                        if (newTargetIndex !== targetIndex) {
                                                            targetIndex = newTargetIndex;
                                                            // Update visual offsets of other tabs
                                                            updateOtherTabOffsets(currentIndex, targetIndex, tabWidth);
                                                        }

                                                        lastGlobalX = globalPos.x;
                                                    }
                                                }

                                                onReleased: {
                                                    if (!isDragging) {
                                                        // It was a click, switch to this tab
                                                        mainTabs.currentIndex = index + 2; // +2 for Preferences and Home (Home hidden but still in TabBar)
                                                    } else {
                                                        // Perform the actual move
                                                        var currentIndex = mediaTabButton.tabIndex;
                                                        if (targetIndex !== currentIndex && targetIndex >= 0) {
                                                            moveMediaTab(currentIndex, targetIndex);
                                                        }

                                                        // Reset all visual offsets
                                                        resetAllTabOffsets();
                                                    }

                                                    mediaTabButton.beingDragged = false;
                                                    mediaTabButton.visualOffset = 0;
                                                    isDragging = false;
                                                    targetIndex = -1;
                                                }

                                                function updateOtherTabOffsets(draggedIndex, targetIdx, tabWidth) {
                                                    for (var i = 0; i < mediaTabsRepeater.count; i++) {
                                                        var tab = mediaTabsRepeater.itemAt(i);
                                                        if (tab && i !== draggedIndex) {
                                                            var offset = 0;
                                                            if (draggedIndex < targetIdx) {
                                                                // Dragging right: tabs between draggedIndex and targetIdx shift left
                                                                if (i > draggedIndex && i <= targetIdx) {
                                                                    offset = -tabWidth;
                                                                }
                                                            } else if (draggedIndex > targetIdx) {
                                                                // Dragging left: tabs between targetIdx and draggedIndex shift right
                                                                if (i >= targetIdx && i < draggedIndex) {
                                                                    offset = tabWidth;
                                                                }
                                                            }
                                                            tab.visualOffset = offset;
                                                        }
                                                    }
                                                }

                                                function resetAllTabOffsets() {
                                                    for (var i = 0; i < mediaTabsRepeater.count; i++) {
                                                        var tab = mediaTabsRepeater.itemAt(i);
                                                        if (tab) {
                                                            tab.visualOffset = 0;
                                                        }
                                                    }
                                                }
                                            }
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
                                bgColor: backgroundColor
                                hoverColor: Qt.lighter(backgroundColor, 1.2)
                                txtColor: subtleTextColor
                                borderCol: borderColor
                                onClicked: {
                                    addTabMenu.popup();
                                }

                                Menu {
                                    id: addTabMenu

                                    background: Rectangle {
                                        implicitWidth: 180
                                        color: panelColor
                                        border.color: borderColor
                                        radius: Components.Theme.borderRadius
                                    }

                                    Components.StyledMenuItem {
                                        text: qsTr("New Slideshow Tab")
                                        panelCol: panelColor
                                        txtColor: textColor
                                        onTriggered: addMediaTab("slideshow")
                                    }
                                    Components.StyledMenuItem {
                                        text: qsTr("New Video Tab")
                                        panelCol: panelColor
                                        txtColor: textColor
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
                                    backgroundColor: controlRoot.backgroundColor
                                    panelColor: controlRoot.panelColor
                                    accentColor: controlRoot.accentColor
                                    textColor: controlRoot.textColor
                                    subtleTextColor: controlRoot.subtleTextColor
                                    borderColor: controlRoot.borderColor

                                    slideshowDelaySeconds: controlRoot.slideshowDelaySeconds
                                    transitionDurationMs: controlRoot.transitionDurationMs
                                    outputScreenIndex: controlRoot.outputScreenIndex
                                    loopSlideshows: controlRoot.loopSlideshows
                                    loopVideos: controlRoot.loopVideos
                                    autoPlayNextVideo: controlRoot.autoPlayNextVideo
                                    screenCount: outputWindow ? outputWindow.screenCount : 1
                                    prefAccentColor: controlRoot.prefAccentColor

                                    onSlideshowDelayUpdated: {
                                        controlRoot.slideshowDelaySeconds = value;
                                        if (preferences)
                                            preferences.slideshowIntervalSeconds = value;
                                    }
                                    onTransitionDurationUpdated: {
                                        controlRoot.transitionDurationMs = value;
                                        if (preferences)
                                            preferences.transitionDurationMs = value;
                                    }
                                    onOutputScreenIndexUpdated: {
                                        controlRoot.outputScreenIndex = value;
                                        if (preferences)
                                            preferences.outputScreenIndex = value;
                                        if (outputWindow)
                                            outputWindow.moveToScreen(value);
                                    }
                                    onLoopSlideshowsUpdated: controlRoot.loopSlideshows = enabled
                                    onLoopVideosUpdated: controlRoot.loopVideos = enabled
                                    onAutoPlayNextVideoUpdated: {
                                        controlRoot.autoPlayNextVideo = enabled;
                                        if (preferences)
                                            preferences.autoPlayNextVideo = enabled;
                                    }
                                    onAccentColorUpdated: {
                                        controlRoot.prefAccentColor = color;
                                        if (preferences)
                                            preferences.accentColor = color;
                                    }
                                }
                            }

                            // Home tab content (hidden when media tabs exist via index mapping)
                            HomePanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                panelColor: controlRoot.panelColor
                                accentColor: controlRoot.accentColor
                                textColor: controlRoot.textColor
                                subtleTextColor: controlRoot.subtleTextColor
                                borderColor: controlRoot.borderColor

                                onAddFilesClicked: {
                                    var files = controlBridge.openFileDialog();
                                    if (files.length === 0)
                                        return;

                                    // Separate files by type and create appropriate tabs
                                    var images = [];
                                    var videos = [];
                                    for (var i = 0; i < files.length; ++i) {
                                        var type = mediaManager.getMediaType(files[i]);
                                        if (type === "image")
                                            images.push(files[i]);
                                        else if (type === "video")
                                            videos.push(files[i]);
                                    }

                                    if (images.length > 0) {
                                        var slideshowIdx = addMediaTab("slideshow");
                                        var slideshowTab = mediaTabsModel.get(slideshowIdx);
                                        for (var j = 0; j < images.length; ++j) {
                                            slideshowTab.mediaModel.append({
                                                "path": images[j]
                                            });
                                        }
                                    }

                                    if (videos.length > 0) {
                                        var videoIdx = addMediaTab("video");
                                        var videoTab = mediaTabsModel.get(videoIdx);
                                        for (var k = 0; k < videos.length; ++k) {
                                            videoTab.mediaModel.append({
                                                "path": videos[k]
                                            });
                                        }
                                    }

                                    statusText = qsTr("Added %1 images and %2 videos").arg(images.length).arg(videos.length);
                                }
                                onAddFolderClicked: {
                                    var folder = controlBridge.openFolderDialog();
                                    if (folder === "")
                                        return;

                                    var images = mediaManager.getMediaPathsFromFolder(folder, "image");
                                    var videos = mediaManager.getMediaPathsFromFolder(folder, "video");

                                    if (images.length > 0) {
                                        var slideshowIdx = addMediaTab("slideshow");
                                        var slideshowTab = mediaTabsModel.get(slideshowIdx);
                                        for (var i = 0; i < images.length; ++i) {
                                            slideshowTab.mediaModel.append({
                                                "path": images[i]
                                            });
                                        }
                                    }

                                    if (videos.length > 0) {
                                        var videoIdx = addMediaTab("video");
                                        var videoTab = mediaTabsModel.get(videoIdx);
                                        for (var j = 0; j < videos.length; ++j) {
                                            videoTab.mediaModel.append({
                                                "path": videos[j]
                                            });
                                        }
                                    }

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

                                    panelColor: controlRoot.panelColor
                                    accentColor: controlRoot.accentColor
                                    textColor: controlRoot.textColor
                                    subtleTextColor: controlRoot.subtleTextColor
                                    borderColor: controlRoot.borderColor
                                    listItemColor: controlRoot.listItemColor
                                    listItemHighlight: controlRoot.listItemHighlight

                                    onStatusMessage: controlRoot.statusText = message
                                    onSlideshowStarted: {
                                        controlRoot.activeSlideshowTabId = tabId;
                                        controlRoot.activeSlideshowTabIndex = tabIndex;
                                    }
                                    onSlideshowStopped: {
                                        controlRoot.activeSlideshowTabId = -1;
                                        controlRoot.activeSlideshowTabIndex = -1;
                                    }
                                }
                            }
                        }
                    }
                } // end ColumnLayout for mainPanel content
            } // end Rectangle (mainPanel)

            // Center panel: only the splitter
            ColumnLayout {
                id: center
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                spacing: 8

                Rectangle {
                    id: rightSplitter
                    width: 5
                    color: borderColor
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Layout.leftMargin: 3
                    Layout.rightMargin: 3

                    MouseArea {
                        id: splitterMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        property real dragStartX: 0
                        property real startRightWidth: 0
                        property real pendingWidth: 0

                        onPressed: function (mouse) {
                            // Capture the mouse position in window coordinates at press
                            var windowPos = mapToItem(controlRoot.contentItem, mouse.x, mouse.y);
                            dragStartX = windowPos.x;
                            startRightWidth = controlRoot.rightSideWidth;
                            pendingWidth = startRightWidth;
                        }
                        onPositionChanged: function (mouse) {
                            if (!pressed)
                                return;
                            // Get current mouse position in window coordinates
                            var windowPos = mapToItem(controlRoot.contentItem, mouse.x, mouse.y);

                            // Calculate how far mouse has moved from start (negative = moved left)
                            var mouseDelta = windowPos.x - dragStartX;

                            // New right width = start width minus the mouse movement
                            // (moving left increases right panel, moving right decreases it)
                            var maxWidth = controlRoot.width / 2;
                            pendingWidth = Math.max(120, Math.min(maxWidth, startRightWidth - mouseDelta / 2));
                        }
                        onReleased: {
                            controlRoot.rightSideWidth = pendingWidth;
                        }
                    }

                    // Throttled update timer for smooth dragging
                    Timer {
                        id: splitterUpdateTimer
                        interval: 16  // ~60fps
                        repeat: true
                        running: splitterMouseArea.pressed
                        onTriggered: {
                            if (Math.abs(controlRoot.rightSideWidth - splitterMouseArea.pendingWidth) > 1) {
                                controlRoot.rightSideWidth = splitterMouseArea.pendingWidth;
                            }
                        }
                    }
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
                    color: panelColor
                    border.color: borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Label {
                            text: qsTr("Output Preview")
                            color: textColor
                            font.bold: true
                            font.pixelSize: Components.Theme.fontSize
                        }

                        // Container that maintains the output window's aspect ratio
                        PreviewPanel {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            accentColor: controlRoot.accentColor
                            borderColor: controlRoot.borderColor
                            mediaTabsModel: controlRoot.mediaTabs
                            autoPlayNextVideo: controlRoot.autoPlayNextVideo
                            loopVideos: controlRoot.loopVideos
                        }
                    }
                }

                // Spectrometer panel
                Rectangle {
                    id: spectrometerPanel
                    Layout.fillWidth: true
                    implicitHeight: 100
                    radius: Components.Theme.borderRadius
                    color: panelColor
                    border.color: borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: qsTr("Spectrometer")
                                color: textColor
                                font.pixelSize: Components.Theme.fontSize
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Components.StyledSwitch {
                                id: spectrometerSwitch
                                checked: audioAnalyzer ? audioAnalyzer.active : false
                                Layout.alignment: Qt.AlignVCenter
                                panelCol: panelColor
                                accentCol: accentColor
                                borderCol: borderColor

                                onCheckedChanged: {
                                    if (audioAnalyzer) {
                                        audioAnalyzer.active = checked;
                                    }
                                }
                            }
                        }

                        Components.Spectrometer {
                            id: spectrometer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 50
                            spectrumData: audioAnalyzer ? audioAnalyzer.spectrum : []
                            barColor: accentColor
                            bgColor: panelColor
                            active: audioAnalyzer ? audioAnalyzer.active : false
                        }

                        Item {
                            Layout.fillHeight: true
                            Layout.preferredHeight: 4
                        }
                    }
                }

                // Controls stacked below preview panel
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 80
                    radius: Components.Theme.borderRadius
                    color: panelColor
                    border.color: borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.bottomMargin: 12
                        spacing: 6

                        // Blackout / brightness slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Label {
                                text: qsTr("Blackout")
                                color: textColor
                                font.pixelSize: Components.Theme.fontSize
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Components.StyledSlider {
                                id: brightnessSlider
                                from: 0.0
                                to: 1.0
                                value: 1.0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                bgColor: panelColor
                                accentCol: accentColor
                                borderCol: borderColor
                                ToolTip.visible: hovered || pressed
                                ToolTip.text: qsTr("Brightness: ") + Math.round(value * 100) + "%"

                                onValueChanged: {
                                    // Only change brightness of the real output window, not the embedded preview
                                    if (outputWindow && outputWindow.setBrightness)
                                        outputWindow.setBrightness(value);
                                }
                            }

                            Label {
                                text: Math.round(brightnessSlider.value * 100) + "%"
                                color: textColor
                                font.pixelSize: Components.Theme.fontSize
                                font.bold: true
                                Layout.preferredWidth: 45
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Spacer to ensure some padding below the slider
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                        }
                    }
                }
            }
        }

        // Bottom status bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Components.Theme.borderRadius
            color: panelColor
            border.color: borderColor

            Label {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                text: statusText
                color: subtleTextColor
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
        console.log("=== ControlWindow loaded ===");
        console.log("preferences object:", preferences);
        console.log("prefAccentColor:", prefAccentColor);

        // Sync loop setting to slideshow controller
        if (slideshow) {
            slideshow.loopEnabled = loopSlideshows;
        }
    }

    Connections {
        target: slideshow
        onCurrentImagePathChanged: {
            if (!slideshow.currentImagePath)
                return;
            var iPath = slideshow.currentImagePath;

            // Update the active slideshow tab's currentPath and sync to OutputWindow
            if (activeSlideshowTabId >= 0 && activeSlideshowTabIndex >= 0 && activeSlideshowTabIndex < mediaTabsModel.count) {
                var tab = mediaTabsModel.get(activeSlideshowTabIndex);
                if (tab && tab.tabId === activeSlideshowTabId) {
                    // Update the model for preview
                    mediaTabsModel.setProperty(activeSlideshowTabIndex, "currentPath", iPath);

                    // Find the index in the tab's media list
                    var mediaModel = tab.mediaModel;
                    if (mediaModel) {
                        for (var j = 0; j < mediaModel.count; ++j) {
                            if (mediaModel.get(j).path === iPath) {
                                mediaTabsModel.setProperty(activeSlideshowTabIndex, "currentIndex", j);
                                break;
                            }
                        }
                    }

                    // Also update OutputWindow
                    if (outputWindow) {
                        var zOrder = tab.zOrder !== undefined ? tab.zOrder : activeSlideshowTabIndex;
                        var brightness = tab.brightness !== undefined ? tab.brightness : 1.0;
                        outputWindow.setImageLayer(activeSlideshowTabId, iPath, brightness, zOrder);
                    }

                    console.log("Slideshow advanced to: " + iPath + ", tabId=" + activeSlideshowTabId);
                }
            }
        }
        onSlideshowEnded: {
            console.log("Slideshow ended (looping disabled)");
            statusText = qsTr("Slideshow ended");
            // The slideshow has already stopped in the controller
            // Reset the active slideshow tracking
            activeSlideshowTabId = -1;
            activeSlideshowTabIndex = -1;
        }
    }

    // Width of the right-side preview + controls column, adjustable via splitter
    property real rightSideWidth: Math.min(260, width / 2)
}
