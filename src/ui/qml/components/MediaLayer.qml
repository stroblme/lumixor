import QtQuick 2.12
import QtMultimedia 5.15

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

    visible: true

    // Handle seek requests
    onLayerSeekPositionChanged: {
        if (layerSeekPosition >= 0 && layerType === "video") {
            console.log("MediaLayer[" + layerTabId + "] seeking to: " + layerSeekPosition);
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
        source: root.layerType === "slideshow" && root.layerPath !== "" ? root.imageUrlForPath(root.layerPath) : ""
        opacity: root.layerBrightness

        onSourceChanged: {
            console.log("MediaLayer image source: " + source + ", visible=" + visible + ", brightness=" + root.layerBrightness);
        }
    }

    // Video display (for video type)
    MediaPlayer {
        id: layerPlayer
        autoPlay: false
        source: root.layerType === "video" && root.layerPath !== "" ? root.urlForPath(root.layerPath) : ""
        volume: root.layerVolume

        property bool pendingAutoPlay: false

        onSourceChanged: {
            console.log("MediaLayer MediaPlayer source changed: " + source + ", layerPlaying=" + root.layerPlaying);
            if (source !== "" && root.layerPlaying) {
                pendingAutoPlay = true;
            }
        }

        onStatusChanged: {
            console.log("MediaLayer MediaPlayer status changed: " + status + ", pendingAutoPlay=" + pendingAutoPlay);
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
            console.log("MediaLayer video visible: " + visible + ", path=" + root.layerPath);
        }
    }

    onLayerPlayingChanged: {
        if (layerType === "video") {
            console.log("MediaLayer[" + layerTabId + "] playing changed: " + layerPlaying + ", path=" + layerPath);
            if (layerPlaying && layerPath !== "") {
                layerPlayer.play();
            } else {
                layerPlayer.pause();
            }
        }
    }

    onLayerPathChanged: {
        console.log("MediaLayer[" + layerTabId + "] path changed: " + layerPath + ", type=" + layerType);
        if (layerType === "video") {
            if (layerPath !== "" && layerPlaying) {
                layerPlayer.play();
            } else if (layerPath === "") {
                layerPlayer.stop();
            }
        }
    }

    onLayerBrightnessChanged: {
        console.log("MediaLayer[" + layerTabId + "] brightness changed: " + layerBrightness);
    }

    Component.onCompleted: {
        console.log("MediaLayer[" + layerTabId + "] created: type=" + layerType + ", path=" + layerPath + ", brightness=" + layerBrightness);
        if (layerType === "video" && layerPlaying && layerPath !== "") {
            layerPlayer.play();
        }
    }
}
