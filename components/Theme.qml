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
    // Opacity shown while a card's menu slider is being dragged ({key: 0-100}).
    // It stays in this process; the value is saved once when the drag ends.
    property var cardOpacityPreview: ({})
    function previewCardOpacity(componentKey, percent) {
        const preview = Object.assign({}, cardOpacityPreview)
        if (percent === undefined) delete preview[componentKey]
        else preview[componentKey] = percent
        cardOpacityPreview = preview
    }
    // 0-100: the card's own value (live preview, then saved) wins over Settings.
    function componentOpacityPercentFor(componentKey) {
        const preview = cardOpacityPreview[componentKey]
        if (preview !== undefined) return preview
        const own = (backend.cardOpacities || {})[componentKey]
        if (own !== undefined) return own
        return backend.opacityDisabledComponents.includes(componentKey)
            ? 100 : Math.round(componentOpacity * 100)
    }
    function componentSurfaceFor(componentKey) {
        return Qt.alpha(cardSurface,
            Math.max(0, Math.min(100, componentOpacityPercentFor(componentKey))) / 100)
    }
    // Card outline like the terminal window frame; themes without one draw none.
    readonly property color cardBorder: palette.border || "transparent"
    readonly property int cardBorderWidth: palette.border ? 1 : 0
    // Outline color for cards whose border is forced on in themes without one.
    readonly property color cardOutline: cardBorderWidth > 0 ? cardBorder : line
    // Per-card "Border: show | hide" override; unset follows the theme.
    function cardBorderVisible(componentKey) {
        const mode = backend.cardBorderModes[componentKey] || ""
        return mode === "show" || (mode !== "hide" && cardBorderWidth > 0)
    }
    function toggleCardBorder(componentKey) {
        backend.setCardBorderMode(componentKey,
            cardBorderVisible(componentKey) ? "hide" : "show")
    }
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
