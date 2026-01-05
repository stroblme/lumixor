import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: root

    // Theme colors - passed from parent
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#78909C"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"

    // Settings values - passed from parent
    property int slideshowDelaySeconds: 5
    property int transitionDurationMs: 200
    property int outputScreenIndex: 1
    property bool loopSlideshows: true
    property bool loopVideos: true
    property bool autoPlayNextVideo: true
    property int screenCount: 1
    property string prefAccentColor: "#78909C"
    property bool useCustomFilePicker: true

    // Signals to notify parent of changes (use unique names to avoid conflicts with auto-generated property change signals)
    signal slideshowDelayUpdated(int value)
    signal transitionDurationUpdated(int value)
    signal outputScreenIndexUpdated(int value)
    signal loopSlideshowsUpdated(bool enabled)
    signal loopVideosUpdated(bool enabled)
    signal autoPlayNextVideoUpdated(bool enabled)
    signal accentColorUpdated(string color)
    signal useCustomFilePickerUpdated(bool enabled)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        StyledGroupBox {
            Layout.fillWidth: true
            title: qsTr("Slideshow")
            panelCol: root.panelColor
            txtColor: root.textColor
            borderCol: root.borderColor

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Delay (seconds):")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSpinBox {
                    id: spinSlideshowDelay
                    from: 1
                    to: 60
                    value: root.slideshowDelaySeconds
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    bgColor: root.backgroundColor
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    txtColor: root.textColor
                    subtleTxtColor: root.subtleTextColor
                    borderCol: root.borderColor
                    onValueChanged: root.slideshowDelayUpdated(value)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Time to display each image before advancing")
                }

                Label {
                    text: qsTr("Transition (ms):")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSpinBox {
                    id: spinTransition
                    from: 0
                    to: 2000
                    stepSize: 50
                    value: root.transitionDurationMs
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    bgColor: root.backgroundColor
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    txtColor: root.textColor
                    subtleTxtColor: root.subtleTextColor
                    borderCol: root.borderColor
                    onValueChanged: root.transitionDurationUpdated(value)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Duration of crossfade between images")
                }

                Label {
                    text: qsTr("Loop slideshow:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSwitch {
                    id: switchLoopSlideshows
                    checked: root.loopSlideshows
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.bottomMargin: 8
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor
                    onCheckedChanged: root.loopSlideshowsUpdated(checked)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, slideshow continues from first image after the last one")
                }
            }
        }

        StyledGroupBox {
            Layout.fillWidth: true
            title: qsTr("Video")
            panelCol: root.panelColor
            txtColor: root.textColor
            borderCol: root.borderColor

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Loop video list:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSwitch {
                    id: switchLoopVideos
                    checked: root.loopVideos
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor
                    onCheckedChanged: root.loopVideosUpdated(checked)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, video playback continues from first video after the last one")
                }

                Label {
                    text: qsTr("Autoplay next video:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSwitch {
                    id: switchAutoPlayNextVideo
                    checked: root.autoPlayNextVideo
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.bottomMargin: 8
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor
                    onCheckedChanged: root.autoPlayNextVideoUpdated(checked)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, the next video in the list will automatically start playing after the current video")
                }
            }
        }

        StyledGroupBox {
            Layout.fillWidth: true
            title: qsTr("Output")
            panelCol: root.panelColor
            txtColor: root.textColor
            borderCol: root.borderColor

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Screen index:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSpinBox {
                    id: spinScreenIndex
                    from: 0
                    to: Math.max(0, root.screenCount - 1)
                    value: root.outputScreenIndex
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    bgColor: root.backgroundColor
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    txtColor: root.textColor
                    subtleTxtColor: root.subtleTextColor
                    borderCol: root.borderColor
                    onValueChanged: root.outputScreenIndexUpdated(value)
                }

                Label {
                    text: qsTr("Available screens: %1").arg(root.screenCount)
                    color: root.subtleTextColor
                    font.pixelSize: 14
                    Layout.columnSpan: 2
                    Layout.alignment: Qt.AlignRight
                    Layout.bottomMargin: 8
                }
            }
        }

        StyledGroupBox {
            Layout.fillWidth: true
            title: qsTr("Appearance")
            panelCol: root.panelColor
            txtColor: root.textColor
            borderCol: root.borderColor

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label {
                    text: qsTr("Accent Color:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                ColorPicker {
                    id: accentColorPicker
                    selectedColor: root.prefAccentColor
                    panelColor: root.panelColor
                    textColor: root.textColor
                    borderColor: root.borderColor
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 200
                    onColorChanged: root.accentColorUpdated(newColor.toString())
                }

                Label {
                    text: qsTr("Use custom file picker:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSwitch {
                    id: switchCustomFilePicker
                    checked: root.useCustomFilePicker
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor
                    onCheckedChanged: root.useCustomFilePickerUpdated(checked)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Use the custom dark-themed file picker instead of the native system dialog")
                }

                Label {
                    text: qsTr("Disable for native GTK/KDE dialogs")
                    color: root.subtleTextColor
                    font.pixelSize: 14
                    Layout.columnSpan: 2
                    Layout.alignment: Qt.AlignRight
                    Layout.bottomMargin: 8
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
