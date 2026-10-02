pragma Singleton
import QtQuick

QtObject {
    readonly property bool mist: backend.themeName === "white"
    readonly property bool sky: backend.themeName === "white-sky"
    readonly property bool forest: backend.themeName === "forest"

    readonly property color accent: forest ? "#477F6D" : (sky ? "#1E73E7" : (mist ? "#467B9D" : "#875A82"))
    readonly property color accentText: "#FFFFFF"
    readonly property color text: forest ? "#194C3C" : (sky ? "#174269" : (mist ? "#263B4C" : "#3F2B41"))
    readonly property color mutedText: Qt.alpha(text, 0.68)

    readonly property color cardSurface: "#FAFCFD"
    readonly property color panelSurface: cardSurface
    readonly property color managerSurface: cardSurface
    readonly property color barSurface: cardSurface
    readonly property color control: forest ? "#E8F3EE" : (sky ? "#EAF4FF" : (mist ? "#EAF1F5" : "#F2EAF2"))
    readonly property color controlHover: forest ? "#D9EAE1" : (sky ? "#DCEEFF" : (mist ? "#DDEAF0" : "#E9DDE9"))
    readonly property color selected: forest ? "#D9EAE1" : (sky ? "#DCEEFF" : (mist ? "#DCEAF1" : "#E9DDE9"))
    readonly property color selectedStrong: accent
    readonly property color track: forest ? "#CFE3D8" : (sky ? "#D1E7FA" : (mist ? "#D3E2EA" : "#E2D2E2"))

    readonly property color heroSurface: accent
    readonly property color heroText: "#FFFFFF"
    readonly property color heroMutedText: Qt.rgba(1, 1, 1, 0.78)
    readonly property color heroControl: Qt.rgba(1, 1, 1, 0.16)
    readonly property color heroControlHover: Qt.rgba(1, 1, 1, 0.24)

    readonly property color clockAccent: accent
    readonly property color checkedText: accent
}
