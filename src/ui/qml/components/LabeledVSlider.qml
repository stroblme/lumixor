import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "." as Components

// Vertical slider with a caption above and a percentage readout below.
ColumnLayout {
    id: control

    property string title: ""
    property real value: 1.0
    property string tooltipPrefix: ""

    // Mirrors the slider's own valueChanged, so programmatic updates propagate exactly
    // as they did when this was written inline.
    signal sliderMoved(real value)

    Layout.fillHeight: true
    Layout.preferredWidth: 45
    spacing: 8

    Components.SectionLabel {
        text: control.title
        Layout.alignment: Qt.AlignHCenter
    }

    Components.StyledSlider {
        orientation: Qt.Vertical
        from: 0.0
        to: 1.0
        value: control.value
        Layout.fillHeight: true
        Layout.preferredWidth: 36
        Layout.alignment: Qt.AlignHCenter
        ToolTip.visible: hovered || pressed
        ToolTip.text: control.tooltipPrefix + Math.round(value * 100) + "%"

        onValueChanged: control.sliderMoved(value)
    }

    Components.SectionLabel {
        text: Math.round(control.value * 100) + "%"
        Layout.alignment: Qt.AlignHCenter
    }
}
