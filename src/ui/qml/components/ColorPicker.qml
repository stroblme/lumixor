import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

Item {
    id: control

    property color selectedColor: "#78909C"
    property color panelColor: Components.Theme.panelColor
    property color textColor: Components.Theme.textColor
    property color borderColor: Components.Theme.borderColor

    signal colorChanged(color newColor)

    implicitHeight: Components.Theme.switchHeight
    implicitWidth: Math.round(Components.Theme.switchHeight * 8)

    // Preset colors
    property var presetColors: ["#78909C"  // Blue Grey (default)
        , "#66BB6A"  // Green
        , "#FFA726"  // Orange
        , "#EF5350"  // Red
        , "#AB47BC"  // Purple
        , "#42A5F5"  // Cyan
        , "#FFEE58"  // Yellow
        , "#EC407A"  // Pink
        , "#8D6E63"   // Brown
    ]

    Row {
        anchors.fill: parent
        spacing: Math.round(Components.Theme.spacing / 4)

        Repeater {
            model: control.presetColors

            Rectangle {
                width: Components.Theme.switchHeight
                height: Components.Theme.switchHeight
                radius: Components.Theme.switchHeight / 2
                color: modelData
                border.color: control.selectedColor === modelData ? Qt.lighter(modelData, 1.5) : control.borderColor
                border.width: control.selectedColor === modelData ? 2 : 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        control.selectedColor = modelData;
                        control.colorChanged(modelData);
                    }
                }
            }
        }
    }
}
