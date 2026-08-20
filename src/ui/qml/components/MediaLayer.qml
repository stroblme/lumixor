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

    // Cap on the decoded size of a slideshow image, which bounds the texture the
    // render thread has to upload while it is also compositing video. It is a fixed
    // size rather than the item's own size so that resizing does not force a reload
    // and so that the output window and the control window's preview share one decode.
    readonly property size imageDecodeSize: Qt.size(3840, 2160)

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

    // Image display (for slideshow type). The source is set by layerImageNext once
    // that decode finished, which makes this assignment a pixmap cache hit.
    Image {
        id: layerImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize: root.imageDecodeSize
        visible: root.layerType === "slideshow" && root.layerPath !== ""
        opacity: root.layerBrightness
    }

    // Back buffer for the slideshow image. A synchronous decode runs on the GUI
    // thread, and the GStreamer video backend blocks until the GUI thread accepts
    // each frame, so it would stall playback for the length of the decode. Loading
    // asynchronously here keeps the visible image up until the new one is ready,
    // which a plain asynchronous Image does not do.
    Image {
        id: layerImageNext
        visible: false
        asynchronous: true
        // fillMode and sourceSize are both part of the pixmap cache key, so they must
        // match layerImage or the front buffer misses the cache and decodes again on
        // the GUI thread.
        fillMode: Image.PreserveAspectFit
        sourceSize: root.imageDecodeSize
        source: root.layerType === "slideshow" && root.layerPath !== "" ? Components.Utils.imageUrlForPath(root.layerPath) : ""
        // Null covers the cleared path, which releases the front buffer's texture.
        onStatusChanged: {
            if (status === Image.Ready || status === Image.Null)
                layerImage.source = source;
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
