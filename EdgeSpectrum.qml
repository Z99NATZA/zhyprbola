import QtQuick
import QtQuick.Window
import "components"

Window {
    id: edge

    readonly property string edgePosition: backend.edgeSpectrumPosition
    readonly property bool vertical: edgePosition === "left" || edgePosition === "right"
    readonly property int stripSize: 161
    readonly property int barLength: backend.edgeSpectrumSize === "sm" ? 54
        : backend.edgeSpectrumSize === "md" ? 108 : stripSize
    readonly property int screenWidth: edgeScreenWidth > 0
        ? edgeScreenWidth : Screen.width
    readonly property int screenHeight: edgeScreenHeight > 0
        ? edgeScreenHeight : Screen.height
    readonly property int edgeLength: vertical ? screenHeight : screenWidth

    visible: true
    width: vertical ? stripSize : screenWidth
    height: vertical ? screenHeight : stripSize
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "Zhyprbola Edge Spectrum"

    Item {
        x: (edge.width - width) / 2
        y: (edge.height - height) / 2
        width: edge.edgeLength
        height: edge.stripSize
        rotation: edge.edgePosition === "top" ? 180
            : edge.edgePosition === "left" ? 90
            : edge.edgePosition === "right" ? -90 : 0

        SpectrumBars {
            objectName: "edge-spectrum-bars"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: edge.barLength
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
}
