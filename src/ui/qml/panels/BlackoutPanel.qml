import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

// Master brightness for the output window. outputWindow is a global context property.
Components.Panel {
    contentSpacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Components.SectionLabel {
            text: qsTr("Blackout")
            Layout.alignment: Qt.AlignVCenter
        }

        Components.StyledSlider {
            id: brightnessSlider
            from: 0.0
            to: 1.0
            value: 1.0
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            ToolTip.visible: hovered || pressed
            ToolTip.text: qsTr("Brightness: ") + Math.round(value * 100) + "%"

            // Only the real output dims; the embedded preview stays visible.
            onValueChanged: {
                if (outputWindow)
                    outputWindow.setBrightness(value);
            }
        }

        Components.SectionLabel {
            text: Math.round(brightnessSlider.value * 100) + "%"
            Layout.preferredWidth: 45
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 4
    }
}
