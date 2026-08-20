import QtQuick 2.12
import QtQuick.Window 2.12
import "components" as Components

Window {
    id: root
    objectName: "outputRoot"
    visible: true
    width: 800
    height: 600
    color: "#000000"

    // Unified media layers model - the single source of truth for the output.
    ListModel {
        id: mediaLayersModel
    }

    // === Media layer API (called from ControlWindow and OutputWindow.cpp) ===

    // Row of a layer by tab id, or -1. Every accessor below went through its own copy
    // of this scan.
    function indexOfLayer(tabId) {
        for (var i = 0; i < mediaLayersModel.count; i++) {
            if (mediaLayersModel.get(i).tabId === tabId)
                return i;
        }
        return -1;
    }

    function setLayerProperty(tabId, name, value) {
        var i = indexOfLayer(tabId);
        if (i >= 0)
            mediaLayersModel.setProperty(i, name, value);
    }

    // Update or add a media layer
    function setMediaLayer(tabId, mediaType, path, brightness, playing, zOrder) {
        var i = indexOfLayer(tabId);
        if (i >= 0) {
            mediaLayersModel.setProperty(i, "mediaType", mediaType);
            mediaLayersModel.setProperty(i, "path", path);
            mediaLayersModel.setProperty(i, "brightness", brightness);
            mediaLayersModel.setProperty(i, "playing", playing);
            if (zOrder !== undefined)
                mediaLayersModel.setProperty(i, "zOrder", zOrder);
            return;
        }

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
    }

    function setVideoLayer(tabId, path, brightness, playing, zOrder) {
        var finalZOrder = zOrder;
        if (finalZOrder === undefined) {
            var i = indexOfLayer(tabId);
            finalZOrder = i >= 0 ? (mediaLayersModel.get(i).zOrder || 0) : 0;
        }
        setMediaLayer(tabId, "video", path, brightness, playing, finalZOrder);
    }

    function setImageLayer(tabId, path, brightness, zOrder) {
        setMediaLayer(tabId, "slideshow", path, brightness, false, zOrder);
    }

    function setVideoLayerVolume(tabId, volume) {
        setLayerProperty(tabId, "volume", volume);
    }

    function setMediaLayerZOrder(tabId, zOrder) {
        setLayerProperty(tabId, "zOrder", zOrder);
    }

    function setMediaLayerBrightness(tabId, brightness) {
        setLayerProperty(tabId, "brightness", brightness);
    }

    function seekVideoLayer(tabId, position) {
        setLayerProperty(tabId, "seekPosition", position);
    }

    function removeMediaLayer(tabId) {
        var i = indexOfLayer(tabId);
        if (i >= 0)
            mediaLayersModel.remove(i);
    }

    function stopMediaLayer(tabId) {
        var i = indexOfLayer(tabId);
        if (i >= 0) {
            mediaLayersModel.setProperty(i, "playing", false);
            mediaLayersModel.setProperty(i, "path", "");
        }
    }

    // Unified media layers container
    Item {
        id: mediaLayersContainer
        anchors.fill: parent
        z: 2

        Repeater {
            id: mediaLayerRepeater
            model: mediaLayersModel

            Components.MediaLayer {
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

                onSeekComplete: mediaLayersModel.setProperty(index, "seekPosition", -1)

                // The output is the authoritative player, so it reports progress and
                // end-of-media back to the controls.
                onPositionChanged: outputWindow.notifyMediaPosition(layerTabId, position)
                onDurationChanged: outputWindow.notifyMediaDuration(layerTabId, duration)
                onMediaEnded: {
                    if (layerPlaying)
                        outputWindow.notifyMediaEnded(layerTabId);
                }
            }
        }
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

    // Escape hatch: never let a fullscreen output window trap the controls behind it.
    // F toggles fullscreen; Escape returns to a normal, movable window.
    Shortcut {
        sequence: "F"
        onActivated: root.visibility = (root.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }
    Shortcut {
        sequence: "Escape"
        onActivated: root.visibility = Window.Windowed
    }
}
