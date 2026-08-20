import QtQuick 2.12
import QtQuick.Layouts 1.12
import "../components" as Components

// Live audio spectrum with its on/off switch. audioAnalyzer is a global context property.
Components.Panel {
    contentSpacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Components.SectionLabel {
            text: qsTr("Spectrometer")
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }

        Components.StyledSwitch {
            id: spectrometerSwitch
            Layout.alignment: Qt.AlignVCenter

            onToggled: audioAnalyzer.active = checked

            // A plain `checked:` binding would be destroyed the first time the user
            // clicks the switch, after which a failed capture start could no longer
            // switch it back off. A Binding element keeps re-applying the real state.
            Binding {
                target: spectrometerSwitch
                property: "checked"
                value: audioAnalyzer ? audioAnalyzer.active : false
            }
        }
    }

    Components.Spectrometer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 50
        spectrumData: audioAnalyzer ? audioAnalyzer.spectrum : []
        active: audioAnalyzer ? audioAnalyzer.active : false
    }

    Item {
        Layout.fillHeight: true
        Layout.preferredHeight: 4
    }
}
