import QtQuick 2.12
import "." as Components

// Drag handle that resizes the panel to its right. It reports the requested width
// rather than assigning it, so the owner keeps control of the layout.
Rectangle {
    id: control

    // Coordinate space the drag is measured in (normally the window content item).
    property Item reference: null

    property real panelWidth: 0
    property real minimumWidth: 120
    property real maximumWidth: 10000

    signal widthDragged(real newWidth)

    width: 5
    color: Components.Theme.borderColor

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor

        property real dragStartX: 0
        property real startPanelWidth: 0
        property real pendingWidth: 0

        function referenceX(mouse) {
            return control.reference ? mapToItem(control.reference, mouse.x, mouse.y).x : mouse.x;
        }

        onPressed: function (mouse) {
            dragStartX = referenceX(mouse);
            startPanelWidth = control.panelWidth;
            pendingWidth = startPanelWidth;
        }

        onPositionChanged: function (mouse) {
            if (!pressed)
                return;
            // Moving left widens the panel on the right, and vice versa. The halved
            // delta is the original drag ratio, kept so the handle still feels the same.
            var mouseDelta = referenceX(mouse) - dragStartX;
            pendingWidth = Math.max(control.minimumWidth,
                                    Math.min(control.maximumWidth, startPanelWidth - mouseDelta / 2));
        }

        onReleased: control.widthDragged(pendingWidth)
    }

    // Throttle the live updates while dragging rather than relayouting per mouse event.
    Timer {
        interval: 16 // ~60 fps
        repeat: true
        running: dragArea.pressed
        onTriggered: {
            if (Math.abs(control.panelWidth - dragArea.pendingWidth) > 1)
                control.widthDragged(dragArea.pendingWidth);
        }
    }
}
