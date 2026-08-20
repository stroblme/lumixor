import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "." as Components

Rectangle {
    id: root

    property var spectrumData: []
    property color barColor: Components.Theme.accentColor
    property color barGlowColor: Qt.lighter(barColor, 1.5)
    property color bgColor: "#000000"
    property bool active: false
    property real barSpacing: 2
    property bool showPeaks: true
    property real peakDecay: 0.02

    // Peak hold values
    property var peakValues: []

    color: bgColor
    radius: Components.Theme.borderRadius

    onSpectrumDataChanged: {
        // Initialize peak values if needed
        if (peakValues.length !== spectrumData.length) {
            var newPeaks = [];
            for (var i = 0; i < spectrumData.length; i++) {
                newPeaks.push(0);
            }
            peakValues = newPeaks;
        }

        // Update peaks
        var updatedPeaks = peakValues.slice();
        for (var j = 0; j < spectrumData.length; j++) {
            var val = spectrumData[j] || 0;
            if (val > updatedPeaks[j]) {
                updatedPeaks[j] = val;
            } else {
                updatedPeaks[j] = Math.max(0, updatedPeaks[j] - peakDecay);
            }
        }
        peakValues = updatedPeaks;

        canvas.requestPaint();
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 4

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var data = root.spectrumData;
            if (!data || data.length === 0)
                return;

            var bandCount = data.length;
            var barWidth = (width - (bandCount - 1) * root.barSpacing) / bandCount;

            for (var i = 0; i < bandCount; i++) {
                var value = data[i] || 0;
                var barHeight = value * height;
                var x = i * (barWidth + root.barSpacing);
                var y = height - barHeight;

                // Create gradient for bar
                var gradient = ctx.createLinearGradient(x, height, x, y);
                gradient.addColorStop(0, root.barColor);
                gradient.addColorStop(0.5, root.barGlowColor);
                gradient.addColorStop(1, Qt.lighter(root.barGlowColor, 1.3));

                ctx.fillStyle = gradient;
                ctx.fillRect(x, y, barWidth, barHeight);

                // Draw peak indicator
                if (root.showPeaks && root.peakValues.length > i) {
                    var peakY = height - (root.peakValues[i] * height);
                    ctx.fillStyle = "#EEEEEE";
                    ctx.fillRect(x, peakY - 2, barWidth, 2);
                }
            }
        }
    }
}
