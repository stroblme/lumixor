import QtQuick 2.12
import QtQuick.Controls 2.12
import "." as Components

// Bold heading used at the top of a panel or slider group.
Label {
    color: Components.Theme.textColor
    font.pixelSize: Components.Theme.fontSize
    font.bold: true
}
