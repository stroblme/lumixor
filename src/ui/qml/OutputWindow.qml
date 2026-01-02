import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtMultimedia 5.15

Window {
    id: root
    objectName: "outputRoot"
    visible: true
    width: 800
    height: 600
    color: "#000000"

    property bool isFading: false
    property string pendingImage: ""
    property string nextImage: ""
    property string activeMedia: "image" // "image" or "video" - tracks which was started last

    // Unified media layers model - supports both images and videos
    ListModel {
        id: mediaLayersModel
    }

    // Update or add a media layer (works for both slideshow/image and video)
    function setMediaLayer(tabId, mediaType, path, brightness, playing, zOrder) {
        console.log("OutputWindow.setMediaLayer: tabId=" + tabId + ", type=" + mediaType + ", path=" + path + ", brightness=" + brightness + ", playing=" + playing + ", zOrder=" + zOrder);

        // Find existing layer
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                // Use setProperty for each field to ensure proper reactivity
                mediaLayersModel.setProperty(i, "mediaType", mediaType);
                mediaLayersModel.setProperty(i, "path", path);
                mediaLayersModel.setProperty(i, "brightness", brightness);
                mediaLayersModel.setProperty(i, "playing", playing);
                if (zOrder !== undefined) {
                    mediaLayersModel.setProperty(i, "zOrder", zOrder);
                }
                console.log("OutputWindow: updated media layer " + tabId + " brightness=" + brightness);
                return;
            }
        }

        // Add new layer
        mediaLayersModel.append({
            tabId: tabId,
            mediaType: mediaType,
            path: path,
            brightness: brightness,
            playing: playing,
            zOrder: zOrder !== undefined ? zOrder : mediaLayersModel.count
        });
        console.log("OutputWindow: added media layer " + tabId + ", total: " + mediaLayersModel.count);
    }

    // Convenience function for video layers (backward compatibility)
    function setVideoLayer(tabId, path, brightness, playing, zOrder) {
        // Find existing to preserve zOrder if not provided
        var finalZOrder = zOrder;
        if (finalZOrder === undefined) {
            finalZOrder = 0;
            for (var i = 0; i < mediaLayersModel.count; i++) {
                if (mediaLayersModel.get(i).tabId === tabId) {
                    finalZOrder = mediaLayersModel.get(i).zOrder || 0;
                    break;
                }
            }
        }
        setMediaLayer(tabId, "video", path, brightness, playing, finalZOrder);
    }

    // Convenience function for image/slideshow layers
    function setImageLayer(tabId, path, brightness, zOrder) {
        setMediaLayer(tabId, "slideshow", path, brightness, false, zOrder);
    }

    // Set the z-order for a media layer
    function setMediaLayerZOrder(tabId, zOrder) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "zOrder", zOrder);
                console.log("OutputWindow: set zOrder for layer " + tabId + " to " + zOrder);
                return;
            }
        }
    }

    // Backward compatibility alias
    function setVideoLayerZOrder(tabId, zOrder) {
        setMediaLayerZOrder(tabId, zOrder);
    }

    // Remove a media layer
    function removeMediaLayer(tabId) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.remove(i);
                console.log("OutputWindow: removed layer " + tabId);
                return;
            }
        }
    }

    // Backward compatibility alias
    function removeVideoLayer(tabId) {
        removeMediaLayer(tabId);
    }

    // Update brightness for a media layer
    function setMediaLayerBrightness(tabId, brightness) {
        console.log("OutputWindow.setMediaLayerBrightness: tabId=" + tabId + ", brightness=" + brightness);
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "brightness", brightness);
                console.log("OutputWindow: updated brightness for layer " + tabId + " to " + brightness);
                return;
            }
        }
        console.log("OutputWindow: layer " + tabId + " not found for brightness update");
    }

    function urlForPath(p) {
        // Generic url helper: if path is absolute file path, convert to file:// URL
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p; // already has a scheme
        if (p.startsWith("/"))
            return "file://" + p;
        return p;
    }

    function imageUrlForPath(p) {
        // Use image provider for local files so EXIF orientation is applied
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p;
        if (p.startsWith("/"))
            return "image://exif/" + encodeURIComponent(p);
        return p;
    }

    // Legacy single player for backward compatibility (hidden, use media layers instead)
    MediaPlayer {
        id: player
        autoPlay: false
        onPlaybackStateChanged: {
            // Notify C++ that playback finished when the player stops
            if (playbackState === MediaPlayer.StoppedState) {
                if (playbackController && playbackController.notifyMediaFinished)
                    playbackController.notifyMediaFinished();
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        source: player
        visible: false  // Hidden - use dynamic media layers instead
        fillMode: VideoOutput.PreserveAspectFit
        opacity: 1.0
        z: 1
    }

    // Unified media layers container - handles both images and videos
    Item {
        id: mediaLayersContainer
        anchors.fill: parent
        z: 2

        Repeater {
            id: mediaLayerRepeater
            model: mediaLayersModel

            Item {
                id: mediaLayerItem
                anchors.fill: parent

                // Use zOrder from model for proper stacking (higher = on top)
                z: model.zOrder !== undefined ? model.zOrder : index

                // Access model properties directly for proper reactivity with ListModel
                property string layerPath: model.path ? model.path : ""
                property real layerBrightness: model.brightness !== undefined ? model.brightness : 1.0
                property bool layerPlaying: model.playing ? model.playing : false
                property int layerTabId: model.tabId !== undefined ? model.tabId : -1
                property string layerType: model.mediaType ? model.mediaType : "video"

                visible: true  // Always visible, let children handle visibility

                // Image display (for slideshow type)
                Image {
                    id: layerImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    visible: mediaLayerItem.layerType === "slideshow" && mediaLayerItem.layerPath !== ""
                    source: mediaLayerItem.layerType === "slideshow" && mediaLayerItem.layerPath !== "" ? root.imageUrlForPath(mediaLayerItem.layerPath) : ""
                    opacity: mediaLayerItem.layerBrightness

                    onSourceChanged: {
                        console.log("OutputWindow image layer source: " + source + ", visible=" + visible + ", brightness=" + mediaLayerItem.layerBrightness);
                    }
                }

                // Video display (for video type)
                MediaPlayer {
                    id: layerPlayer
                    autoPlay: false
                    source: mediaLayerItem.layerType === "video" && mediaLayerItem.layerPath !== "" ? root.urlForPath(mediaLayerItem.layerPath) : ""
                    loops: MediaPlayer.Infinite
                }

                VideoOutput {
                    id: layerVideoOutput
                    anchors.fill: parent
                    source: layerPlayer
                    fillMode: VideoOutput.PreserveAspectFit
                    opacity: mediaLayerItem.layerBrightness
                    visible: mediaLayerItem.layerType === "video" && mediaLayerItem.layerPath !== ""

                    onVisibleChanged: {
                        console.log("OutputWindow video layer visible: " + visible + ", path=" + mediaLayerItem.layerPath);
                    }
                }

                onLayerPlayingChanged: {
                    if (layerType === "video") {
                        console.log("OutputWindow layer[" + layerTabId + "] playing changed: " + layerPlaying + ", path=" + layerPath);
                        if (layerPlaying && layerPath !== "") {
                            layerPlayer.play();
                        } else {
                            layerPlayer.pause();
                        }
                    }
                }

                onLayerPathChanged: {
                    console.log("OutputWindow layer[" + layerTabId + "] path changed: " + layerPath + ", type=" + layerType);
                    if (layerType === "video" && layerPath !== "" && layerPlaying) {
                        layerPlayer.play();
                    }
                }

                onLayerBrightnessChanged: {
                    console.log("OutputWindow layer[" + layerTabId + "] brightness changed: " + layerBrightness);
                }

                Component.onCompleted: {
                    console.log("OutputWindow media layer[" + layerTabId + "] created: type=" + layerType + ", path=" + layerPath + ", brightness=" + layerBrightness);
                    if (layerType === "video" && layerPlaying && layerPath !== "") {
                        layerPlayer.play();
                    }
                }
            }
        }
    }

    // Legacy image item - hidden, kept for backward compatibility with fadeToImage
    Image {
        id: imageItem
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: false  // Hidden - using media layers instead
        opacity: 1.0
        z: 0
    }

    Rectangle {
        id: blackoutRect
        anchors.fill: parent
        color: "#000000"
        visible: false
        z: 1000
        opacity: 1.0
    }

    function setBrightness(level) {
        // level expected in [0, 1]; 0 = black, 1 = normal
        // Implemented as a black overlay with variable opacity
        blackoutRect.opacity = 1.0 - level;
        blackoutRect.visible = blackoutRect.opacity > 0.0;
        // Do not pause the player here so video can continue playing under blackout
    }

    function setImageBrightness(level) {
        // level expected in [0, 1]; 0 = fully transparent, 1 = fully opaque
        // Control the opacity of the image directly for cross-fade capability
        imageItem.opacity = level;
    }

    function setVideoBrightness(level) {
        // level expected in [0, 1]; 0 = fully transparent, 1 = fully opaque
        // Control the opacity of the legacy video output
        videoOutput.opacity = level;
    }

    function setBlackout(enable) {
        // Preserve existing API: map boolean blackout to brightness levels
        setBrightness(enable ? 0.0 : 1.0);
        if (enable) {
            // For legacy blackout calls, keep previous behavior of pausing
            player.pause();
        }
    }

    function showVideo() {
        activeMedia = "video";
        videoOutput.visible = true;
        imageItem.visible = true;
        blackoutRect.visible = false;
        blackoutRect.opacity = 0.0;
    }

    function showImage(path) {
        activeMedia = "image";
        imageItem.source = imageUrlForPath(path);
        imageItem.opacity = 1.0;
        imageItem.visible = true;
        videoOutput.visible = true;
        blackoutRect.visible = false;
        blackoutRect.opacity = 0.0;
    }

    function fadeToImage(path) {
        // Legacy function - disabled in favor of media layers system
        // The ControlWindow now handles image display via setImageLayer()
        // which provides proper z-ordering and brightness control
        console.log("fadeToImage called (legacy, ignored): " + path);
        return;

        // Original implementation (disabled):
        /*
        activeMedia = "image";
        if (isFading) {
            pendingImage = imageUrlForPath(path);
            return;
        }
        nextImage = imageUrlForPath(path);
        isFading = true;
        crossFade.start();
        */
    }

    SequentialAnimation {
        id: crossFade
        running: false
        NumberAnimation {
            target: imageItem
            property: "opacity"
            from: 1
            to: 0
            duration: 200
        }
        ScriptAction {
            script: imageItem.source = root.nextImage
        }
        NumberAnimation {
            target: imageItem
            property: "opacity"
            from: 0
            to: 1
            duration: 200
        }
        onStopped: {
            isFading = false;
            if (pendingImage.length > 0) {
                var p = pendingImage;
                pendingImage = "";
                nextImage = p;
                crossFade.start();
            }
            imageItem.visible = true;
            videoOutput.visible = true;
            blackoutRect.visible = false;
        }
    }

    Connections {
        target: playbackController
        onSourceChanged: {
            player.source = playbackController.source;
        }
        onPlayRequested: player.play()
        onPauseRequested: player.pause()
        onStopRequested: player.stop()
    }
}
