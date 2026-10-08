pragma Singleton
import QtQuick

QtObject {
    readonly property var palette: {
        const colors = {
            current: {
                accent: "#875A82", text: "#3F2B41", control: "#F2EAF2",
                controlHover: "#E9DDE9", selected: "#D3BDD1", track: "#E2D2E2"
            },
            white: {
                accent: "#467B9D", text: "#263B4C", control: "#EAF1F5",
                controlHover: "#DDEAF0", selected: "#BFD6E3", track: "#D3E2EA"
            },
            "white-sky": {
                accent: "#1E73E7", text: "#174269", control: "#EAF4FF",
                controlHover: "#DCEEFF", selected: "#B7D6FA", track: "#D1E7FA"
            },
            forest: {
                accent: "#477F6D", text: "#194C3C", control: "#E8F3EE",
                controlHover: "#D9EAE1", selected: "#B8D6C8", track: "#CFE3D8"
            },
            "one-half-gray": {
                accent: "#68717D", text: "#2D3640", control: "#ECEFF1",
                controlHover: "#E0E5E8", selected: "#C5CDD5", track: "#CFD7DC"
            },
            red: {
                accent: "#B83252", text: "#542437", control: "#FAE9EE",
                controlHover: "#F5DCE4", selected: "#EDBDCB", track: "#EECBD5"
            },
            "silver-dawn": {
                accent: "#6275A6", text: "#303B58", control: "#EDF0F8",
                controlHover: "#DFE5F2", selected: "#C3CDE5", track: "#D5DDEF"
            },
            mauve: {
                accent: "#C45478", text: "#623746", control: "#FBECEF",
                controlHover: "#F7DCE5", selected: "#EDBDCE", track: "#EBC2D0"
            }
        }
        return colors[backend.themeName] || colors.current
    }

    readonly property color accent: palette.accent
    readonly property color accentText: "#FFFFFF"
    readonly property color text: palette.text
    readonly property color mutedText: Qt.alpha(text, 0.68)

    readonly property color cardSurface: "#FAFCFD"
    readonly property color panelSurface: cardSurface
    readonly property color managerSurface: cardSurface
    readonly property color barSurface: cardSurface
    readonly property color control: palette.control
    readonly property color controlHover: palette.controlHover
    readonly property color selected: palette.selected
    readonly property color selectedStrong: accent
    readonly property color track: palette.track
    readonly property color secondary: track

    readonly property color heroSurface: accent
    readonly property color heroText: "#FFFFFF"
    readonly property color heroMutedText: Qt.rgba(1, 1, 1, 0.78)
    readonly property color heroControl: Qt.rgba(1, 1, 1, 0.16)
    readonly property color heroControlHover: Qt.rgba(1, 1, 1, 0.24)

    readonly property color clockAccent: accent
    readonly property color checkedText: accent
}
