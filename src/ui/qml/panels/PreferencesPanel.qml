import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

Item {
    id: root

    // Settings are read from and written to PreferencesController directly, so there
    // is no second copy of any value or default in the UI layer.
    readonly property int screenCount: outputWindow ? outputWindow.screenCount : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Components.StyledGroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            title: qsTr("Slideshow")

            GridLayout {
                anchors.fill: parent
                anchors.margins: 16
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: qsTr("Delay (seconds):")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.StyledSpinBox {
                    id: spinSlideshowDelay
                    from: 1
                    to: 60
                    value: preferences.slideshowIntervalSeconds
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    onValueChanged: preferences.slideshowIntervalSeconds = value
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Time to display each image before advancing")
                }

                Label {
                    text: qsTr("Transition (ms):")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.StyledSpinBox {
                    id: spinTransition
                    from: 0
                    to: 2000
                    stepSize: 50
                    value: preferences.transitionDurationMs
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    onValueChanged: preferences.transitionDurationMs = value
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Duration of crossfade between images")
                }

                Label {
                    text: qsTr("Loop slideshow:")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.StyledSwitch {
                    id: switchLoopSlideshows
                    checked: preferences.loopSlideshows
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.bottomMargin: 8
                    onCheckedChanged: preferences.loopSlideshows = checked
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, slideshow continues from first image after the last one")
                }
            }
        }

        Components.StyledGroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            title: qsTr("Video")

            GridLayout {
                anchors.fill: parent
                anchors.margins: 16
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: qsTr("Loop video list:")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.StyledSwitch {
                    id: switchLoopVideos
                    checked: preferences.loopVideos
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    onCheckedChanged: preferences.loopVideos = checked
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, video playback continues from first video after the last one")
                }

                Label {
                    text: qsTr("Autoplay next video:")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.StyledSwitch {
                    id: switchAutoPlayNextVideo
                    checked: preferences.autoPlayNextVideo
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.bottomMargin: 8
                    onCheckedChanged: preferences.autoPlayNextVideo = checked
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, the next video in the list will automatically start playing after the current video")
                }
            }
        }

        Components.StyledGroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            title: qsTr("Output")

            GridLayout {
                anchors.fill: parent
                anchors.margins: 16
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: qsTr("Screen index:")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.StyledSpinBox {
                    id: spinScreenIndex
                    from: 0
                    to: Math.max(0, root.screenCount - 1)
                    value: preferences.outputScreenIndex
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    onValueChanged: preferences.outputScreenIndex = value
                }

                Label {
                    text: qsTr("Available screens: %1").arg(root.screenCount)
                    color: Components.Theme.subtleTextColor
                    font.pixelSize: Components.Theme.fontSize
                    Layout.columnSpan: 2
                    Layout.alignment: Qt.AlignRight
                    Layout.bottomMargin: 8
                }
            }
        }

        Components.StyledGroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            title: qsTr("Appearance")

            GridLayout {
                anchors.fill: parent
                anchors.margins: 16
                columns: 2
                columnSpacing: 16
                rowSpacing: 12

                Label {
                    text: qsTr("Accent Color:")
                    color: Components.Theme.textColor
                    font.pixelSize: Components.Theme.fontSize
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                Components.ColorPicker {
                    id: accentColorPicker
                    selectedColor: preferences.accentColor
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 280
                    onColorChanged: preferences.accentColor = newColor.toString()
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
