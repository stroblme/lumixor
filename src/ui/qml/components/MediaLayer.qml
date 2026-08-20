import QtQuick 2.12
import QtMultimedia 5.15
import "." as Components

Item {
    id: root

    // Model properties for this layer
    property string layerPath: ""
    property real layerBrightness: 1.0
    property real layerVolume: 1.0
    property bool layerPlaying: false
    property int layerTabId: -1
    property string layerType: "video"  // "video" or "slideshow"
    property int layerSeekPosition: -1
    property int layerIndex: 0

    // Output signal for seek position reset
    signal seekComplete(int index)

    // Signal for position/duration updates
    signal positionChanged(int position)
    signal durationChanged(int duration)
    signal mediaEnded

    visible: true

    // Handle seek requests
    onLayerSeekPositionChanged: {
        if (layerSeekPosition >= 0 && layerType === "video") {
            layerPlayer.seek(layerSeekPosition);
            root.seekComplete(layerIndex);
        }
    }

    // Image display (for slideshow type)
    Image {
        id: layerImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: root.layerType === "slideshow" && root.layerPath !== ""
        source: root.layerType === "slideshow" && root.layerPath !== "" ? Components.Utils.imageUrlForPath(root.layerPath) : ""
        opacity: root.layerBrightness

        onSourceChanged: {
        }
    }

    // Video display (for video type)
    MediaPlayer {
        id: layerPlayer
        autoPlay: false
        source: root.layerType === "video" && root.layerPath !== "" ? Components.Utils.urlForPath(root.layerPath) : ""
        volume: root.layerVolume

        property bool pendingAutoPlay: false

        onSourceChanged: {
            if (source !== "" && root.layerPlaying) {
                pendingAutoPlay = true;
            }
        }

        onStatusChanged: {
            if (status === MediaPlayer.Loaded && pendingAutoPlay && root.layerPlaying) {
                pendingAutoPlay = false;
                layerPlayer.play();
            }
            if (status === MediaPlayer.EndOfMedia) {
                root.mediaEnded();
            }
        }

        onPositionChanged: root.positionChanged(position)
        onDurationChanged: root.durationChanged(duration)
    }

    VideoOutput {
        id: layerVideoOutput
        anchors.fill: parent
        source: layerPlayer
        fillMode: VideoOutput.PreserveAspectFit
        opacity: root.layerBrightness
        visible: root.layerType === "video" && root.layerPath !== ""

        onVisibleChanged: {
        }
    }

    onLayerPlayingChanged: {
        if (layerType === "video") {
            if (layerPlaying && layerPath !== "") {
                layerPlayer.play();
            } else {
                layerPlayer.pause();
            }
        }
    }

    onLayerPathChanged: {
        if (layerType === "video") {
            if (layerPath !== "" && layerPlaying) {
                layerPlayer.play();
            } else if (layerPath === "") {
                layerPlayer.stop();
            }
        }
    }

    onLayerBrightnessChanged: {
    }

    Component.onCompleted: {
        if (layerType === "video" && layerPlaying && layerPath !== "") {
            layerPlayer.play();
        }
    }
}
