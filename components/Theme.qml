pragma Singleton
import QtQuick

QtObject {
    readonly property bool sky: backend.themeName === "white-sky"
    readonly property bool light: backend.themeName === "white" || sky

    readonly property color accent: sky ? "#1E73E7" : (light ? "#467B9D" : "#875A82")
    readonly property color accentText: "#FFFFFF"
    readonly property color text: sky ? "#174269" : (light ? "#263B4C" : "#FFFFFF")
    readonly property color mutedText: Qt.alpha(text, light ? 0.68 : 0.74)

    readonly property color cardSurface: sky ? "#FCFDFF" : (light ? "#FAFCFD" : "#28202D")
    readonly property color panelSurface: cardSurface
    readonly property color managerSurface: cardSurface
    readonly property color barSurface: cardSurface
    readonly property color control: sky ? "#EAF4FF" : (light ? "#EAF1F5" : "#3A2E40")
    readonly property color controlHover: sky ? "#DCEEFF" : (light ? "#DDEAF0" : "#49394E")
    readonly property color selected: sky ? "#DCEEFF" : (light ? "#DCEAF1" : "#49394E")
    readonly property color selectedStrong: accent
    readonly property color track: sky ? "#D1E7FA" : (light ? "#D3E2EA" : "#514158")

    readonly property color heroSurface: accent
    readonly property color heroText: "#FFFFFF"
    readonly property color heroMutedText: Qt.rgba(1, 1, 1, 0.78)
    readonly property color heroControl: Qt.rgba(1, 1, 1, 0.16)
    readonly property color heroControlHover: Qt.rgba(1, 1, 1, 0.24)

    readonly property color clockAccent: accent
    readonly property color checkedText: accent
}
