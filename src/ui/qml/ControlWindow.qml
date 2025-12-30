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

    // Dark theme colors for the control UI
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#42A5F5"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"
    property color listItemColor: "#232323"
    property color listItemHighlight: "#29434E"

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

                        TabButton {
                            text: qsTr("Preferences")
                        }
                        TabButton {
                            text: qsTr("Slideshow")
                        }
                        TabButton {
                            text: qsTr("Video")
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

                        // Slideshow tab content
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Button {
                                        id: btnSlideshowToggle
                                        checkable: true
                                        text: "Start Slideshow"
                                        Layout.preferredWidth: 160
                                        background: Rectangle {
                                            radius: 6
                                            implicitHeight: 32
                                            border.color: borderColor
                                            color: btnSlideshowToggle.down || btnSlideshowToggle.checked ? accentColor : btnSlideshowToggle.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                        }
                                        contentItem: Text {
                                            text: btnSlideshowToggle.text
                                            color: textColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        onCheckedChanged: {
                                            if (checked) {
                                                if (playbackController.isPlaying())
                                                    playbackController.pause();
                                                slideshow.start(slideshowDelaySeconds * 1000);
                                                statusText = "Slideshow started (" + slideshowDelaySeconds + " s per image)";
                                                btnSlideshowToggle.text = "Pause Slideshow";
                                            } else {
                                                slideshow.pause();
                                                statusText = "Slideshow paused";
                                                btnSlideshowToggle.text = "Resume Slideshow";
                                            }
                                        }
                                    }

                                    Label {
                                        text: qsTr("Delay: ") + slideshowDelaySeconds + qsTr(" s")
                                        color: subtleTextColor
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                // Image list view used by slideshow
                                ListView {
                                    id: listImages
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: imageModel
                                    delegate: Rectangle {
                                        width: listImages.width
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
                                            width: parent.width - 16
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                listImages.currentIndex = index;
                                                outputWindow.fadeToImage(model.path);
                                            }
                                        }
                                    }
                                    ScrollBar.vertical: ScrollBar {}
                                }
                            }
                        }

                        // Video tab content
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Button {
                                        id: btnPlayToggle
                                        checkable: true
                                        text: "Play"
                                        Layout.preferredWidth: 120
                                        background: Rectangle {
                                            radius: 6
                                            implicitHeight: 32
                                            border.color: borderColor
                                            color: btnPlayToggle.down || btnPlayToggle.checked ? accentColor : btnPlayToggle.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                        }
                                        contentItem: Text {
                                            text: btnPlayToggle.text
                                            color: textColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                        onCheckedChanged: {
                                            if (checked) {
                                                var row = listVideos.currentIndex;
                                                if (row < 0) {
                                                    btnPlayToggle.checked = false;
                                                    statusText = "No video selected";
                                                    return;
                                                }
                                                if (row !== m_loadedVideoIndex) {
                                                    var item = videoModel.get(row);
                                                    playbackController.loadMediaPath(item.path);
                                                    outputWindow.showVideo();
                                                    m_loadedVideoIndex = row;
                                                    statusText = "Playing video: " + item.path;
                                                }
                                                playbackController.play();
                                                btnPlayToggle.text = "Pause";
                                            } else {
                                                playbackController.pause();
                                                statusText = "Video paused";
                                                btnPlayToggle.text = "Resume";
                                            }
                                        }
                                    }
                                }

                                // Video list view and controls
                                ListView {
                                    id: listVideos
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: videoModel
                                    currentIndex: -1
                                    delegate: Rectangle {
                                        width: listVideos.width
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
                                            width: parent.width - 16
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                listVideos.currentIndex = index;
                                            }
                                        }
                                    }
                                    ScrollBar.vertical: ScrollBar {}
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

                            Rectangle {
                                id: previewFrame
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 4
                                color: "#000000"
                                border.color: borderColor

                                // Slideshow image: exact path used by OutputWindow via EXIF provider
                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    visible: slideshow && slideshow.currentImagePath !== ""
                                    source: slideshow ? controlRoot.imageUrlForPath(slideshow.currentImagePath) : ""
                                }

                                // Video preview: small live video using the same source as OutputWindow
                                VideoOutput {
                                    id: previewVideo
                                    anchors.fill: parent
                                    visible: playbackController && playbackController.source !== "" && (!slideshow || slideshow.currentImagePath === "")
                                    source: previewPlayer
                                    fillMode: VideoOutput.PreserveAspectFit
                                }

                                MediaPlayer {
                                    id: previewPlayer
                                    autoPlay: false
                                    source: ""
                                }

                                // Mirror OutputWindow's wiring to PlaybackController
                                Connections {
                                    target: playbackController
                                    onSourceChanged: previewPlayer.source = playbackController.source
                                    onPlayRequested: previewPlayer.play()
                                    onPauseRequested: previewPlayer.pause()
                                    onStopRequested: previewPlayer.stop()
                                }
                            }
                        }
                    }

                    // Controls stacked below preview panel
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 90
                        radius: 6
                        color: panelColor
                        border.color: borderColor

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.bottomMargin: 12
                            spacing: 6

                            // First row: Add Media button
                            RowLayout {
                                Layout.fillWidth: true

                                Button {
                                    id: btnAdd
                                    text: "Add Media"
                                    Layout.preferredWidth: 120
                                    background: Rectangle {
                                        radius: 6
                                        implicitHeight: 32
                                        border.color: borderColor
                                        color: btnAdd.down || btnAdd.checked ? accentColor : btnAdd.hovered ? Qt.lighter(panelColor, 1.25) : panelColor
                                    }
                                    contentItem: Text {
                                        text: btnAdd.text
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    onClicked: {
                                        var files = controlBridge.openFileDialog();
                                        for (var i = 0; i < files.length; ++i) {
                                            mediaManager.addMedia(files[i]);
                                        }
                                    }

                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Add images or videos to the media list")
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            // Second row: blackout / brightness slider
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
