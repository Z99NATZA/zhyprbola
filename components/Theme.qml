pragma Singleton
import QtQuick

QtObject {
    readonly property bool sky: backend.themeName === "white-sky"
    readonly property bool light: backend.themeName === "white" || sky

    readonly property color cardSurface: sky ? "#FCFDFF" : (light ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0.22, 0.17, 0.25, 0.84))
    readonly property color panelSurface: sky ? "#FCFDFF" : (light ? Qt.rgba(1, 1, 1, 0.97) : Qt.rgba(0.08, 0.06, 0.11, 0.92))
    readonly property color managerSurface: sky ? "#FCFDFF" : (light ? Qt.rgba(1, 1, 1, 0.97) : Qt.rgba(0.08, 0.06, 0.11, 0.90))
    readonly property color barSurface: sky ? "#FCFDFF" : (light ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0.08, 0.06, 0.11, 0.86))
    readonly property color cardBorder: sky ? "#B9D8F3" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.23) : Qt.rgba(1, 1, 1, 0.24))
    readonly property color panelBorder: sky ? "#C6DFF5" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.22) : Qt.rgba(1, 1, 1, 0.18))
    readonly property color barBorder: sky ? "#C6DFF5" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.22) : Qt.rgba(1, 1, 1, 0.20))
    readonly property color text: sky ? "#174269" : (light ? "#263B4C" : "#FFFFFF")
    readonly property color mutedText: Qt.alpha(text, light ? 0.68 : 0.75)
    readonly property color accent: sky ? "#1E73E7" : (light ? "#467B9D" : "#F3A5CD")
    readonly property color accentText: light ? "#FFFFFF" : "#6D4F6B"
    readonly property color clockAccent: sky ? "#1E73E7" : (light ? "#467B9D" : "#FFD76A")
    readonly property color checkedText: sky ? "#1B66CA" : (light ? "#467B9D" : "#F0B4D1")
    readonly property color control: sky ? "#EAF4FF" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.09) : Qt.rgba(1, 1, 1, 0.08))
    readonly property color controlHover: sky ? "#DCEEFF" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.16) : Qt.rgba(1, 1, 1, 0.14))
    readonly property color controlBorder: sky ? "#C7DFF6" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.15) : Qt.rgba(1, 1, 1, 0.10))
    readonly property color selected: sky ? "#DCEEFF" : (light ? Qt.rgba(0.30, 0.53, 0.66, 0.18) : Qt.rgba(0.95, 0.65, 0.80, 0.18))
    readonly property color selectedBorder: sky ? "#A9D0F7" : (light ? Qt.rgba(0.30, 0.53, 0.66, 0.36) : Qt.rgba(0.95, 0.65, 0.80, 0.34))
    readonly property color selectedStrong: sky ? "#1E73E7" : (light ? "#467B9D" : Qt.rgba(0.95, 0.65, 0.80, 0.88))
    readonly property color track: sky ? "#D1E7FA" : (light ? Qt.rgba(0.30, 0.48, 0.62, 0.16) : Qt.rgba(1, 1, 1, 0.15))
}
