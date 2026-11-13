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
            // One Half Dark terminal colors: gray surfaces with light text. The
            // accent is the light gray foreground, so text on accent fills is dark.
            "one-half-gray": {
                surface: "#282C34", accent: "#ABB2BF", accentText: "#282C34",
                text: "#DCDFE4", control: "#323842", controlHover: "#3E4451",
                selected: "#5C6370", track: "#3E4451", line: "#4B5263", knob: "#DCDFE4",
                border: "#3E4451"
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
                accent: "#BE345F", text: "#4A293A", control: "#FBECF0",
                controlHover: "#F8D6E0", selected: "#ECB7C9", track: "#EAC9D5"
            }
        }
        const defaults = {
            surface: "#FAFCFD", accentText: "#FFFFFF", line: "#CFD7DC", knob: "#FFFFFF",
            border: ""
        }
        return Object.assign({}, defaults, colors[backend.themeName] || colors.current)
    }

    readonly property color accent: palette.accent
    readonly property color accentText: palette.accentText
    readonly property color text: palette.text
    readonly property color mutedText: Qt.alpha(text, 0.68)

    readonly property color cardSurface: palette.surface
    readonly property real componentOpacity: Math.max(0, Math.min(100,
        backend.componentOpacity)) / 100
    readonly property color componentSurface: Qt.alpha(cardSurface, componentOpacity)
    function componentSurfaceFor(componentKey) {
        return backend.opacityDisabledComponents.includes(componentKey)
            ? cardSurface : componentSurface
    }
    // Card outline like the terminal window frame; themes without one draw none.
    readonly property color cardBorder: palette.border || "transparent"
    readonly property int cardBorderWidth: palette.border ? 1 : 0
    readonly property color panelSurface: cardSurface
    readonly property color managerSurface: cardSurface
    readonly property color barSurface: cardSurface
    readonly property color control: palette.control
    readonly property color controlHover: palette.controlHover
    readonly property color selected: palette.selected
    readonly property color selectedStrong: accent
    readonly property color track: palette.track
    readonly property color secondary: track
    readonly property color line: palette.line
    // Toggle knob: accentText on the accent-filled (checked) track, knob otherwise.
    readonly property color knob: palette.knob
    function knobFor(checked) { return checked ? accentText : knob }

    readonly property color heroSurface: accent
    readonly property color heroText: accentText
    readonly property color heroMutedText: Qt.alpha(accentText, 0.78)
    readonly property color heroControl: Qt.alpha(accentText, 0.16)
    readonly property color heroControlHover: Qt.alpha(accentText, 0.24)

    readonly property color clockAccent: accent
    readonly property color checkedText: accent
}
