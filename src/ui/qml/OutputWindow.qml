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

    function urlForPath(p) {
        // Generic url helper: if path is absolute file path, convert to file:// URL
        if (!p) return ""
        if (p.indexOf(":/") !== -1) return p // already has a scheme
        if (p.startsWith("/")) return "file://" + p
        return p
    }

    function imageUrlForPath(p) {
        // Use image provider for local files so EXIF orientation is applied
        if (!p) return ""
        if (p.indexOf(":/") !== -1) return p
        if (p.startsWith("/")) return "image://exif/" + encodeURIComponent(p)
        return p
    }

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
        visible: false
        fillMode: VideoOutput.PreserveAspectFit
    }

    Image {
        id: imageItem
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        visible: false
        opacity: 1.0
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
        blackoutRect.opacity = 1.0 - level
        blackoutRect.visible = blackoutRect.opacity > 0.0
        // Do not pause the player here so video can continue playing under blackout
    }

    function setBlackout(enable) {
        // Preserve existing API: map boolean blackout to brightness levels
        setBrightness(enable ? 0.0 : 1.0)
        if (enable) {
            // For legacy blackout calls, keep previous behavior of pausing
            player.pause()
        }
    }

    function showVideo() {
        videoOutput.visible = true
        imageItem.visible = false
        blackoutRect.visible = false
        blackoutRect.opacity = 0.0
    }

    function showImage(path) {
        imageItem.source = imageUrlForPath(path)
        imageItem.opacity = 1.0
        imageItem.visible = true
        videoOutput.visible = false
        blackoutRect.visible = false
        blackoutRect.opacity = 0.0
    }

    function fadeToImage(path) {
        if (isFading) {
            pendingImage = imageUrlForPath(path)
            return
        }
        nextImage = imageUrlForPath(path)
        isFading = true
        crossFade.start()
    }

    SequentialAnimation {
        id: crossFade
        running: false
        NumberAnimation { target: imageItem; property: "opacity"; from: 1; to: 0; duration: 200 }
        ScriptAction { script: imageItem.source = root.nextImage }
        NumberAnimation { target: imageItem; property: "opacity"; from: 0; to: 1; duration: 200 }
        onStopped: {
            isFading = false
            if (pendingImage.length > 0) {
                var p = pendingImage; pendingImage = ""; nextImage = p; crossFade.start()
            }
            imageItem.visible = true
            videoOutput.visible = false
            blackoutRect.visible = false
        }
    }

    Connections {
        target: playbackController
        onSourceChanged: {
            player.source = playbackController.source
        }
        onPlayRequested: player.play()
        onPauseRequested: player.pause()
        onStopRequested: player.stop()
    }
}
