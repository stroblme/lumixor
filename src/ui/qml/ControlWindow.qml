import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtMultimedia 5.15
import Qt.labs.platform 1.1 as Platform
import "components"
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

    // File picker setting from preferences
    property bool useCustomFilePicker: preferences ? preferences.useCustomFilePicker : true

    property int m_loadedVideoIndex: -1
    property bool isBlack: false
    property bool wasVideoPlaying: false
    property bool wasSlideshowRunning: false
    property string statusText: ""
    property string previewActiveMedia: "image" // "image" or "video" - tracks which preview should be on top

    // Per-media brightness controls (1.0 = full brightness, 0.0 = blackout)
    property real slideshowBrightness: 1.0
    property real videoBrightness: 1.0

    // Dark theme colors for the control UI
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

    // Helper to mirror OutputWindow's EXIF-aware image URL resolution
    function imageUrlForPath(p) {
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p; // already has a scheme
        if (p.startsWith("/"))
            return "image://exif/" + encodeURIComponent(p);
        return p;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Main content area with tab bar on the left and persistent preview on the right
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: panelColor
            border.color: borderColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0

                // Left side: tabs and their content, resizable via splitter
                ColumnLayout {
                    id: leftSide
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumWidth: Math.min(320, controlRoot.width * 0.35)

                    TabBar {
                        id: mainTabs
                        Layout.fillWidth: true
                        currentIndex: 1 // Default to Home tab

                        // Remove white background from TabBar
                        background: Rectangle {
                            color: "transparent"
                        }

                        // Prevent switching to the "+" tab
                        onCurrentIndexChanged: {
                            // The + button is at index (2 + mediaTabsModel.count)
                            var addButtonIndex = 2 + mediaTabsModel.count;
                            if (currentIndex >= addButtonIndex) {
                                currentIndex = Math.max(0, addButtonIndex - 1);
                            }
                        }

                        // Fixed tabs - Preferences
                        StyledTabButton {
                            id: preferencesTab
                            text: qsTr("Preferences")
                        }

                        // Fixed tabs - Home
                        StyledTabButton {
                            id: homeTab
                            text: qsTr("Home")
                        }

                        // Dynamic media tabs with drag-and-drop support
                        Repeater {
                            id: mediaTabsRepeater
                            model: mediaTabsModel

                            StyledTabButton {
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
                                        font.pixelSize: 16
                                        color: mediaTabButton.checked ? textColor : subtleTextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    // Close button
                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: closeMouseArea.containsMouse ? Qt.lighter(panelColor, 1.5) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: subtleTextColor
                                            font.pixelSize: 14
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
                                            mainTabs.currentIndex = index + 2; // +2 for Preferences and Home
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

                        // Add tab button (+) - not a real tab, just a button
                        TabButton {
                            id: addTabButton
                            width: 40
                            checkable: false
                            onClicked: {
                                addTabMenu.popup();
                            }

                            background: Rectangle {
                                color: addTabButton.hovered ? Qt.lighter(backgroundColor, 1.2) : backgroundColor
                                border.color: borderColor
                                border.width: 1
                                radius: 6
                            }

                            contentItem: Text {
                                text: "+"
                                color: subtleTextColor
                                font.pixelSize: 18
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            Menu {
                                id: addTabMenu

                                background: Rectangle {
                                    implicitWidth: 180
                                    color: panelColor
                                    border.color: borderColor
                                    radius: 6
                                }

                                MenuItem {
                                    id: slideshowMenuItem
                                    text: qsTr("New Slideshow Tab")
                                    onTriggered: addMediaTab("slideshow")

                                    background: Rectangle {
                                        implicitWidth: 180
                                        implicitHeight: 32
                                        color: slideshowMenuItem.highlighted ? Qt.lighter(panelColor, 1.3) : "transparent"
                                    }
                                    contentItem: Text {
                                        text: slideshowMenuItem.text
                                        color: textColor
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 8
                                    }
                                }
                                MenuItem {
                                    id: videoMenuItem
                                    text: qsTr("New Video Tab")
                                    onTriggered: addMediaTab("video")

                                    background: Rectangle {
                                        implicitWidth: 180
                                        implicitHeight: 32
                                        color: videoMenuItem.highlighted ? Qt.lighter(panelColor, 1.3) : "transparent"
                                    }
                                    contentItem: Text {
                                        text: videoMenuItem.text
                                        color: textColor
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 8
                                    }
                                }
                            }
                        }
                    }

                    StackLayout {
                        id: tabStack
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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
                                useCustomFilePicker: controlRoot.useCustomFilePicker

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
                                onUseCustomFilePickerUpdated: {
                                    controlRoot.useCustomFilePicker = enabled;
                                    if (preferences)
                                        preferences.useCustomFilePicker = enabled;
                                }
                            }
                        }

                        // Home tab content
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Label {
                                    text: qsTr("Welcome to Lumixor")
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 20
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Label {
                                    text: qsTr("Add media files to get started")
                                    color: subtleTextColor
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Item {
                                    Layout.fillHeight: true
                                    Layout.preferredHeight: 20
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 16

                                    Button {
                                        id: btnHomeAddFiles
                                        text: qsTr("Add Files")
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 48
                                        background: Rectangle {
                                            radius: 6
                                            border.color: borderColor
                                            color: btnHomeAddFiles.down ? accentColor : btnHomeAddFiles.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                        }
                                        contentItem: Text {
                                            text: btnHomeAddFiles.text
                                            color: textColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 14
                                        }
                                        onClicked: {
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

                                            // Add images to a new slideshow tab
                                            if (images.length > 0) {
                                                var slideshowIdx = addMediaTab("slideshow");
                                                var slideshowTab = mediaTabsModel.get(slideshowIdx);
                                                for (var j = 0; j < images.length; ++j) {
                                                    slideshowTab.mediaModel.append({
                                                        "path": images[j]
                                                    });
                                                }
                                            }

                                            // Add videos to a new video tab
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

                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Add images or videos - creates new tabs automatically")
                                    }

                                    Button {
                                        id: btnHomeAddFolder
                                        text: qsTr("Add Folder")
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 48
                                        background: Rectangle {
                                            radius: 6
                                            border.color: borderColor
                                            color: btnHomeAddFolder.down ? accentColor : btnHomeAddFolder.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                        }
                                        contentItem: Text {
                                            text: btnHomeAddFolder.text
                                            color: textColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 14
                                        }
                                        onClicked: {
                                            var folder = controlBridge.openFolderDialog();
                                            if (folder === "")
                                                return;

                                            // Get files by type
                                            var images = mediaManager.getMediaPathsFromFolder(folder, "image");
                                            var videos = mediaManager.getMediaPathsFromFolder(folder, "video");

                                            // Add images to a new slideshow tab
                                            if (images.length > 0) {
                                                var slideshowIdx = addMediaTab("slideshow");
                                                var slideshowTab = mediaTabsModel.get(slideshowIdx);
                                                for (var i = 0; i < images.length; ++i) {
                                                    slideshowTab.mediaModel.append({
                                                        "path": images[i]
                                                    });
                                                }
                                            }

                                            // Add videos to a new video tab
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

                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Recursively scan a folder - creates new tabs automatically")
                                    }
                                }

                                Item {
                                    Layout.fillHeight: true
                                }
                            }
                        }

                        // Dynamic media tab content
                        Repeater {
                            model: mediaTabsModel

                            Item {
                                id: tabContentItem
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                property int tabModelIndex: index
                                property var tabData: mediaTabsModel.get(index)
                                property bool isSlideshow: tabData ? tabData.tabType === "slideshow" : false
                                property var currentMediaModel: tabData ? tabData.mediaModel : null

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
                                            Button {
                                                id: slideshowPlayPauseBtn
                                                visible: isSlideshow
                                                checkable: true
                                                Layout.preferredWidth: 44
                                                Layout.preferredHeight: 44
                                                ToolTip.visible: hovered
                                                ToolTip.text: checked ? qsTr("Pause Slideshow") : qsTr("Start Slideshow")
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 44
                                                    implicitWidth: 44
                                                    border.color: borderColor
                                                    color: slideshowPlayPauseBtn.down || slideshowPlayPauseBtn.checked ? accentColor : slideshowPlayPauseBtn.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: slideshowPlayPauseBtn.checked ? "⏸" : "▶"
                                                    color: textColor
                                                    font.pixelSize: 18
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onCheckedChanged: {
                                                    if (checked) {
                                                        if (playbackController.isPlaying()) {
                                                            playbackController.pause();
                                                        }
                                                        previewActiveMedia = "image";
                                                        // Set slideshow to use this tab's media
                                                        if (currentMediaModel && currentMediaModel.count > 0) {
                                                            // Only set image list if this is a new slideshow (not resuming)
                                                            var isResumingSameTab = (activeSlideshowTabId === tabData.tabId);

                                                            // Track which tab is running the slideshow
                                                            activeSlideshowTabId = tabData.tabId;
                                                            activeSlideshowTabIndex = tabContentItem.tabModelIndex;

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
                                                            statusText = isResumingSameTab ? "Slideshow resumed" : "Slideshow started (" + slideshowDelaySeconds + " s per image)";
                                                        }
                                                    } else {
                                                        slideshow.pause();
                                                        // Don't clear activeSlideshowTabId on pause so we can resume
                                                        statusText = "Slideshow paused";
                                                    }
                                                }
                                            }

                                            // Slideshow Stop Icon Button
                                            Button {
                                                id: slideshowStopBtn
                                                visible: isSlideshow
                                                Layout.preferredWidth: 44
                                                Layout.preferredHeight: 44
                                                ToolTip.visible: hovered
                                                ToolTip.text: qsTr("Stop Slideshow")
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 44
                                                    implicitWidth: 44
                                                    border.color: borderColor
                                                    color: slideshowStopBtn.down ? accentColor : slideshowStopBtn.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: "⏹"
                                                    color: textColor
                                                    font.pixelSize: 20
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    // Stop and reset the slideshow
                                                    slideshow.reset();
                                                    slideshowPlayPauseBtn.checked = false;
                                                    activeSlideshowTabId = -1;
                                                    activeSlideshowTabIndex = -1;

                                                    // Clear the current path for preview
                                                    mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", "");
                                                    mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", -1);

                                                    // Also stop in OutputWindow
                                                    if (outputWindow) {
                                                        outputWindow.stopMediaLayer(tabData.tabId);
                                                    }

                                                    // Clear list selection
                                                    dynamicMediaList.currentIndex = -1;
                                                    statusText = "Slideshow stopped";
                                                }
                                            }

                                            Label {
                                                visible: isSlideshow
                                                text: qsTr("Delay: ") + slideshowDelaySeconds + qsTr(" s")
                                                color: textColor
                                                font.pixelSize: 14
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Slideshow Progress Slider
                                            Slider {
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

                                                ToolTip.visible: hovered || pressed
                                                ToolTip.text: qsTr("Image ") + (Math.round(value) + 1) + " / " + (currentMediaModel ? currentMediaModel.count : 0)

                                                handle: Rectangle {
                                                    x: slideshowProgressSlider.leftPadding + slideshowProgressSlider.visualPosition * (slideshowProgressSlider.availableWidth - width)
                                                    y: slideshowProgressSlider.topPadding + slideshowProgressSlider.availableHeight / 2 - height / 2
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: slideshowProgressSlider.pressed ? accentColor : panelColor
                                                    border.color: accentColor
                                                    border.width: 2
                                                }

                                                background: Rectangle {
                                                    x: slideshowProgressSlider.leftPadding
                                                    y: slideshowProgressSlider.topPadding + slideshowProgressSlider.availableHeight / 2 - height / 2
                                                    width: slideshowProgressSlider.availableWidth
                                                    height: 8
                                                    radius: 6
                                                    color: borderColor

                                                    Rectangle {
                                                        width: slideshowProgressSlider.visualPosition * parent.width
                                                        height: parent.height
                                                        radius: 6
                                                        color: accentColor
                                                    }
                                                }

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

                                                            statusText = qsTr("Jumped to image ") + (targetIndex + 1);
                                                        }
                                                    }
                                                }
                                            }

                                            // Slideshow position label
                                            Label {
                                                visible: isSlideshow
                                                text: (tabData && tabData.currentIndex >= 0 ? (tabData.currentIndex + 1) : 0) + "/" + (currentMediaModel ? currentMediaModel.count : 0)
                                                color: subtleTextColor
                                                font.pixelSize: 14
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: 50
                                                horizontalAlignment: Text.AlignRight
                                            }

                                            // Video controls - Play/Pause Icon Button
                                            Button {
                                                id: dynamicPlayBtn
                                                visible: !isSlideshow
                                                checkable: true
                                                checked: tabData ? tabData.isPlaying : false
                                                Layout.preferredWidth: 44
                                                Layout.preferredHeight: 44
                                                ToolTip.visible: hovered
                                                ToolTip.text: checked ? qsTr("Pause Video") : qsTr("Play Video")
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 44
                                                    implicitWidth: 44
                                                    border.color: borderColor
                                                    color: dynamicPlayBtn.down || dynamicPlayBtn.checked ? accentColor : dynamicPlayBtn.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: dynamicPlayBtn.checked ? "⏸" : "▶"
                                                    color: textColor
                                                    font.pixelSize: 18
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
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
                                                            statusText = "No videos in list";
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

                                                        statusText = "Playing video: " + item.path;
                                                    } else {
                                                        // Pausing
                                                        var pauseZOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isPlaying", false);
                                                        if (outputWindow) {
                                                            outputWindow.setVideoLayer(tabData.tabId, tabData.currentPath, tabData.brightness, false, pauseZOrder);
                                                        }
                                                        statusText = "Video paused";
                                                    }
                                                }
                                            }

                                            // Video Stop Icon Button
                                            Button {
                                                id: videoStopBtn
                                                visible: !isSlideshow
                                                Layout.preferredWidth: 44
                                                Layout.preferredHeight: 44
                                                ToolTip.visible: hovered
                                                ToolTip.text: qsTr("Stop Video")
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 44
                                                    implicitWidth: 44
                                                    border.color: borderColor
                                                    color: videoStopBtn.down ? accentColor : videoStopBtn.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: "⏹"
                                                    color: textColor
                                                    font.pixelSize: 20
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
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
                                                    statusText = "Video stopped";
                                                }
                                            }

                                            // Video Progress Slider
                                            Slider {
                                                id: videoProgressSlider
                                                visible: !isSlideshow
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 44
                                                from: 0
                                                to: tabData && tabData.videoDuration > 0 ? tabData.videoDuration : 1000
                                                enabled: tabData && tabData.currentPath !== ""

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

                                                handle: Rectangle {
                                                    x: videoProgressSlider.leftPadding + videoProgressSlider.visualPosition * (videoProgressSlider.availableWidth - width)
                                                    y: videoProgressSlider.topPadding + videoProgressSlider.availableHeight / 2 - height / 2
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: videoProgressSlider.pressed ? accentColor : panelColor
                                                    border.color: accentColor
                                                    border.width: 2
                                                }

                                                background: Rectangle {
                                                    x: videoProgressSlider.leftPadding
                                                    y: videoProgressSlider.topPadding + videoProgressSlider.availableHeight / 2 - height / 2
                                                    width: videoProgressSlider.availableWidth
                                                    height: 8
                                                    radius: 6
                                                    color: borderColor

                                                    Rectangle {
                                                        width: videoProgressSlider.visualPosition * parent.width
                                                        height: parent.height
                                                        radius: 6
                                                        color: accentColor
                                                    }
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
                                                font.pixelSize: 14
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: 80
                                                horizontalAlignment: Text.AlignRight
                                            }

                                            Item {
                                                Layout.fillWidth: false
                                                Layout.preferredWidth: 8
                                            }

                                            // Add media buttons
                                            Button {
                                                text: qsTr("Add Files")
                                                Layout.preferredWidth: 100
                                                Layout.preferredHeight: 44
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 44
                                                    border.color: borderColor
                                                    color: parent.down ? accentColor : parent.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 14
                                                }
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
                                                        statusText = qsTr("Added %1 files").arg(addedCount);
                                                    }
                                                }
                                            }

                                            Button {
                                                text: qsTr("Add Folder")
                                                Layout.preferredWidth: 100
                                                Layout.preferredHeight: 44
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 44
                                                    border.color: borderColor
                                                    color: parent.down ? accentColor : parent.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 14
                                                }
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
                                                        statusText = qsTr("Added %1 files from folder").arg(paths.length);
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
                                            delegate: Rectangle {
                                                width: dynamicMediaList.width
                                                height: 40
                                                color: ListView.isCurrentItem ? listItemHighlight : listItemColor
                                                radius: 6
                                                border.color: borderColor
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    text: fileNameFromPath(model.path)
                                                    color: textColor
                                                    elide: Text.ElideRight
                                                    width: parent.width - 40
                                                }
                                                // Delete button
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: delMouseArea.containsMouse ? Qt.lighter(listItemColor, 1.5) : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "×"
                                                        color: subtleTextColor
                                                        font.pixelSize: 14
                                                    }
                                                    MouseArea {
                                                        id: delMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: {
                                                            currentMediaModel.remove(index);
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 36
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
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
                                                }
                                            }
                                            ScrollBar.vertical: ScrollBar {}
                                        }
                                    }

                                    // Combined sliders + link button (video tabs only)
                                    ColumnLayout {
                                        visible: !isSlideshow
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 45    // wide enough to cover both sliders
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 8

                                            // Volume slider column
                                            ColumnLayout {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                spacing: 4

                                                Label {
                                                    text: qsTr("Volume")
                                                    color: textColor
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    Layout.alignment: Qt.AlignHCenter
                                                }

                                                Slider {
                                                    id: tabVolumeSlider
                                                    orientation: Qt.Vertical
                                                    from: 0.0
                                                    to: 1.0
                                                    value: tabData ? tabData.volume : 1.0
                                                    Layout.fillHeight: true
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: 44
                                                    ToolTip.visible: hovered || pressed
                                                    ToolTip.text: qsTr("Volume: ") + Math.round(value * 100) + "%"

                                                    handle: Rectangle {
                                                        x: tabVolumeSlider.leftPadding + tabVolumeSlider.availableWidth / 2 - width / 2
                                                        y: tabVolumeSlider.topPadding + tabVolumeSlider.visualPosition * (tabVolumeSlider.availableHeight - height)
                                                        width: 28
                                                        height: 28
                                                        radius: 14
                                                        color: tabVolumeSlider.pressed ? accentColor : panelColor
                                                        border.color: accentColor
                                                        border.width: 2
                                                    }
                                                    background: Rectangle {
                                                        x: tabVolumeSlider.leftPadding + tabVolumeSlider.availableWidth / 2 - width / 2
                                                        y: tabVolumeSlider.topPadding
                                                        width: 8
                                                        height: tabVolumeSlider.availableHeight
                                                        radius: 6
                                                        color: borderColor
                                                        Rectangle {
                                                            width: parent.width
                                                            height: (1 - tabVolumeSlider.visualPosition) * parent.height
                                                            y: tabVolumeSlider.visualPosition * parent.height
                                                            radius: 6
                                                            color: accentColor
                                                        }
                                                    }

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
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }

                                            // Brightness/alpha slider column
                                            ColumnLayout {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                spacing: 4

                                                Label {
                                                    text: qsTr("Alpha")
                                                    color: textColor
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    Layout.alignment: Qt.AlignHCenter
                                                }

                                                Slider {
                                                    id: tabBrightnessSlider
                                                    orientation: Qt.Vertical
                                                    from: 0.0
                                                    to: 1.0
                                                    value: tabData ? tabData.brightness : 1.0
                                                    Layout.fillHeight: true
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: 44
                                                    ToolTip.visible: hovered || pressed
                                                    ToolTip.text: qsTr("Video Alpha: ") + Math.round(value * 100) + "%"

                                                    handle: Rectangle {
                                                        x: tabBrightnessSlider.leftPadding + tabBrightnessSlider.availableWidth / 2 - width / 2
                                                        y: tabBrightnessSlider.topPadding + tabBrightnessSlider.visualPosition * (tabBrightnessSlider.availableHeight - height)
                                                        width: 28
                                                        height: 28
                                                        radius: 14
                                                        color: tabBrightnessSlider.pressed ? accentColor : panelColor
                                                        border.color: accentColor
                                                        border.width: 2
                                                    }
                                                    background: Rectangle {
                                                        x: tabBrightnessSlider.leftPadding + tabBrightnessSlider.availableWidth / 2 - width / 2
                                                        y: tabBrightnessSlider.topPadding
                                                        width: 8
                                                        height: tabBrightnessSlider.availableHeight
                                                        radius: 6
                                                        color: borderColor
                                                        Rectangle {
                                                            width: parent.width
                                                            height: (1 - tabBrightnessSlider.visualPosition) * parent.height
                                                            y: tabBrightnessSlider.visualPosition * parent.height
                                                            radius: 6
                                                            color: accentColor
                                                        }
                                                    }

                                                    onValueChanged: {
                                                        if (!tabData)
                                                            return;
                                                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "brightness", value);
                                                        if (outputWindow) {
                                                            outputWindow.setMediaLayerBrightness(tabData.tabId, value);
                                                            var zOrder = tabData.zOrder !== undefined ? tabData.zOrder : tabContentItem.tabModelIndex;
                                                            var currentPath = tabData.currentPath;
                                                            if (currentPath) {
                                                                outputWindow.setVideoLayer(tabData.tabId, currentPath, value, tabData.isPlaying, zOrder);
                                                            }
                                                        }
                                                        // Link to volume
                                                        if (tabData.linkSliders && Math.abs(tabData.volume - value) > 0.001) {
                                                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "volume", value);
                                                            if (outputWindow) {
                                                                outputWindow.setVideoLayerVolume(tabData.tabId, value);
                                                            }
                                                        }
                                                    }
                                                }

                                                Label {
                                                    text: Math.round((tabData ? tabData.brightness : 1.0) * 100) + "%"
                                                    color: textColor
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        } // end RowLayout with two sliders

                                        // Wide link/unlink button below both sliders
                                        Rectangle {
                                            id: linkToggleButton
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            radius: 6
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
                                                    font.pixelSize: 14
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
                        }
                    }
                }

                Rectangle {
                    id: rightSplitter
                    width: 4
                    color: borderColor
                    Layout.fillHeight: true

                    MouseArea {
                        id: splitterMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        property real dragStartX: 0
                        property real startRightWidth: 0
                        property real pendingWidth: 0
                        property real splitterStartX: 0

                        onPressed: function (mouse) {
                            // Capture the splitter's initial position in window coordinates
                            splitterStartX = rightSplitter.mapToItem(controlRoot.contentItem, 0, 0).x;
                            // Store where we clicked relative to the splitter
                            dragStartX = mouse.x;
                            startRightWidth = controlRoot.rightSideWidth;
                            pendingWidth = startRightWidth;
                        }
                        onPositionChanged: function (mouse) {
                            if (!pressed)
                                return;
                            // Calculate how far the mouse has moved from initial click position
                            // mouse.x is relative to the MouseArea, which stays with the splitter
                            // So we need to account for how much the splitter itself has moved
                            var splitterCurrentX = rightSplitter.mapToItem(controlRoot.contentItem, 0, 0).x;
                            var splitterDelta = splitterCurrentX - splitterStartX;
                            var mouseDelta = mouse.x - dragStartX;
                            // Total movement = how much splitter moved + mouse movement within splitter
                            var totalDelta = splitterDelta + mouseDelta;
                            var maxWidth = controlRoot.width / 2;
                            pendingWidth = Math.max(120, Math.min(maxWidth, startRightWidth - totalDelta));
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
                        radius: 6
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
                            }

                            // Container that maintains the output window's aspect ratio
                            Item {
                                id: previewContainer
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Use 16:9 aspect ratio as default (common for presentations)
                                property real outputAspect: 16 / 9

                                Rectangle {
                                    id: previewFrame
                                    anchors.centerIn: parent
                                    // Fit within container while maintaining aspect ratio
                                    property real containerAspect: previewContainer.width / Math.max(1, previewContainer.height)
                                    property bool isHeightLimited: containerAspect > previewContainer.outputAspect

                                    width: Math.max(50, isHeightLimited ? previewContainer.height * previewContainer.outputAspect : previewContainer.width)
                                    height: Math.max(50, isHeightLimited ? previewContainer.height : previewContainer.width / previewContainer.outputAspect)
                                    radius: 6
                                    color: "#000000"
                                    border.color: borderColor
                                    clip: true

                                    // Unified media layers from all tabs (both slideshow and video)
                                    Repeater {
                                        model: mediaTabsModel

                                        Item {
                                            id: previewMediaItem
                                            anchors.fill: parent
                                            z: model.zOrder !== undefined ? model.zOrder : index

                                            // Use direct model access for better reactivity
                                            property string mediaPath: model.currentPath ? model.currentPath : ""
                                            property real mediaBrightness: model.brightness !== undefined ? model.brightness : 1.0
                                            // property real mediaVolume: model.volume !== undefined ? model.volume : 1.0
                                            property real mediaVolume: 0
                                            property bool mediaPlaying: model.isPlaying ? model.isPlaying : false
                                            property string mediaType: model.tabType ? model.tabType : "video"
                                            property int seekPosition: model.seekPosition !== undefined ? model.seekPosition : -1
                                            property bool isSeeking: model.isSeeking ? model.isSeeking : false

                                            // Determine if this layer has active content (for border)
                                            property bool hasActiveContent: mediaPath !== ""

                                            visible: true  // Always visible, let children handle visibility

                                            // Handle seek requests
                                            onSeekPositionChanged: {
                                                if (seekPosition >= 0 && mediaType === "video") {
                                                    console.log("Preview seeking to: " + seekPosition);
                                                    previewMediaPlayer.seek(seekPosition);
                                                    // Reset the seekPosition to -1 after seeking
                                                    if (index >= 0 && index < mediaTabsModel.count) {
                                                        mediaTabsModel.setProperty(index, "seekPosition", -1);
                                                    }
                                                }
                                            }

                                            // Image display (for slideshow type)
                                            Image {
                                                id: previewImageItem
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectFit
                                                visible: previewMediaItem.mediaType === "slideshow" && previewMediaItem.mediaPath !== ""
                                                source: previewMediaItem.mediaType === "slideshow" && previewMediaItem.mediaPath !== "" ? controlRoot.imageUrlForPath(previewMediaItem.mediaPath) : ""
                                                opacity: previewMediaItem.mediaBrightness

                                                onSourceChanged: {
                                                    console.log("Preview image source changed: " + source + ", visible=" + visible);
                                                }

                                                // Blue border around actual image content (indicates size in output)
                                                Rectangle {
                                                    visible: previewImageItem.visible && previewImageItem.status === Image.Ready
                                                    color: "transparent"
                                                    border.color: accentColor
                                                    border.width: 2
                                                    radius: 2
                                                    z: 100

                                                    // Calculate position and size based on image's painted area
                                                    property real imgRatio: previewImageItem.sourceSize.width > 0 ? previewImageItem.sourceSize.height / previewImageItem.sourceSize.width : 1
                                                    property real containerRatio: previewImageItem.height / Math.max(1, previewImageItem.width)
                                                    property real paintedWidth: containerRatio > imgRatio ? previewImageItem.width : previewImageItem.height / imgRatio
                                                    property real paintedHeight: containerRatio > imgRatio ? previewImageItem.width * imgRatio : previewImageItem.height

                                                    x: (previewImageItem.width - paintedWidth) / 2
                                                    y: (previewImageItem.height - paintedHeight) / 2
                                                    width: paintedWidth
                                                    height: paintedHeight
                                                }
                                            }

                                            // Video display (for video type)
                                            MediaPlayer {
                                                id: previewMediaPlayer
                                                autoPlay: false
                                                source: previewMediaItem.mediaType === "video" && previewMediaItem.mediaPath !== "" ? "file://" + previewMediaItem.mediaPath : ""
                                                volume: previewMediaItem.mediaVolume

                                                // Track if we're auto-advancing to play on load
                                                property bool pendingAutoPlay: false

                                                onPositionChanged: {
                                                    // Only update position in model if not seeking (to prevent slider jumping back)
                                                    if (previewMediaItem.mediaType === "video" && !previewMediaItem.isSeeking && index >= 0 && index < mediaTabsModel.count) {
                                                        mediaTabsModel.setProperty(index, "videoPosition", position);
                                                    }
                                                }

                                                onDurationChanged: {
                                                    // Update duration in model for the progress slider
                                                    if (previewMediaItem.mediaType === "video" && index >= 0 && index < mediaTabsModel.count) {
                                                        mediaTabsModel.setProperty(index, "videoDuration", duration);
                                                    }
                                                }

                                                onStatusChanged: {
                                                    console.log("Preview MediaPlayer status changed: " + status + ", pendingAutoPlay=" + pendingAutoPlay);
                                                    if (status === MediaPlayer.Loaded) {
                                                        if (index >= 0 && index < mediaTabsModel.count) {
                                                            mediaTabsModel.setProperty(index, "videoDuration", duration);
                                                        }
                                                        // Auto-play if we were advancing to next video
                                                        if (pendingAutoPlay && previewMediaItem.mediaPlaying) {
                                                            pendingAutoPlay = false;
                                                            previewMediaPlayer.play();
                                                        }
                                                    }
                                                    // Detect when video reaches the end
                                                    if (status === MediaPlayer.EndOfMedia && previewMediaItem.mediaPlaying) {
                                                        if (autoPlayNextVideo) {
                                                            advanceToNextVideo(index);
                                                        } else {
                                                            // Stop playback - don't auto-advance
                                                            console.log("Video ended, auto-play next disabled - stopping playback");
                                                            mediaTabsModel.setProperty(index, "isPlaying", false);
                                                            if (outputWindow) {
                                                                var tab = mediaTabsModel.get(index);
                                                                if (tab) {
                                                                    var zOrder = tab.zOrder !== undefined ? tab.zOrder : index;
                                                                    outputWindow.setVideoLayer(tab.tabId, tab.currentPath, tab.brightness, false, zOrder);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                onSourceChanged: {
                                                    console.log("Preview MediaPlayer source changed: " + source);
                                                    // When source changes while playing, mark for auto-play when loaded
                                                    if (source !== "" && previewMediaItem.mediaPlaying) {
                                                        pendingAutoPlay = true;
                                                    }
                                                }
                                            }

                                            // Function to advance to next video in the list
                                            function advanceToNextVideo(tabIndex) {
                                                if (tabIndex < 0 || tabIndex >= mediaTabsModel.count)
                                                    return;

                                                var tab = mediaTabsModel.get(tabIndex);
                                                if (!tab || tab.tabType !== "video")
                                                    return;

                                                var mediaModel = tab.mediaModel;
                                                if (!mediaModel || mediaModel.count === 0)
                                                    return;

                                                var currentIdx = tab.currentIndex;
                                                var nextIdx = currentIdx + 1;

                                                // If at end of list, check if looping is enabled
                                                if (nextIdx >= mediaModel.count) {
                                                    if (loopVideos) {
                                                        nextIdx = 0;  // Loop back to beginning
                                                    } else {
                                                        // Stop playback - don't loop
                                                        console.log("Video list ended, looping disabled - stopping playback");
                                                        mediaTabsModel.setProperty(tabIndex, "isPlaying", false);
                                                        if (outputWindow) {
                                                            var stopZOrder = tab.zOrder !== undefined ? tab.zOrder : tabIndex;
                                                            outputWindow.setVideoLayer(tab.tabId, tab.currentPath, tab.brightness, false, stopZOrder);
                                                        }
                                                        return;
                                                    }
                                                }

                                                var nextItem = mediaModel.get(nextIdx);
                                                if (nextItem && nextItem.path) {
                                                    console.log("Advancing to next video: index=" + nextIdx + ", path=" + nextItem.path);

                                                    // Update the model
                                                    mediaTabsModel.setProperty(tabIndex, "currentPath", nextItem.path);
                                                    mediaTabsModel.setProperty(tabIndex, "currentIndex", nextIdx);
                                                    mediaTabsModel.setProperty(tabIndex, "videoPosition", 0);

                                                    // Update OutputWindow
                                                    if (outputWindow) {
                                                        var zOrder = tab.zOrder !== undefined ? tab.zOrder : tabIndex;
                                                        outputWindow.setVideoLayer(tab.tabId, nextItem.path, tab.brightness, true, zOrder);
                                                    }
                                                }
                                            }

                                            VideoOutput {
                                                id: previewVideoOutput
                                                anchors.fill: parent
                                                source: previewMediaPlayer
                                                fillMode: VideoOutput.PreserveAspectFit
                                                opacity: previewMediaItem.mediaBrightness
                                                visible: previewMediaItem.mediaType === "video" && previewMediaItem.mediaPath !== ""

                                                onVisibleChanged: {
                                                    console.log("Preview video visible changed: " + visible + ", path=" + previewMediaItem.mediaPath + ", type=" + previewMediaItem.mediaType);
                                                }

                                                // Blue border around actual video content (indicates size in output)
                                                Rectangle {
                                                    visible: previewVideoOutput.visible && previewMediaPlayer.status >= MediaPlayer.Loaded
                                                    color: "transparent"
                                                    border.color: accentColor
                                                    border.width: 2
                                                    radius: 2
                                                    z: 100

                                                    // Calculate position and size based on video's content rect
                                                    property real vidWidth: previewVideoOutput.contentRect.width
                                                    property real vidHeight: previewVideoOutput.contentRect.height
                                                    property real vidX: previewVideoOutput.contentRect.x
                                                    property real vidY: previewVideoOutput.contentRect.y

                                                    x: vidX
                                                    y: vidY
                                                    width: vidWidth > 0 ? vidWidth : parent.width
                                                    height: vidHeight > 0 ? vidHeight : parent.height
                                                }
                                            }

                                            onMediaPlayingChanged: {
                                                console.log("Preview mediaPlaying changed: " + mediaPlaying + ", type=" + mediaType + ", path=" + mediaPath);
                                                if (mediaType === "video") {
                                                    if (mediaPlaying && mediaPath !== "") {
                                                        previewMediaPlayer.play();
                                                    } else {
                                                        previewMediaPlayer.pause();
                                                    }
                                                }
                                            }

                                            onMediaPathChanged: {
                                                console.log("Preview mediaPath changed: " + mediaPath + ", type=" + mediaType + ", brightness=" + mediaBrightness);
                                                if (mediaType === "video" && mediaPath !== "" && mediaPlaying) {
                                                    previewMediaPlayer.play();
                                                }
                                            }

                                            onMediaBrightnessChanged: {
                                                console.log("Preview mediaBrightness changed: " + mediaBrightness + ", type=" + mediaType);
                                            }

                                            Component.onCompleted: {
                                                console.log("Preview media item created: type=" + mediaType + ", path=" + mediaPath + ", brightness=" + mediaBrightness + ", playing=" + mediaPlaying);
                                                if (mediaType === "video" && mediaPlaying && mediaPath !== "") {
                                                    previewMediaPlayer.play();
                                                }
                                            }
                                        }
                                    }
                                }
                            } // End of previewContainer Item
                        }
                    }

                    // Spectrometer panel
                    Rectangle {
                        id: spectrometerPanel
                        Layout.fillWidth: true
                        implicitHeight: 100
                        radius: 6
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
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    id: spectrometerSwitch
                                    checked: audioAnalyzer ? audioAnalyzer.active : false
                                    Layout.alignment: Qt.AlignVCenter

                                    onCheckedChanged: {
                                        if (audioAnalyzer) {
                                            audioAnalyzer.active = checked;
                                        }
                                    }

                                    indicator: Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 20
                                        x: spectrometerSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 10
                                        color: spectrometerSwitch.checked ? accentColor : borderColor

                                        Rectangle {
                                            x: spectrometerSwitch.checked ? parent.width - width - 2 : 2
                                            y: 2
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: "#FFFFFF"

                                            Behavior on x {
                                                NumberAnimation {
                                                    duration: 100
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Spectrometer {
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
                        radius: 6
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
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Slider {
                                    id: brightnessSlider
                                    from: 0.0
                                    to: 1.0
                                    value: 1.0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    ToolTip.visible: hovered || pressed
                                    ToolTip.text: qsTr("Brightness: ") + Math.round(value * 100) + "%"

                                    // Make the handle larger for touch
                                    handle: Rectangle {
                                        x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: brightnessSlider.pressed ? accentColor : panelColor
                                        border.color: accentColor
                                        border.width: 2
                                    }

                                    background: Rectangle {
                                        x: brightnessSlider.leftPadding
                                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                        width: brightnessSlider.availableWidth
                                        height: 8
                                        radius: 6
                                        color: borderColor

                                        // Filled from left (inverted - filled by default at 100%)
                                        Rectangle {
                                            width: brightnessSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 6
                                            color: accentColor
                                        }
                                    }

                                    onValueChanged: {
                                        // Only change brightness of the real output window, not the embedded preview
                                        if (outputWindow && outputWindow.setBrightness)
                                            outputWindow.setBrightness(value);
                                    }
                                }

                                Label {
                                    text: Math.round(brightnessSlider.value * 100) + "%"
                                    color: textColor
                                    font.pixelSize: 14
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
        }

        // Bottom status bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
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

    ListModel {
        id: imageModel
    }
    ListModel {
        id: videoModel
    }

    function refreshLists() {
        imageModel.clear();
        videoModel.clear();
        for (var i = 0; i < mediaManager.count(); ++i) {
            var t = mediaManager.typeAt(i);
            var p = mediaManager.pathAt(i);
            if (t === "image")
                imageModel.append({
                    "path": p
                });
            else if (t === "video")
                videoModel.append({
                    "path": p
                });
        }

        // Initial sync with current media paths, if available
        if (playbackController && playbackController.currentMediaPath) {
            var vPath = playbackController.currentMediaPath;
            for (var vi = 0; vi < videoModel.count; ++vi) {
                if (videoModel.get(vi).path === vPath) {
                    listVideos.currentIndex = vi;
                    m_loadedVideoIndex = vi;
                    break;
                }
            }
        }
        if (slideshow && slideshow.currentImagePath) {
            var iPath = slideshow.currentImagePath;
            for (var ii = 0; ii < imageModel.count; ++ii) {
                if (imageModel.get(ii).path === iPath) {
                    listImages.currentIndex = ii;
                    break;
                }
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

        refreshLists();
        // Sync loop setting to slideshow controller
        if (slideshow) {
            slideshow.loopEnabled = loopSlideshows;
        }
        // Connect the mediaTabsModel to OutputWindow for shared state
        if (outputWindow) {
            outputWindow.setExternalMediaTabsModel(mediaTabsModel);
        }
    }

    Connections {
        target: mediaManager
        onItemsChanged: refreshLists()
    }

    Connections {
        target: playbackController
        onCurrentMediaPathChanged: {
            if (!playbackController.currentMediaPath)
                return;
            var vPath = playbackController.currentMediaPath;
            for (var i = 0; i < videoModel.count; ++i) {
                if (videoModel.get(i).path === vPath) {
                    listVideos.currentIndex = i;
                    m_loadedVideoIndex = i;
                    break;
                }
            }
        }
        onMediaFinished: {
            statusText = "Media finished";
            btnPlayToggle.checked = false;
            btnPlayToggle.text = "Play";
            m_loadedVideoIndex = -1;
            listVideos.currentIndex = -1;
        }
    }

    Connections {
        target: slideshow
        onCurrentImagePathChanged: {
            if (!slideshow.currentImagePath)
                return;
            var iPath = slideshow.currentImagePath;

            // Update legacy list (for backward compatibility)
            for (var i = 0; i < imageModel.count; ++i) {
                if (imageModel.get(i).path === iPath) {
                    listImages.currentIndex = i;
                    break;
                }
            }

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

    function fileNameFromPath(p) {
        if (!p)
            return "";
        var s = String(p);
        var parts = s.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : s;
    }

    // Width of the right-side preview + controls column, adjustable via splitter
    property real rightSideWidth: Math.min(260, width / 2)
}
