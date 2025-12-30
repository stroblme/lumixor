import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Window {
    id: prefsRoot
    objectName: "preferencesRoot"
    visible: true
    modality: Qt.ApplicationModal
    title: qsTr("Preferences")

    width: 520
    height: 320
    minimumWidth: 480
    minimumHeight: 280

    // Dark theme colors (match ControlWindow)
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#42A5F5"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"

    color: backgroundColor

    // These are expected to be provided as context properties from C++
    property var preferences

    // Local bindings with safe defaults
    property int slideshowDelaySeconds: preferences ? preferences.slideshowIntervalSeconds : 5
    property int transitionDurationMs: preferences ? preferences.transitionDurationMs : 200
    property int outputScreenIndex: preferences ? preferences.outputScreenIndex : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        GroupBox {
            Layout.fillWidth: true
            title: qsTr("Slideshow")
            label: Label { text: qsTr("Slideshow"); color: textColor }
            background: Rectangle {
                radius: 6
                color: panelColor
                border.color: borderColor
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Delay (s):")
                    color: textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                SpinBox {
                    id: spinSlideshow
                    from: 1
                    to: 3600
                    value: prefsRoot.slideshowDelaySeconds
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.fillWidth: true
                    background: Rectangle {
                        radius: 4
                        color: backgroundColor
                        border.color: borderColor
                    }
                    contentItem: TextInput {
                        text: parent.displayText
                        font: parent.font
                        color: textColor
                        selectionColor: accentColor
                        selectedTextColor: backgroundColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                    }
                }

                Label {
                    text: qsTr("Transition (ms):")
                    color: textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                SpinBox {
                    id: spinTransition
                    from: 0
                    to: 10000
                    value: prefsRoot.transitionDurationMs
                    stepSize: 50
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.fillWidth: true
                    background: Rectangle {
                        radius: 4
                        color: backgroundColor
                        border.color: borderColor
                    }
                    contentItem: TextInput {
                        text: parent.displayText
                        font: parent.font
                        color: textColor
                        selectionColor: accentColor
                        selectedTextColor: backgroundColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                    }
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            title: qsTr("Output")
            label: Label { text: qsTr("Output"); color: textColor }
            background: Rectangle {
                radius: 6
                color: panelColor
                border.color: borderColor
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Screen index:")
                    color: textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                SpinBox {
                    id: spinScreenIndex
                    from: 0
                    to: 8
                    value: prefsRoot.outputScreenIndex
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.fillWidth: true
                    background: Rectangle {
                        radius: 4
                        color: backgroundColor
                        border.color: borderColor
                    }
                    contentItem: TextInput {
                        text: parent.displayText
                        font: parent.font
                        color: textColor
                        selectionColor: accentColor
                        selectedTextColor: backgroundColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        readOnly: !parent.editable
                        validator: parent.validator
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Button {
                text: qsTr("Cancel")
                background: Rectangle {
                    radius: 6
                    implicitHeight: 32
                    color: panelColor
                    border.color: borderColor
                }
                contentItem: Text {
                    text: parent.text
                    color: subtleTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: prefsRoot.close()
            }

            Button {
                id: btnSave
                text: qsTr("Save")
                background: Rectangle {
                    radius: 6
                    implicitHeight: 32
                    color: accentColor
                    border.color: borderColor
                }
                contentItem: Text {
                    text: parent.text
                    color: backgroundColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (!preferences)
                        return
                    preferences.slideshowIntervalSeconds = spinSlideshow.value
                    preferences.transitionDurationMs = spinTransition.value
                    preferences.outputScreenIndex = spinScreenIndex.value
                    preferences.save()
                    prefsRoot.close()
                }
            }
        }
    }
}
