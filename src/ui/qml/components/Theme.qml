pragma Singleton
import QtQuick 2.12

QtObject {
    // Dark theme colors for the control UI
    readonly property color backgroundColor: "#121212"
    readonly property color panelColor: "#1E1E1E"
    readonly property color accentColor: "#78909C"
    readonly property color textColor: "#E0E0E0"
    readonly property color subtleTextColor: "#9E9E9E"
    readonly property color borderColor: "#333333"
    readonly property color listItemColor: "#232323"
    readonly property color listItemHighlight: "#29434E"

    // Global UI scaling factor (1.0 = 100%, 1.25 = 125%, etc.)
    // Adjust this value to scale the entire UI up or down
    readonly property real scaleFactor: 1.25

    // Base sizing constants (at scale factor 1.0)
    readonly property int baseButtonHeight: 44
    readonly property int baseButtonWidth: 44
    readonly property int baseFontSize: 14
    readonly property int baseFontSizeLarge: 16
    readonly property int baseIconSize: 18
    readonly property int baseSliderHandleSize: 28
    readonly property int baseSliderTrackHeight: 8
    readonly property int baseSpinBoxHeight: 36
    readonly property int baseSpinBoxWidth: 120
    readonly property int baseSpinBoxButtonWidth: 28
    readonly property int baseSwitchWidth: 48
    readonly property int baseSwitchHeight: 26
    readonly property int baseSwitchHandleSize: 18
    readonly property int baseTabButtonHeight: 40
    readonly property int baseTabButtonMinWidth: 100
    readonly property int baseListItemHeight: 40
    readonly property int baseBorderRadius: 6
    readonly property int baseSpacing: 10
    readonly property int baseMargins: 16

    // Scaled sizing constants (automatically calculated from scaleFactor)
    readonly property int buttonHeight: Math.round(baseButtonHeight * scaleFactor)
    readonly property int buttonWidth: Math.round(baseButtonWidth * scaleFactor)
    readonly property int fontSize: Math.round(baseFontSize * scaleFactor)
    readonly property int fontSizeLarge: Math.round(baseFontSizeLarge * scaleFactor)
    readonly property int iconSize: Math.round(baseIconSize * scaleFactor)
    readonly property int sliderHandleSize: Math.round(baseSliderHandleSize * scaleFactor)
    readonly property int sliderTrackHeight: Math.round(baseSliderTrackHeight * scaleFactor)
    readonly property int spinBoxHeight: Math.round(baseSpinBoxHeight * scaleFactor)
    readonly property int spinBoxWidth: Math.round(baseSpinBoxWidth * scaleFactor)
    readonly property int spinBoxButtonWidth: Math.round(baseSpinBoxButtonWidth * scaleFactor)
    readonly property int switchWidth: Math.round(baseSwitchWidth * scaleFactor)
    readonly property int switchHeight: Math.round(baseSwitchHeight * scaleFactor)
    readonly property int switchIndicatorWidth: Math.round(baseSwitchWidth * scaleFactor)
    readonly property int switchIndicatorHeight: Math.round(baseSwitchHeight * scaleFactor)
    readonly property int switchHandleSize: Math.round(baseSwitchHandleSize * scaleFactor)
    readonly property int tabButtonHeight: Math.round(baseTabButtonHeight * scaleFactor)
    readonly property int tabButtonMinWidth: Math.round(baseTabButtonMinWidth * scaleFactor)
    readonly property int listItemHeight: Math.round(baseListItemHeight * scaleFactor)
    readonly property int borderRadius: Math.round(baseBorderRadius * scaleFactor)
    readonly property int spacing: Math.round(baseSpacing * scaleFactor)
    readonly property int margins: Math.round(baseMargins * scaleFactor)
}
