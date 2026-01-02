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

    // Multi-layer video support using ListModel for proper reactivity
    ListModel {
        id: videoLayersModel
    }

    // Update or add a video layer
    function setVideoLayer(tabId, path, brightness, playing) {
        console.log("OutputWindow.setVideoLayer: tabId=" + tabId + ", path=" + path + ", brightness=" + brightness + ", playing=" + playing);

        // Find existing layer
        for (var i = 0; i < videoLayersModel.count; i++) {
            if (videoLayersModel.get(i).tabId === tabId) {
                videoLayersModel.set(i, {
                    tabId: tabId,
                    path: path,
                    brightness: brightness,
                    playing: playing
                });
                console.log("OutputWindow: updated layer " + i + ", total layers: " + videoLayersModel.count);
                return;
            }
        }

        // Add new layer
        videoLayersModel.append({
            tabId: tabId,
            path: path,
            brightness: brightness,
            playing: playing
        });
        console.log("OutputWindow: added new layer, total layers: " + videoLayersModel.count);
    }

    // Remove a video layer
    function removeVideoLayer(tabId) {
        for (var i = 0; i < videoLayersModel.count; i++) {
            if (videoLayersModel.get(i).tabId === tabId) {
                videoLayersModel.remove(i);
                console.log("OutputWindow: removed layer " + tabId);
                return;
            }
        }
    }

    // Update brightness for a video layer (convenience function)
    function setVideoLayerBrightness(tabId, brightness) {
        for (var i = 0; i < videoLayersModel.count; i++) {
            var layer = videoLayersModel.get(i);
            if (layer.tabId === tabId) {
                videoLayersModel.setProperty(i, "brightness", brightness);
                return;
            }
        }
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

    // Legacy single player for backward compatibility (hidden, use video layers instead)
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
        visible: false  // Hidden - use dynamic video layers instead
        fillMode: VideoOutput.PreserveAspectFit
        opacity: 1.0
        z: 1
    }

    // Dynamic video layers container
    Item {
        id: videoLayersContainer
        anchors.fill: parent
        z: 2

        Repeater {
            id: videoLayerRepeater
            model: videoLayersModel

            Item {
                id: videoLayerItem
                anchors.fill: parent

                // Access model properties directly for proper reactivity with ListModel
                property string layerPath: model.path || ""
                property real layerBrightness: model.brightness !== undefined ? model.brightness : 1.0
                property bool layerPlaying: model.playing || false
                property int layerTabId: model.tabId || -1

                visible: layerPath !== ""

                MediaPlayer {
                    id: layerPlayer
                    autoPlay: false
                    source: videoLayerItem.layerPath !== "" ? root.urlForPath(videoLayerItem.layerPath) : ""
                    loops: MediaPlayer.Infinite
                }

                VideoOutput {
                    anchors.fill: parent
                    source: layerPlayer
                    fillMode: VideoOutput.PreserveAspectFit
                    opacity: videoLayerItem.layerBrightness
                    visible: videoLayerItem.layerPath !== ""
                }

                onLayerPlayingChanged: {
                    console.log("OutputWindow layer[" + layerTabId + "] playing changed: " + layerPlaying + ", path=" + layerPath);
                    if (layerPlaying && layerPath !== "") {
                        layerPlayer.play();
                    } else {
                        layerPlayer.pause();
                    }
                }

                onLayerPathChanged: {
                    console.log("OutputWindow layer[" + layerTabId + "] path changed: " + layerPath + ", playing=" + layerPlaying);
                    if (layerPath !== "" && layerPlaying) {
                        layerPlayer.play();
                    }
                }

                Component.onCompleted: {
                    console.log("OutputWindow video layer[" + layerTabId + "] created: path=" + layerPath + ", brightness=" + layerBrightness + ", playing=" + layerPlaying);
                    if (layerPlaying && layerPath !== "") {
                        layerPlayer.play();
                    }
                }
            }
        }
    }

    Image {
        id: imageItem
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: true
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
        activeMedia = "image";
        if (isFading) {
            pendingImage = imageUrlForPath(path);
            return;
        }
        nextImage = imageUrlForPath(path);
        isFading = true;
        crossFade.start();
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
