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

    color: "#121212"

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
            label: Label { text: qsTr("Slideshow"); color: "#E0E0E0" }
            background: Rectangle {
                radius: 6
                color: "#1E1E1E"
                border.color: "#333333"
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Delay (s):")
                    color: "#E0E0E0"
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
                }

                Label {
                    text: qsTr("Transition (ms):")
                    color: "#E0E0E0"
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
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            title: qsTr("Output")
            label: Label { text: qsTr("Output"); color: "#E0E0E0" }
            background: Rectangle {
                radius: 6
                color: "#1E1E1E"
                border.color: "#333333"
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Screen index:")
                    color: "#E0E0E0"
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
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Button {
                text: qsTr("Cancel")
                onClicked: prefsRoot.close()
            }

            Button {
                id: btnSave
                text: qsTr("Save")
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
