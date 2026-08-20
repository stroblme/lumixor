import QtQuick 2.12
import QtQuick.Layouts 1.12
import "." as Components

// Standard panel chrome: themed rounded rectangle wrapping a column of content.
Rectangle {
    id: control

    default property alias content: contentColumn.data
    property alias contentMargins: contentColumn.anchors.margins
    property alias contentSpacing: contentColumn.spacing

    radius: Components.Theme.borderRadius
    color: Components.Theme.panelColor
    border.color: Components.Theme.borderColor

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6
    }
}
