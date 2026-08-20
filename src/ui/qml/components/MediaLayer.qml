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

    // Rectangle actually covered by the image or video inside this layer, in layer
    // coordinates. An overlay can use it to outline the real content instead of the
    // full item, which is letterboxed by PreserveAspectFit.
    readonly property rect contentRect: layerType === "slideshow"
        ? Qt.rect((layerImage.width - layerImage.paintedWidth) / 2,
                  (layerImage.height - layerImage.paintedHeight) / 2,
                  layerImage.paintedWidth, layerImage.paintedHeight)
        : layerVideoOutput.contentRect

    // True once there is something painted for contentRect to describe.
    readonly property bool contentReady: layerType === "slideshow"
        ? (layerImage.visible && layerImage.status === Image.Ready)
        : (layerVideoOutput.visible && layerPlayer.status >= MediaPlayer.Loaded)

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

    Component.onCompleted: {
        if (layerType === "video" && layerPlaying && layerPath !== "") {
            layerPlayer.play();
        }
    }
}
