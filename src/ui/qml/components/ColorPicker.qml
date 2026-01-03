import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Item {
    id: root

    property color selectedColor: "#42A5F5"
    property color panelColor: "#1E1E1E"
    property color textColor: "#E0E0E0"
    property color borderColor: "#333333"

    signal colorChanged(color newColor)

    implicitWidth: 200
    implicitHeight: 40

    // Predefined accent colors
    readonly property var presetColors: ["#42A5F5" // Blue (default)
        , "#66BB6A" // Green
        , "#FFA726" // Orange
        , "#EF5350" // Red
        , "#AB47BC" // Purple
        , "#26C6DA" // Cyan
        , "#FFEE58" // Yellow
        , "#EC407A" // Pink
        , "#78909C" // Blue Grey
        , "#8D6E63"  // Brown
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 4

        // Color preview with current selection
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 4
            color: root.selectedColor
            border.color: root.borderColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: colorPopup.open()
            }
        }

        // Hex color display
        TextField {
            id: hexInput
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            text: root.selectedColor.toString().toUpperCase()
            font.pixelSize: 12
            font.family: "monospace"
            horizontalAlignment: Text.AlignHCenter
            selectByMouse: true

            background: Rectangle {
                radius: 4
                color: Qt.darker(root.panelColor, 1.2)
                border.color: hexInput.activeFocus ? root.selectedColor : root.borderColor
            }

            color: root.textColor

            validator: RegExpValidator {
                regExp: /^#[0-9A-Fa-f]{6}$/
            }

            onEditingFinished: {
                if (acceptableInput) {
                    root.selectedColor = text;
                    root.colorChanged(root.selectedColor);
                }
            }
        }

        // Dropdown button
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 4
            color: dropdownMouse.containsMouse ? Qt.lighter(root.panelColor, 1.3) : root.panelColor
            border.color: root.borderColor

            Text {
                anchors.centerIn: parent
                text: "▼"
                color: root.textColor
                font.pixelSize: 10
            }

            MouseArea {
                id: dropdownMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: colorPopup.open()
            }
        }
    }

    Popup {
        id: colorPopup
        x: 0
        y: parent.height + 4
        width: 220
        height: 120
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.panelColor
            border.color: root.borderColor
            radius: 6
        }

        contentItem: ColumnLayout {
            spacing: 8

            Label {
                text: qsTr("Select Accent Color")
                color: root.textColor
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            GridLayout {
                columns: 5
                rowSpacing: 4
                columnSpacing: 4
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.presetColors

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 4
                        color: modelData
                        border.color: root.selectedColor.toString().toUpperCase() === modelData.toUpperCase() ? root.textColor : root.borderColor
                        border.width: root.selectedColor.toString().toUpperCase() === modelData.toUpperCase() ? 2 : 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.selectedColor = modelData;
                                root.colorChanged(root.selectedColor);
                                colorPopup.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
