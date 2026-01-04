import QtQuick 2.12
import QtQuick.Controls 2.12

Item {
    id: control

    property color selectedColor: "#78909C"
    property color panelColor: "#1E1E1E"
    property color textColor: "#E0E0E0"
    property color borderColor: "#333333"

    signal colorChanged(color newColor)

    implicitHeight: 28
    implicitWidth: 220

    // Preset colors
    property var presetColors: ["#78909C"  // Blue (default)
        , "#66BB6A"  // Green
        , "#FFA726"  // Orange
        , "#EF5350"  // Red
        , "#AB47BC"  // Purple
        , "#42A5F5"  // Cyan
        , "#FFEE58"  // Yellow
        , "#EC407A"  // Pink
        , "#78909C"  // Blue Grey
        , "#8D6E63"   // Brown
    ]

    Row {
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: control.presetColors

            Rectangle {
                width: 20
                height: 20
                radius: 10
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
