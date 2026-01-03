import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: root

    // Theme colors - passed from parent
    property color backgroundColor: "#121212"
    property color panelColor: "#1E1E1E"
    property color accentColor: "#42A5F5"
    property color textColor: "#E0E0E0"
    property color subtleTextColor: "#9E9E9E"
    property color borderColor: "#333333"

    // Preference values - should be bound to parent properties
    property int slideshowDelaySeconds: 5
    property int transitionDurationMs: 200
    property int outputScreenIndex: 1
    property bool loopSlideshows: true
    property bool loopVideos: true
    property int screenCount: 1

    // Signals
    signal slideshowDelayChanged(int value)
    signal transitionDurationChanged(int value)
    signal outputScreenIndexChanged(int value)
    signal loopSlideshowsChanged(bool enabled)
    signal loopVideosChanged(bool enabled)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

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
                    text: qsTr("Delay (s):")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSpinBox {
                    id: spinSlideshow
                    from: 1
                    to: 3600
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
                    onValueChanged: root.slideshowDelayChanged(value)
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
                    to: 10000
                    value: root.transitionDurationMs
                    stepSize: 50
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    bgColor: root.backgroundColor
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    txtColor: root.textColor
                    subtleTxtColor: root.subtleTextColor
                    borderCol: root.borderColor
                    onValueChanged: root.transitionDurationChanged(value)
                }

                Label {
                    text: qsTr("Loop slideshow:")
                    color: root.textColor
                    horizontalAlignment: Text.AlignLeft
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
                StyledSwitch {
                    id: switchLoopSlideshow
                    checked: root.loopSlideshows
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    panelCol: root.panelColor
                    accentCol: root.accentColor
                    borderCol: root.borderColor
                    onCheckedChanged: root.loopSlideshowsChanged(checked)
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
                    onCheckedChanged: root.loopVideosChanged(checked)
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("When enabled, video playback continues from first video after the last one")
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
                    onValueChanged: root.outputScreenIndexChanged(value)
                }

                Label {
                    text: qsTr("Available screens: %1").arg(root.screenCount)
                    color: root.subtleTextColor
                    font.pixelSize: 11
                    Layout.columnSpan: 2
                    Layout.alignment: Qt.AlignRight
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
