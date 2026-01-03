import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtMultimedia 5.15
import "components"

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
    property string activeMedia: "image"

    // External media tabs model from ControlWindow - the single source of truth
    property var externalMediaTabsModel: null

    // Unified media layers model - used when external model is not set (backward compatibility)
    ListModel {
        id: mediaLayersModel
    }

    // Get the active model - prefer external model if set
    function getActiveModel() {
        return externalMediaTabsModel ? externalMediaTabsModel : mediaLayersModel;
    }

    // URL helpers
    function urlForPath(p) {
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p;
        if (p.startsWith("/"))
            return "file://" + p;
        return p;
    }

    function imageUrlForPath(p) {
        if (!p)
            return "";
        if (p.indexOf(":/") !== -1)
            return p;
        if (p.startsWith("/"))
            return "image://exif/" + encodeURIComponent(p);
        return p;
    }

    // === Public API ===

    function setExternalMediaTabsModel(model) {
        externalMediaTabsModel = model;
    }

    // Update or add a media layer
    function setMediaLayer(tabId, mediaType, path, brightness, playing, zOrder) {
        console.log("OutputWindow.setMediaLayer: tabId=" + tabId + ", type=" + mediaType + ", path=" + path + ", brightness=" + brightness + ", playing=" + playing + ", zOrder=" + zOrder);

        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "mediaType", mediaType);
                mediaLayersModel.setProperty(i, "path", path);
                mediaLayersModel.setProperty(i, "brightness", brightness);
                mediaLayersModel.setProperty(i, "playing", playing);
                if (zOrder !== undefined) {
                    mediaLayersModel.setProperty(i, "zOrder", zOrder);
                }
                return;
            }
        }

        // Add new layer
        mediaLayersModel.append({
            tabId: tabId,
            mediaType: mediaType,
            path: path,
            brightness: brightness,
            volume: 1.0,
            playing: playing,
            zOrder: zOrder !== undefined ? zOrder : mediaLayersModel.count,
            seekPosition: -1
        });
        console.log("OutputWindow: added media layer " + tabId + ", total: " + mediaLayersModel.count);
    }

    function setVideoLayerVolume(tabId, volume) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "volume", volume);
                console.log("OutputWindow: set volume for layer " + tabId + " to " + volume);
                return;
            }
        }
    }

    function setVideoLayer(tabId, path, brightness, playing, zOrder) {
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

    function setImageLayer(tabId, path, brightness, zOrder) {
        setMediaLayer(tabId, "slideshow", path, brightness, false, zOrder);
    }

    function setMediaLayerZOrder(tabId, zOrder) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "zOrder", zOrder);
                return;
            }
        }
    }

    function setVideoLayerZOrder(tabId, zOrder) {
        setMediaLayerZOrder(tabId, zOrder);
    }

    function removeMediaLayer(tabId) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.remove(i);
                console.log("OutputWindow: removed layer " + tabId);
                return;
            }
        }
    }

    function stopMediaLayer(tabId) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "playing", false);
                mediaLayersModel.setProperty(i, "path", "");
                console.log("OutputWindow: stopped and cleared layer " + tabId);
                return;
            }
        }
    }

    function seekVideoLayer(tabId, position) {
        console.log("OutputWindow.seekVideoLayer: tabId=" + tabId + ", position=" + position);
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "seekPosition", position);
                return;
            }
        }
    }

    function removeVideoLayer(tabId) {
        removeMediaLayer(tabId);
    }

    function setMediaLayerBrightness(tabId, brightness) {
        console.log("OutputWindow.setMediaLayerBrightness: tabId=" + tabId + ", brightness=" + brightness);
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId) {
                mediaLayersModel.setProperty(i, "brightness", brightness);
                return;
            }
        }
        console.log("OutputWindow: layer " + tabId + " not found for brightness update");
    }

    // Legacy single player for backward compatibility
    MediaPlayer {
        id: player
        autoPlay: false
        onPlaybackStateChanged: {
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
        visible: false
        fillMode: VideoOutput.PreserveAspectFit
        opacity: 1.0
        z: 1
    }

    // Unified media layers container
    Item {
        id: mediaLayersContainer
        anchors.fill: parent
        z: 2

        Repeater {
            id: mediaLayerRepeater
            model: mediaLayersModel

            MediaLayer {
                anchors.fill: parent
                z: model.zOrder !== undefined ? model.zOrder : index
                layerPath: model.path ? model.path : ""
                layerBrightness: model.brightness !== undefined ? model.brightness : 1.0
                layerVolume: model.volume !== undefined ? model.volume : 1.0
                layerPlaying: model.playing ? model.playing : false
                layerTabId: model.tabId !== undefined ? model.tabId : -1
                layerType: model.mediaType ? model.mediaType : "video"
                layerSeekPosition: model.seekPosition !== undefined ? model.seekPosition : -1
                layerIndex: index

                onSeekComplete: {
                    mediaLayersModel.setProperty(index, "seekPosition", -1);
                }
            }
        }
    }

    // Legacy image item - hidden
    Image {
        id: imageItem
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: false
        opacity: 1.0
        z: 0
    }

    // Blackout overlay
    Rectangle {
        id: blackoutRect
        anchors.fill: parent
        color: "#000000"
        visible: false
        z: 1000
        opacity: 1.0
    }

    // === Brightness/Blackout API ===

    function setBrightness(level) {
        blackoutRect.opacity = 1.0 - level;
        blackoutRect.visible = blackoutRect.opacity > 0.0;
    }

    function setImageBrightness(level) {
        imageItem.opacity = level;
    }

    function setVideoBrightness(level) {
        videoOutput.opacity = level;
    }

    function setBlackout(enable) {
        setBrightness(enable ? 0.0 : 1.0);
        if (enable) {
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
        console.log("fadeToImage called (legacy, ignored): " + path);
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
        onSourceChanged: player.source = playbackController.source
        onPlayRequested: player.play()
        onPauseRequested: player.pause()
        onStopRequested: player.stop()
    }
}
