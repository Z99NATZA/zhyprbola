import QtQuick

Item {
    id: visualizer

    readonly property var settings: backend.keyVisualizerSettings
    readonly property int fontSize: settings.fontSize === "sm" ? 23
        : settings.fontSize === "lg" ? 38 : 30
    readonly property int padding: settings.fontSize === "lg" ? 24 : 20
    property var history: []
    property bool pendingShift: false
    property bool shiftUsed: false
    readonly property string displayText: history.join(" ")
    implicitWidth: settings.widthMode === "fixed" ? settings.maxWidth
        : Math.max(settings.minWidth,
            Math.min(settings.maxWidth, measure.implicitWidth + padding * 2))
    implicitHeight: settings.fontSize === "sm" ? 64
        : settings.fontSize === "lg" ? 96 : 78
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
        if ((hasCtrl || hasShift) && /^[a-z]$/i.test(key)) key = key.toUpperCase()
        const prefix = []
        if (hasCtrl) prefix.push("Ctrl")
        if (hasAlt) prefix.push("Alt")
        if (hasSuper) prefix.push("Super")
        if (hasShift) prefix.push("⇧")
        appendKey(prefix.length === 1 && hasShift ? "⇧ " + key
            : prefix.length ? prefix.join("+") + "+" + key : key)
    }

    function globalPress(name, text, hasShift, hasCtrl, hasAlt, hasSuper) {
        if (name === "Shift_L" || name === "Shift_R") {
            pendingShift = true
            shiftUsed = false
            return
        }
        if (name === "Control_L" || name === "Control_R"
            || name === "Alt_L" || name === "Alt_R"
            || name === "Super_L" || name === "Super_R"
            || name === "Meta_L" || name === "Meta_R"
            || name === "ISO_Level3_Shift") return

        if (pendingShift) shiftUsed = true
        let key = symbolForGlobal(name) || text
        if ((!key || /[\x00-\x1f]/.test(key)) && /^[a-z]$/i.test(name))
            key = name
        if (!key || /[\x00-\x1f]/.test(key) || key.length > 16) return
        appendFormattedKey(key, hasCtrl, hasShift, hasAlt, hasSuper)
    }

    function globalRelease(name) {
        if (name !== "Shift_L" && name !== "Shift_R") return
        if (pendingShift && !shiftUsed) appendKey("⇧")
        pendingShift = false
    }

    Keys.onPressed: function(event) {
        if (backend.keyCaptureAvailable) return
        if (event.isAutoRepeat) return
        if (event.key === Qt.Key_Shift) {
            pendingShift = true
            shiftUsed = false
            return
        }
        if (event.key === Qt.Key_Control
            || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta
            || event.key === Qt.Key_AltGr) return

        if (pendingShift) shiftUsed = true
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

    Keys.onReleased: function(event) {
        if (backend.keyCaptureAvailable) return
        if (event.key === Qt.Key_Shift) {
            if (pendingShift && !shiftUsed) appendKey("⇧")
            pendingShift = false
        }
    }

    Connections {
        target: backend
        function onGlobalKeyPressed(name, text, shift, ctrl, alt, superKey) {
            if (visualizer.visible)
                visualizer.globalPress(name, text, shift, ctrl, alt, superKey)
        }
        function onGlobalKeyReleased(name) {
            if (visualizer.visible) visualizer.globalRelease(name)
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
            anchors.fill: parent
            anchors.leftMargin: visualizer.padding
            anchors.rightMargin: visualizer.padding
            text: visualizer.displayText
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
