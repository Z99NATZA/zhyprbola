import QtQuick
import QtQuick.Window
import "components"

Window {
    id: edge

    readonly property string edgePosition: backend.edgeSpectrumPosition
    readonly property bool vertical: edgePosition === "left" || edgePosition === "right"
    readonly property int stripSize: 161
    readonly property int bottomMargin: edgePosition === "bottom" ? 32 : 0
    readonly property int edgeLength: vertical ? Screen.height : Screen.width

    visible: true
    width: vertical ? stripSize : Screen.width
    height: vertical ? Screen.height : stripSize + bottomMargin
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "Zhyprbola Edge Spectrum"

    SpectrumBars {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -edge.bottomMargin / 2
        width: edge.edgeLength
        height: edge.stripSize
        rotation: edge.edgePosition === "top" ? 180
            : edge.edgePosition === "left" ? 90
            : edge.edgePosition === "right" ? -90 : 0
        barCount: Math.max(2, 2 * Math.floor((edge.edgeLength + 4) / 34))
        gap: 4
        flatBaseline: true
        minimumBarHeight: 6
        sensitivity: 1.35
        adaptiveSmoothing: true
        riseDuration: 45
        fallDuration: 100
        orientation: SpectrumBars.Inward
        barColor: Theme.accent
        barOpacity: 0.9
    }
}
