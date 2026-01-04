import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Item {
    id: control

    property color selectedColor: "#42A5F5"
    property color panelColor: "#1E1E1E"
    property color textColor: "#E0E0E0"
    property color borderColor: "#333333"

    signal colorChanged(color newColor)

    implicitHeight: 32
    implicitWidth: 200

    // Preset colors
    property var presetColors: ["#42A5F5"  // Blue (default)
        , "#66BB6A"  // Green
        , "#FFA726"  // Orange
        , "#EF5350"  // Red
        , "#AB47BC"  // Purple
        , "#26C6DA"  // Cyan
        , "#FFEE58"  // Yellow
        , "#EC407A"  // Pink
        , "#78909C"  // Blue Grey
        , "#8D6E63"   // Brown
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: control.presetColors

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: modelData
                border.color: control.selectedColor === modelData ? Qt.lighter(modelData, 1.5) : control.borderColor
                border.width: control.selectedColor === modelData ? 3 : 1

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
