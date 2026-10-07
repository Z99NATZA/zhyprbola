import QtQuick

Item {
    id: visualizer

    readonly property var settings: backend.keyVisualizerSettings
    readonly property int fontSize: settings.fontSize === "sm" ? 23
        : settings.fontSize === "lg" ? 38 : 30
    readonly property int defaultPadding: settings.fontSize === "lg" ? 24 : 20
    readonly property int padding: settings.padding === "sm" ? 4
        : defaultPadding + (settings.padding === "lg" ? 12 : 0)
    readonly property int defaultHeight: settings.fontSize === "sm" ? 64
        : settings.fontSize === "lg" ? 96 : 78
    property var history: []
    readonly property string displayText: history.join(" ")
    readonly property string styledText: history.map(token =>
        styledToken(token, Theme.accent.toString())).join(" ")
    implicitWidth: settings.widthMode === "fixed" ? settings.maxWidth
        : Math.max(settings.minWidth,
            Math.min(settings.maxWidth, measure.implicitWidth + padding * 2))
    implicitHeight: settings.padding === "sm" ? Math.ceil(measure.implicitHeight) + 8
        : defaultHeight + (settings.padding === "lg" ? 24 : 0)
    focus: true

    function symbolFor(key) {
        switch (key) {
        case Qt.Key_Space: return "␣"
        case Qt.Key_Backspace: return "⌫"
        case Qt.Key_Return:
        case Qt.Key_Enter: return "↵"
        case Qt.Key_Tab: return "⇥"
        case Qt.Key_Escape: return "Esc"
        case Qt.Key_Delete: return "⌦"
        case Qt.Key_Left: return "←"
        case Qt.Key_Right: return "→"
        case Qt.Key_Up: return "↑"
        case Qt.Key_Down: return "↓"
        case Qt.Key_Home: return "Home"
        case Qt.Key_End: return "End"
        case Qt.Key_PageUp: return "PgUp"
        case Qt.Key_PageDown: return "PgDn"
        default: return ""
        }
    }

    function appendKey(value) {
        if (!value) return
        const next = history.concat(value)
        history = next.length > 48 ? next.slice(-48) : next
        clearTimer.restart()
    }

    function escapeText(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function styledToken(value, accent) {
        let remaining = value
        let result = ""
        let modifier = /^(Ctrl|Alt|Super|Shift)\+/.exec(remaining)
        while (modifier) {
            const prefix = modifier[0]
            result += '<font color="' + accent + '">' + prefix + '</font>'
            remaining = remaining.slice(prefix.length)
            modifier = /^(Ctrl|Alt|Super|Shift)\+/.exec(remaining)
        }
        const key = escapeText(remaining)
        const special = ["␣", "⌫", "↵", "⇥", "Esc", "⌦", "←", "→",
            "↑", "↓", "Home", "End", "PgUp", "PgDn"].includes(remaining)
        return result + (special ? '<font color="' + accent + '">' + key + '</font>' : key)
    }

    function symbolForGlobal(name) {
        switch (name) {
        case "space": return "␣"
        case "BackSpace": return "⌫"
        case "Return":
        case "KP_Enter": return "↵"
        case "Tab":
        case "ISO_Left_Tab": return "⇥"
        case "Escape": return "Esc"
        case "Delete": return "⌦"
        case "Left": return "←"
        case "Right": return "→"
        case "Up": return "↑"
        case "Down": return "↓"
        case "Home": return "Home"
        case "End": return "End"
        case "Page_Up": return "PgUp"
        case "Page_Down": return "PgDn"
        default: return ""
        }
    }

    function appendFormattedKey(key, hasCtrl, hasShift, hasAlt, hasSuper) {
        if (hasCtrl && /^[a-z]$/i.test(key))
            key = hasShift ? key.toUpperCase() : key.toLowerCase()
        const prefix = []
        if (hasCtrl) prefix.push("Ctrl")
        if (hasAlt) prefix.push("Alt")
        if (hasSuper) prefix.push("Super")
        appendKey(prefix.length ? prefix.join("+") + "+" + key : key)
    }

    function globalPress(name, text, hasShift, hasCtrl, hasAlt, hasSuper) {
        if (name === "Shift_L" || name === "Shift_R"
            || name === "Control_L" || name === "Control_R"
            || name === "Alt_L" || name === "Alt_R"
            || name === "Super_L" || name === "Super_R"
            || name === "Meta_L" || name === "Meta_R"
            || name === "ISO_Level3_Shift") return

        let key = symbolForGlobal(name) || text
        if ((!key || /[\x00-\x1f]/.test(key)) && /^[a-z]$/i.test(name))
            key = name
        if (!key || /[\x00-\x1f]/.test(key) || key.length > 16) return
        appendFormattedKey(key, hasCtrl, hasShift, hasAlt, hasSuper)
    }

    Keys.onPressed: function(event) {
        if (backend.keyCaptureAvailable) return
        if (event.isAutoRepeat) return
        if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control
            || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta
            || event.key === Qt.Key_AltGr) return

        let key = symbolFor(event.key)
        if (!key) key = event.text
        if ((!key || /[\x00-\x1f]/.test(key))
            && event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            key = String.fromCharCode(event.key)
        if (!key || /[\x00-\x1f]/.test(key) || key.length > 16) return

        const modifiers = event.modifiers
        const hasCtrl = (modifiers & Qt.ControlModifier) !== 0
        const hasShift = (modifiers & Qt.ShiftModifier) !== 0
        const hasAlt = (modifiers & Qt.AltModifier) !== 0
        const hasSuper = (modifiers & Qt.MetaModifier) !== 0
        appendFormattedKey(key, hasCtrl, hasShift, hasAlt, hasSuper)
        event.accepted = true
    }

    Connections {
        target: backend
        function onGlobalKeyPressed(name, text, shift, ctrl, alt, superKey) {
            if (visualizer.visible)
                visualizer.globalPress(name, text, shift, ctrl, alt, superKey)
        }
    }

    Timer {
        id: clearTimer
        interval: 5000
        onTriggered: visualizer.history = []
    }

    Text {
        id: measure
        visible: false
        text: visualizer.displayText
        font.family: Qt.application.font.family
        font.pixelSize: visualizer.fontSize
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(26, height / 3)
        color: Theme.cardSurface

        Text {
            objectName: "key-visualizer-display"
            anchors.fill: parent
            anchors.leftMargin: visualizer.padding
            anchors.rightMargin: visualizer.padding
            text: visualizer.styledText
            textFormat: Text.StyledText
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: visualizer.fontSize
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: visualizer.settings.alignment === "left"
                ? Text.AlignLeft : visualizer.settings.alignment === "right"
                    ? Text.AlignRight : Text.AlignHCenter
            elide: Text.ElideLeft
            maximumLineCount: 1
        }
    }

    Component.onCompleted: {
        if (visible) forceActiveFocus()
    }
    onVisibleChanged: {
        if (visible) forceActiveFocus()
    }
}
