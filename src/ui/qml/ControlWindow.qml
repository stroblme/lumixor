import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtMultimedia 5.15

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
    property color accentColor: "#42A5F5"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"
    property color listItemColor: "#232323"
    property color listItemHighlight: "#29434E"

    // Dynamic media tabs model: each entry is { tabId, tabType ("slideshow" or "video"), tabName, mediaModel (ListModel), brightness }
    property int nextSlideshowId: 1
    property int nextVideoId: 1
    property var mediaTabs: ListModel {
        id: mediaTabsModel
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
        var name, tabId;
        if (tabType === "slideshow") {
            tabId = nextSlideshowId;
            name = tabName || qsTr("Slideshow ") + nextSlideshowId;
            nextSlideshowId++;
        } else {
            tabId = nextVideoId;
            name = tabName || qsTr("Video ") + nextVideoId;
            nextVideoId++;
        }
        mediaTabsModel.append({
            "tabId": tabId,
            "tabType": tabType,
            "tabName": name,
            "mediaModel": newModel,
            "brightness": 1.0,
            "currentPath": "",
            "isPlaying": false,
            "currentIndex": -1
        });
        // Switch to the new tab
        mainTabs.currentIndex = mediaTabsModel.count + 1; // +2 for Preferences/Home, -1 for 0-based
        return mediaTabsModel.count - 1;
    }

    // Remove a media tab by index
    function removeMediaTab(tabIndex) {
        if (tabIndex >= 0 && tabIndex < mediaTabsModel.count) {
            var tab = mediaTabsModel.get(tabIndex);

            // Clean up video layer if this is a video tab
            if (tab.tabType === "video" && outputWindow) {
                outputWindow.removeVideoLayer(tab.tabId);
            }

            if (tab.mediaModel) {
                tab.mediaModel.clear();
            }
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

                        // Prevent switching to the "+" tab
                        onCurrentIndexChanged: {
                            // The + button is at index (2 + mediaTabsModel.count)
                            var addButtonIndex = 2 + mediaTabsModel.count;
                            if (currentIndex >= addButtonIndex) {
                                currentIndex = Math.max(0, addButtonIndex - 1);
                            }
                        }

                        // Fixed tabs
                        TabButton {
                            text: qsTr("Preferences")
                            implicitWidth: 100
                        }
                        TabButton {
                            text: qsTr("Home")
                            implicitWidth: 100
                        }

                        // Dynamic media tabs
                        Repeater {
                            model: mediaTabsModel
                            TabButton {
                                implicitWidth: 120
                                contentItem: RowLayout {
                                    spacing: 4
                                    Text {
                                        text: model.tabName
                                        color: textColor
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
                            }
                        }

                        // Add tab button (+) - not a real tab, just a button
                        TabButton {
                            id: addTabButton
                            width: 40
                            text: "+"
                            font.pixelSize: 18
                            font.bold: true
                            checkable: false
                            onClicked: {
                                addTabMenu.popup();
                            }

                            Menu {
                                id: addTabMenu
                                MenuItem {
                                    text: qsTr("New Slideshow Tab")
                                    onTriggered: addMediaTab("slideshow")
                                }
                                MenuItem {
                                    text: qsTr("New Video Tab")
                                    onTriggered: addMediaTab("video")
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

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                GroupBox {
                                    Layout.fillWidth: true
                                    title: qsTr("Slideshow")
                                    label: Label {
                                        text: qsTr("Slideshow")
                                        color: textColor
                                    }
                                    background: Rectangle {
                                        radius: 6
                                        color: panelColor
                                        border.color: borderColor
                                    }

                                    GridLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 8

                                        Label {
                                            text: qsTr("Delay (s):")
                                            color: textColor
                                            horizontalAlignment: Text.AlignLeft
                                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                        }
                                        SpinBox {
                                            id: spinSlideshow
                                            from: 1
                                            to: 3600
                                            value: slideshowDelaySeconds
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            Layout.fillWidth: true
                                            background: Rectangle {
                                                radius: 4
                                                color: backgroundColor
                                                border.color: borderColor
                                            }
                                            contentItem: TextInput {
                                                text: parent.displayText
                                                font: parent.font
                                                color: textColor
                                                selectionColor: accentColor
                                                selectedTextColor: backgroundColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                readOnly: !parent.editable
                                                validator: parent.validator
                                            }
                                            onValueChanged: slideshowDelaySeconds = value
                                        }

                                        Label {
                                            text: qsTr("Transition (ms):")
                                            color: textColor
                                            horizontalAlignment: Text.AlignLeft
                                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                        }
                                        SpinBox {
                                            id: spinTransition
                                            from: 0
                                            to: 10000
                                            value: transitionDurationMs
                                            stepSize: 50
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            Layout.fillWidth: true
                                            background: Rectangle {
                                                radius: 4
                                                color: backgroundColor
                                                border.color: borderColor
                                            }
                                            contentItem: TextInput {
                                                text: parent.displayText
                                                font: parent.font
                                                color: textColor
                                                selectionColor: accentColor
                                                selectedTextColor: backgroundColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                readOnly: !parent.editable
                                                validator: parent.validator
                                            }
                                            onValueChanged: transitionDurationMs = value
                                        }
                                    }
                                }

                                GroupBox {
                                    Layout.fillWidth: true
                                    title: qsTr("Output")
                                    label: Label {
                                        text: qsTr("Output")
                                        color: textColor
                                    }
                                    background: Rectangle {
                                        radius: 6
                                        color: panelColor
                                        border.color: borderColor
                                    }

                                    GridLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 8

                                        Label {
                                            text: qsTr("Screen index:")
                                            color: textColor
                                            horizontalAlignment: Text.AlignLeft
                                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                        }
                                        SpinBox {
                                            id: spinScreenIndex
                                            from: 0
                                            to: 8
                                            value: outputScreenIndex
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            Layout.fillWidth: true
                                            background: Rectangle {
                                                radius: 4
                                                color: backgroundColor
                                                border.color: borderColor
                                            }
                                            contentItem: TextInput {
                                                text: parent.displayText
                                                font: parent.font
                                                color: textColor
                                                selectionColor: accentColor
                                                selectedTextColor: backgroundColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                readOnly: !parent.editable
                                                validator: parent.validator
                                            }
                                            onValueChanged: outputScreenIndex = value
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillHeight: true
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 8

                                    Button {
                                        text: qsTr("Reset")
                                        background: Rectangle {
                                            radius: 6
                                            implicitHeight: 32
                                            color: panelColor
                                            border.color: borderColor
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: subtleTextColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            if (!preferences)
                                                return;
                                            slideshowDelaySeconds = preferences.slideshowIntervalSeconds;
                                            transitionDurationMs = preferences.transitionDurationMs;
                                            outputScreenIndex = preferences.outputScreenIndex;
                                            spinSlideshow.value = slideshowDelaySeconds;
                                            spinTransition.value = transitionDurationMs;
                                            spinScreenIndex.value = outputScreenIndex;
                                        }
                                    }

                                    Button {
                                        text: qsTr("Save")
                                        background: Rectangle {
                                            radius: 6
                                            implicitHeight: 32
                                            color: accentColor
                                            border.color: borderColor
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: backgroundColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            if (!preferences)
                                                return;
                                            preferences.slideshowIntervalSeconds = slideshowDelaySeconds;
                                            preferences.transitionDurationMs = transitionDurationMs;
                                            preferences.outputScreenIndex = outputScreenIndex;
                                            preferences.save();
                                            statusText = qsTr("Preferences saved");
                                        }
                                    }
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
                                    font.pixelSize: 18
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

                                            // Slideshow controls
                                            Button {
                                                visible: isSlideshow
                                                checkable: true
                                                text: checked ? qsTr("Pause Slideshow") : qsTr("Start Slideshow")
                                                Layout.preferredWidth: 160
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 32
                                                    border.color: borderColor
                                                    color: parent.down || parent.checked ? accentColor : parent.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                }
                                                onCheckedChanged: {
                                                    if (checked) {
                                                        if (playbackController.isPlaying()) {
                                                            playbackController.pause();
                                                        }
                                                        previewActiveMedia = "image";
                                                        // Set slideshow to use this tab's media
                                                        if (currentMediaModel && currentMediaModel.count > 0) {
                                                            slideshow.setImageList(currentMediaModel);
                                                            slideshow.start(slideshowDelaySeconds * 1000);
                                                            statusText = "Slideshow started (" + slideshowDelaySeconds + " s per image)";
                                                        }
                                                    } else {
                                                        slideshow.pause();
                                                        statusText = "Slideshow paused";
                                                    }
                                                }
                                            }

                                            Label {
                                                visible: isSlideshow
                                                text: qsTr("Delay: ") + slideshowDelaySeconds + qsTr(" s")
                                                color: subtleTextColor
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Video controls
                                            Button {
                                                id: dynamicPlayBtn
                                                visible: !isSlideshow
                                                checkable: true
                                                checked: tabData ? tabData.isPlaying : false
                                                text: checked ? qsTr("Pause") : qsTr("Play")
                                                Layout.preferredWidth: 120
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 32
                                                    border.color: borderColor
                                                    color: dynamicPlayBtn.down || dynamicPlayBtn.checked ? accentColor : dynamicPlayBtn.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: dynamicPlayBtn.text
                                                    color: textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                }
                                                onClicked: {
                                                    var listView = dynamicMediaList;
                                                    var row = listView.currentIndex;
                                                    var wasPlaying = tabData.isPlaying;

                                                    if (!wasPlaying) {
                                                        // Start playing
                                                        if (row < 0) {
                                                            statusText = "No video selected";
                                                            checked = false;
                                                            return;
                                                        }
                                                        var item = currentMediaModel.get(row);
                                                        var tabId = tabData.tabId;
                                                        var brightness = tabData.brightness;

                                                        // Update the model
                                                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", item.path);
                                                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isPlaying", true);
                                                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", row);

                                                        // Update output window with this video layer
                                                        outputWindow.setVideoLayer(tabId, item.path, brightness, true);

                                                        statusText = "Playing video: " + item.path;
                                                    } else {
                                                        // Pausing
                                                        mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "isPlaying", false);
                                                        outputWindow.setVideoLayer(tabData.tabId, tabData.currentPath, tabData.brightness, false);
                                                        statusText = "Video paused";
                                                    }
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            // Add media buttons
                                            Button {
                                                text: qsTr("Add Files")
                                                Layout.preferredWidth: 80
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 28
                                                    border.color: borderColor
                                                    color: parent.down ? accentColor : parent.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 11
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
                                                Layout.preferredWidth: 80
                                                background: Rectangle {
                                                    radius: 6
                                                    implicitHeight: 28
                                                    border.color: borderColor
                                                    color: parent.down ? accentColor : parent.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 11
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
                                            currentIndex: -1
                                            delegate: Rectangle {
                                                width: dynamicMediaList.width
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
                                                        dynamicMediaList.currentIndex = index;
                                                        if (isSlideshow) {
                                                            // Update currentPath in model for preview
                                                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentPath", model.path);
                                                            mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "currentIndex", index);
                                                            outputWindow.fadeToImage(model.path);
                                                        }
                                                    }
                                                }
                                            }
                                            ScrollBar.vertical: ScrollBar {}
                                        }
                                    }

                                    // Vertical brightness slider
                                    ColumnLayout {
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 40
                                        spacing: 4

                                        Label {
                                            text: qsTr("Alpha")
                                            color: subtleTextColor
                                            font.pixelSize: 10
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
                                            ToolTip.visible: hovered || pressed
                                            ToolTip.text: (isSlideshow ? qsTr("Slideshow Alpha: ") : qsTr("Video Alpha: ")) + Math.round(value * 100) + "%"
                                            onValueChanged: {
                                                if (tabData) {
                                                    mediaTabsModel.setProperty(tabContentItem.tabModelIndex, "brightness", value);

                                                    // Apply brightness to output based on type
                                                    if (isSlideshow) {
                                                        if (outputWindow && outputWindow.setImageBrightness)
                                                            outputWindow.setImageBrightness(value);
                                                    } else {
                                                        // Update the video layer brightness
                                                        if (outputWindow && tabData.currentPath) {
                                                            outputWindow.setVideoLayer(tabData.tabId, tabData.currentPath, value, tabData.isPlaying);
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Label {
                                            text: Math.round((tabData ? tabData.brightness : 1.0) * 100) + "%"
                                            color: subtleTextColor
                                            font.pixelSize: 10
                                            Layout.alignment: Qt.AlignHCenter
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
                        radius: 6
                        color: backgroundColor
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
                                    radius: 4
                                    color: "#000000"
                                    border.color: borderColor
                                    clip: true

                                    // Slideshow images from all slideshow tabs
                                    Repeater {
                                        model: mediaTabsModel
                                        Image {
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            visible: model.tabType === "slideshow"
                                            source: model.tabType === "slideshow" && model.currentPath ? controlRoot.imageUrlForPath(model.currentPath) : ""
                                            opacity: model.brightness
                                            z: index
                                        }
                                    }

                                    // Legacy slideshow image for backward compatibility
                                    Image {
                                        id: previewImage
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectFit
                                        visible: true
                                        source: slideshow ? controlRoot.imageUrlForPath(slideshow.currentImagePath) : ""
                                        opacity: slideshowBrightness
                                        z: 100
                                    }

                                    // Dynamic video layers from all video tabs
                                    Repeater {
                                        model: mediaTabsModel
                                        Item {
                                            anchors.fill: parent
                                            visible: model.tabType === "video" && model.currentPath && model.currentPath !== ""

                                            property string videoPath: model.currentPath || ""
                                            property real videoBrightness: model.brightness || 1.0
                                            property bool videoPlaying: model.isPlaying || false

                                            MediaPlayer {
                                                id: previewLayerPlayer
                                                autoPlay: false
                                                source: videoPath && videoPath !== "" ? "file://" + videoPath : ""
                                                loops: MediaPlayer.Infinite
                                            }

                                            VideoOutput {
                                                anchors.fill: parent
                                                source: previewLayerPlayer
                                                fillMode: VideoOutput.PreserveAspectFit
                                                opacity: videoBrightness
                                                visible: videoPath !== ""
                                            }

                                            onVideoPlayingChanged: {
                                                if (videoPlaying && videoPath && videoPath !== "") {
                                                    previewLayerPlayer.play();
                                                } else {
                                                    previewLayerPlayer.pause();
                                                }
                                            }

                                            onVideoPathChanged: {
                                                if (videoPath && videoPath !== "" && videoPlaying) {
                                                    previewLayerPlayer.play();
                                                }
                                            }

                                            Component.onCompleted: {
                                                if (videoPlaying && videoPath && videoPath !== "") {
                                                    previewLayerPlayer.play();
                                                }
                                            }
                                        }
                                    }
                                }
                            } // End of previewContainer Item
                        }
                    }

                    // Controls stacked below preview panel
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 60
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
                                spacing: 8

                                Label {
                                    text: qsTr("Blackout")
                                    color: subtleTextColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Slider {
                                    id: brightnessSlider
                                    from: 0.0
                                    to: 1.0
                                    value: 1.0
                                    Layout.fillWidth: true
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Brightness: " + Math.round(value * 100) + "%"
                                    onValueChanged: {
                                        // Only change brightness of the real output window, not the embedded preview
                                        if (outputWindow && outputWindow.setBrightness)
                                            outputWindow.setBrightness(value);
                                    }
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

    Component.onCompleted: refreshLists()

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
            for (var i = 0; i < imageModel.count; ++i) {
                if (imageModel.get(i).path === iPath) {
                    listImages.currentIndex = i;
                    break;
                }
            }
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
