import QtQuick 2.12
import QtQuick.Layouts 1.12
import "." as Components

// One media tab in the tab bar: name, close button and drag-to-reorder.
// Reordering is reported through moveRequested; this item never touches the model.
Components.StyledTabButton {
    id: control

    property int tabIndex: -1
    property string tabName: ""
    property int tabCount: 0

    // The Repeater holding the sibling tabs, used to shift them out of the way while
    // one is being dragged.
    property var siblings: null

    property real visualOffset: 0
    property bool beingDragged: false

    signal activated
    signal closeRequested
    signal moveRequested(int fromIndex, int toIndex)

    transform: Translate {
        x: control.visualOffset
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    states: [
        State {
            name: "dragging"
            when: control.beingDragged
            PropertyChanges {
                target: control
                z: 100
                opacity: 0.8
            }
        }
    ]

    transitions: [
        Transition {
            from: "*"
            to: "dragging"
            NumberAnimation {
                properties: "opacity"
                duration: 100
            }
        },
        Transition {
            from: "dragging"
            to: "*"
            NumberAnimation {
                properties: "opacity"
                duration: 100
            }
        }
    ]

    contentItem: RowLayout {
        spacing: 4

        Components.DragHandle {}

        Text {
            text: control.tabName
            font.pixelSize: Components.Theme.fontSize
            color: control.checked ? Components.Theme.textColor : Components.Theme.subtleTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            width: Components.Theme.iconSize
            height: Components.Theme.iconSize
            radius: Components.Theme.iconSize / 2
            color: closeMouseArea.containsMouse ? Qt.lighter(Components.Theme.panelColor, 1.5) : "transparent"
            Text {
                anchors.centerIn: parent
                text: "×"
                color: Components.Theme.subtleTextColor
                font.pixelSize: Components.Theme.fontSize
                font.bold: true
            }
            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: control.closeRequested()
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.rightMargin: 20 // Leave space for close button

        property real dragStartGlobalX: 0
        property bool isDragging: false
        property int targetIndex: -1

        onPressed: {
            var globalPos = mapToGlobal(mouse.x, mouse.y);
            dragStartGlobalX = globalPos.x;
            isDragging = false;
            targetIndex = control.tabIndex;
        }

        onPositionChanged: {
            if (!pressed)
                return;

            var totalDeltaX = mapToGlobal(mouse.x, mouse.y).x - dragStartGlobalX;

            if (!isDragging && Math.abs(totalDeltaX) > 10) {
                isDragging = true;
                control.beingDragged = true;
            }
            if (!isDragging)
                return;

            // The dragged tab follows the pointer 1:1; the others step aside.
            control.visualOffset = totalDeltaX;

            var tabWidth = control.width;
            var newTargetIndex = control.tabIndex + Math.round(totalDeltaX / tabWidth);
            newTargetIndex = Math.max(0, Math.min(control.tabCount - 1, newTargetIndex));

            if (newTargetIndex !== targetIndex) {
                targetIndex = newTargetIndex;
                shiftSiblings(control.tabIndex, targetIndex, tabWidth);
            }
        }

        onReleased: {
            if (!isDragging) {
                control.activated();
            } else {
                if (targetIndex !== control.tabIndex && targetIndex >= 0)
                    control.moveRequested(control.tabIndex, targetIndex);
                resetSiblings();
            }

            control.beingDragged = false;
            control.visualOffset = 0;
            isDragging = false;
            targetIndex = -1;
        }

        function shiftSiblings(draggedIndex, targetIdx, tabWidth) {
            if (!control.siblings)
                return;
            for (var i = 0; i < control.siblings.count; i++) {
                var tab = control.siblings.itemAt(i);
                if (!tab || i === draggedIndex)
                    continue;
                var offset = 0;
                if (draggedIndex < targetIdx && i > draggedIndex && i <= targetIdx)
                    offset = -tabWidth; // dragging right: tabs in between shift left
                else if (draggedIndex > targetIdx && i >= targetIdx && i < draggedIndex)
                    offset = tabWidth;  // dragging left: tabs in between shift right
                tab.visualOffset = offset;
            }
        }

        function resetSiblings() {
            if (!control.siblings)
                return;
            for (var i = 0; i < control.siblings.count; i++) {
                var tab = control.siblings.itemAt(i);
                if (tab)
                    tab.visualOffset = 0;
            }
        }
    }
}
