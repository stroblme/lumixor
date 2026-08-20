import QtQuick 2.12
import "../components" as Components

// Output preview: renders every media tab's current image or video at the output's
// aspect ratio, using the same MediaLayer the real output window uses so both stay
// visually identical. This is a view only: playback progress and playlist
// advancement are driven by the output window, not from here.
Item {
    id: previewContainer

    property var mediaTabsModel: null

    // Use 16:9 aspect ratio as default (common for presentations)
    property real outputAspect: 16 / 9

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
        border.color: Components.Theme.borderColor
        clip: true

        // Unified media layers from all tabs (both slideshow and video)
        Repeater {
            model: previewContainer.mediaTabsModel

            Item {
                anchors.fill: parent
                z: model.zOrder !== undefined ? model.zOrder : index

                Components.MediaLayer {
                    id: previewLayer
                    anchors.fill: parent

                    layerPath: model.currentPath ? model.currentPath : ""
                    layerBrightness: model.brightness !== undefined ? model.brightness : 1.0
                    layerPlaying: model.isPlaying ? model.isPlaying : false
                    layerTabId: model.tabId !== undefined ? model.tabId : -1
                    layerType: model.tabType ? model.tabType : "video"
                    layerSeekPosition: model.seekPosition !== undefined ? model.seekPosition : -1
                    layerIndex: index

                    // The preview is silent; only the output window carries audio.
                    layerVolume: 0

                    // Keeping the preview in step with a seek is a view concern; the
                    // model's seek request is cleared once it has been applied.
                    onSeekComplete: previewContainer.mediaTabsModel.setProperty(index, "seekPosition", -1)
                }

                // Outline of the real content, which is letterboxed inside the layer.
                Rectangle {
                    visible: previewLayer.contentReady
                    x: previewLayer.contentRect.x
                    y: previewLayer.contentRect.y
                    width: previewLayer.contentRect.width > 0 ? previewLayer.contentRect.width : parent.width
                    height: previewLayer.contentRect.height > 0 ? previewLayer.contentRect.height : parent.height
                    color: "transparent"
                    border.color: Components.Theme.accentColor
                    border.width: 2
                    radius: 2
                    z: 100
                }
            }
        }
    }
}
