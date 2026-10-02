pragma Singleton
import QtQuick

QtObject {
    readonly property bool light: backend.themeName === "white"

    readonly property color cardSurface: light ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0.22, 0.17, 0.25, 0.84)
    readonly property color panelSurface: light ? Qt.rgba(1, 1, 1, 0.97) : Qt.rgba(0.08, 0.06, 0.11, 0.92)
    readonly property color managerSurface: light ? Qt.rgba(1, 1, 1, 0.97) : Qt.rgba(0.08, 0.06, 0.11, 0.90)
    readonly property color barSurface: light ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0.08, 0.06, 0.11, 0.86)
    readonly property color cardBorder: light ? Qt.rgba(0.30, 0.48, 0.62, 0.23) : Qt.rgba(1, 1, 1, 0.24)
    readonly property color panelBorder: light ? Qt.rgba(0.30, 0.48, 0.62, 0.22) : Qt.rgba(1, 1, 1, 0.18)
    readonly property color barBorder: light ? Qt.rgba(0.30, 0.48, 0.62, 0.22) : Qt.rgba(1, 1, 1, 0.20)
    readonly property color text: light ? "#263B4C" : "#FFFFFF"
    readonly property color mutedText: Qt.alpha(text, light ? 0.68 : 0.75)
    readonly property color accent: light ? "#467B9D" : "#F3A5CD"
    readonly property color accentText: light ? "#FFFFFF" : "#6D4F6B"
    readonly property color clockAccent: light ? "#467B9D" : "#FFD76A"
    readonly property color checkedText: light ? "#467B9D" : "#F0B4D1"
    readonly property color control: light ? Qt.rgba(0.30, 0.48, 0.62, 0.09) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color controlHover: light ? Qt.rgba(0.30, 0.48, 0.62, 0.16) : Qt.rgba(1, 1, 1, 0.14)
    readonly property color controlBorder: light ? Qt.rgba(0.30, 0.48, 0.62, 0.15) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color selected: light ? Qt.rgba(0.30, 0.53, 0.66, 0.18) : Qt.rgba(0.95, 0.65, 0.80, 0.18)
    readonly property color selectedBorder: light ? Qt.rgba(0.30, 0.53, 0.66, 0.36) : Qt.rgba(0.95, 0.65, 0.80, 0.34)
    readonly property color selectedStrong: light ? "#467B9D" : Qt.rgba(0.95, 0.65, 0.80, 0.88)
    readonly property color track: light ? Qt.rgba(0.30, 0.48, 0.62, 0.16) : Qt.rgba(1, 1, 1, 0.15)
}
