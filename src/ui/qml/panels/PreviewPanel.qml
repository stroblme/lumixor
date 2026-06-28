import QtQuick 2.12
import QtMultimedia 5.15
import "../components" as Components

// Output preview: renders every media tab's current image/video layer at the
// output's aspect ratio, mirroring OutputWindow. Extracted from ControlWindow;
// outputWindow is a global QML context property.
Item {
    id: previewContainer

    property color accentColor: "#78909C"
    property color borderColor: "#333333"
    property var mediaTabsModel: null
    property bool autoPlayNextVideo: true
    property bool loopVideos: true

    // Use 16:9 aspect ratio as default (common for presentations)
    property real outputAspect: 16 / 9

    function imageUrlForPath(p) {
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p;
        if (p.startsWith("/"))
            return "image://exif/" + encodeURIComponent(p);
        return p;
    }

Rectangle {
    id: previewFrame
    anchors.centerIn: parent
    // Fit within container while maintaining aspect ratio
    property real containerAspect: previewContainer.width / Math.max(1, previewContainer.height)
    property bool isHeightLimited: containerAspect > previewContainer.outputAspect

    width: Math.max(50, isHeightLimited ? previewContainer.height * previewContainer.outputAspect : previewContainer.width)
    height: Math.max(50, isHeightLimited ? previewContainer.height : previewContainer.width / previewContainer.outputAspect)
    radius: Components.Theme.borderRadius
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
                source: previewMediaItem.mediaType === "slideshow" && previewMediaItem.mediaPath !== "" ? previewContainer.imageUrlForPath(previewMediaItem.mediaPath) : ""
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
}
