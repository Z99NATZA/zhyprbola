import QtQuick
import QtQuick.Controls as Controls

Item {
    id: visualizer

    readonly property var settings: backend.keyVisualizerSettings
    readonly property int fontSize: settings.fontSize === "sm" ? 23
        : settings.fontSize === "lg" ? 38 : 30
    readonly property int defaultPadding: settings.fontSize === "lg" ? 24 : 20
    readonly property int paddingX: settings.paddingX === "sm" ? 4
        : defaultPadding + (settings.paddingX === "lg" ? 12 : 0)
    readonly property int defaultHeight: settings.fontSize === "sm" ? 64
        : settings.fontSize === "lg" ? 96 : 78
    readonly property int keyAreaHeight: settings.paddingY === "sm"
        ? Math.ceil(measure.implicitHeight) + 8
        : defaultHeight + (settings.paddingY === "lg" ? 24 : 0)
    property bool showAccessPrompt: false
    property var history: []
    property bool componentReady: false
    property bool previewing: false
    // Show the chord immediately; commit on release or replace it with a shortcut.
    property bool ctrlShiftActive: false
    property bool pendingCtrlShift: false
    // Typed keys stay on screen; a settings preview only borrows the display.
    property var keptHistory: []
    readonly property string previewAppearance: [settings.fontSize, settings.paddingX,
        settings.paddingY, settings.alignment].join(":")
    onPreviewAppearanceChanged: {
        if (componentReady) {
            if (!previewing) keptHistory = history
            previewing = true
            history = ["hello", "␣", "world"]
            previewTimer.restart()
        }
    }
    readonly property string displayText: formatHistory(false)
    readonly property string styledText: formatHistory(true)
    readonly property int minimumWidth: showAccessPrompt ? 300 : 200
    implicitWidth: Math.max(minimumWidth, settings.width)
    implicitHeight: keyAreaHeight + (showAccessPrompt ? 58 : 0)
    focus: true

    function symbolFor(key) {
        switch (key) {
        case Qt.Key_Space: return "␣"
        case Qt.Key_Backspace: return "⌫"
        case Qt.Key_Return:
        case Qt.Key_Enter: return "↵"
        case Qt.Key_Tab:
        case Qt.Key_Backtab: return "Tab"
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

    function endPreview() {
        if (!previewing) return
        previewTimer.stop()
        previewing = false
        history = keptHistory
        keptHistory = []
    }

    function clearHistory() {
        resetCtrlShift()
        previewTimer.stop()
        previewing = false
        keptHistory = []
        history = []
    }

    function appendKey(value) {
        if (!value) return
        pendingCtrlShift = false
        endPreview()
        history = trimHistory(history.concat(value))
    }

    // History is kept by runs of the same key, because a long run is shown as
    // one "*n" group and should not push older keys out of the display.
    readonly property int maxHistoryRuns: 48
    readonly property int maxHistoryLength: 500

    function trimHistory(list) {
        let runs = 0
        let start = list.length
        let previous = null
        for (let i = list.length - 1; i >= 0; --i) {
            if (list[i] !== previous) {
                runs++
                previous = list[i]
            }
            if (runs > maxHistoryRuns) break
            start = i
        }
        const kept = list.slice(start)
        return kept.length > maxHistoryLength ? kept.slice(-maxHistoryLength) : kept
    }

    function resetCtrlShift() {
        ctrlShiftActive = false
        pendingCtrlShift = false
    }

    function pressModifier(isCtrl, isShift, hasCtrl, hasShift, hasAlt, hasSuper) {
        const chord = (isCtrl || hasCtrl) && (isShift || hasShift)
            && !hasAlt && !hasSuper
        if ((!isCtrl && !isShift) || !chord) {
            resetCtrlShift()
            return
        }
        if (!ctrlShiftActive) {
            endPreview()
            pendingCtrlShift = true
        }
        ctrlShiftActive = true
    }

    function releaseCtrlShift() {
        const record = pendingCtrlShift
        resetCtrlShift()
        if (record) appendKey("^Shift")
    }

    function escapeText(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function isSpecialKey(value) {
        return ["␣", "⌫", "↵", "Tab", "Esc", "⌦", "←", "→",
            "↑", "↓", "Home", "End", "PgUp", "PgDn"].includes(value)
    }

    // Space stays flush with typed text; other special keys and shortcuts get
    // separated from their neighbours.
    function isSpacedToken(value) {
        return (isSpecialKey(value) && value !== "␣")
            || /^(\^|Alt\+|Super\+|Shift\+)/.test(value)
    }

    // A run of the same key shows up to three times, then "*n" for the total,
    // so holding or mashing a key does not flood the bubble.
    readonly property int maxRepeatShown: 3

    function formatHistory(styled) {
        const entries = []
        const tokens = pendingCtrlShift ? history.concat("^Shift") : history
        let index = 0
        while (index < tokens.length) {
            const token = tokens[index]
            let count = 1
            while (index + count < tokens.length && tokens[index + count] === token) count++
            index += count
            const shown = Math.min(count, maxRepeatShown)
            const shortcut = /^((?:\^|(?:Alt|Super|Shift)\+)+)([a-z])$/i.exec(token)
            // A collapsed run starts a new word, so it is set off from earlier keys.
            const breakBefore = count > maxRepeatShown
            if (shortcut)
                entries.push({token: shortcut[1] + shortcut[2].repeat(shown), suffix: "",
                    breakBefore: breakBefore})
            else
                for (let i = 0; i < shown; i++)
                    entries.push({token: token, suffix: "", breakBefore: breakBefore && i === 0})
            if (count > maxRepeatShown)
                entries[entries.length - 1].suffix = "*" + count
        }
        let result = ""
        let previousSpaced = false
        for (const entry of entries) {
            const spaced = isSpacedToken(entry.token)
            if (result && (previousSpaced || spaced || entry.breakBefore)) result += " "
            result += (styled ? styledToken(entry.token, Theme.accent.toString()) : entry.token)
                + entry.suffix
            // A "*n" count closes its run, so the next key starts a new word.
            previousSpaced = spaced || entry.suffix !== ""
        }
        return result
    }

    function styledToken(value, accent) {
        let remaining = value
        let result = ""
        let modifier = /^(\^|Alt\+|Super\+|Shift\+)/.exec(remaining)
        while (modifier) {
            const prefix = modifier[0]
            result += '<font color="' + accent + '">' + prefix + '</font>'
            remaining = remaining.slice(prefix.length)
            modifier = /^(\^|Alt\+|Super\+|Shift\+)/.exec(remaining)
        }
        const key = escapeText(remaining)
        const special = isSpecialKey(remaining) || remaining === "Shift"
        return result + (special ? '<font color="' + accent + '">' + key + '</font>' : key)
    }

    function symbolForGlobal(name) {
        switch (name) {
        case "space": return "␣"
        case "BackSpace": return "⌫"
        case "Return":
        case "KP_Enter": return "↵"
        case "Tab":
        case "ISO_Left_Tab": return "Tab"
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
        // Ctrl shows as ^ (Ctrl+a = ^a, Ctrl+Shift+a = ^A).
        let prefix = ""
        if (hasCtrl) {
            if (/^[a-z]$/i.test(key))
                key = hasShift ? key.toUpperCase() : key.toLowerCase()
            else if (hasShift)
                prefix += "Shift+"
            prefix = "^" + prefix
        }
        if (hasAlt) prefix += "Alt+"
        if (hasSuper) prefix += "Super+"
        appendKey(prefix + key)
    }

    function globalPress(name, text, hasShift, hasCtrl, hasAlt, hasSuper) {
        const isShift = name === "Shift_L" || name === "Shift_R"
        const isCtrl = name === "Control_L" || name === "Control_R"
        if (isShift || isCtrl
            || name === "Alt_L" || name === "Alt_R"
            || name === "Super_L" || name === "Super_R"
            || name === "Meta_L" || name === "Meta_R"
            || name === "ISO_Level3_Shift") {
            pressModifier(isCtrl, isShift, hasCtrl, hasShift, hasAlt, hasSuper)
            return
        }

        pendingCtrlShift = false
        ctrlShiftActive = hasCtrl && hasShift && !hasAlt && !hasSuper

        let key = symbolForGlobal(name) || text
        if ((!key || /[\x00-\x1f]/.test(key)) && /^[a-z]$/i.test(name))
            key = name
        if (!key || /[\x00-\x1f]/.test(key) || key.length > 16) return
        appendFormattedKey(key, hasCtrl, hasShift, hasAlt, hasSuper)
    }

    Keys.onPressed: function(event) {
        if (backend.keyCaptureAvailable) return
        const modifiers = event.modifiers
        const hasCtrl = (modifiers & Qt.ControlModifier) !== 0
        const hasShift = (modifiers & Qt.ShiftModifier) !== 0
        const hasAlt = (modifiers & Qt.AltModifier) !== 0
        const hasSuper = (modifiers & Qt.MetaModifier) !== 0
        if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control
            || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta
            || event.key === Qt.Key_AltGr) {
            if (!event.isAutoRepeat)
                pressModifier(event.key === Qt.Key_Control, event.key === Qt.Key_Shift,
                    hasCtrl, hasShift, hasAlt, hasSuper)
            return
        }

        pendingCtrlShift = false
        ctrlShiftActive = hasCtrl && hasShift && !hasAlt && !hasSuper

        let key = symbolFor(event.key)
        if (!key) key = event.text
        if ((!key || /[\x00-\x1f]/.test(key))
            && event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            key = String.fromCharCode(event.key)
        if (!key || /[\x00-\x1f]/.test(key) || key.length > 16) return

        appendFormattedKey(key, hasCtrl, hasShift, hasAlt, hasSuper)
        event.accepted = true
    }

    Keys.onReleased: function(event) {
        if (!backend.keyCaptureAvailable && !event.isAutoRepeat
            && (event.key === Qt.Key_Control || event.key === Qt.Key_Shift))
            releaseCtrlShift()
    }

    Connections {
        target: backend
        function onGlobalKeyPressed(name, text, shift, ctrl, alt, superKey) {
            if (visualizer.visible)
                visualizer.globalPress(name, text, shift, ctrl, alt, superKey)
        }
        function onGlobalKeyReleased(name) {
            if (visualizer.visible && (name === "Control_L" || name === "Control_R"
                || name === "Shift_L" || name === "Shift_R"))
                visualizer.releaseCtrlShift()
        }
    }

    Timer {
        id: previewTimer
        interval: 5000
        onTriggered: visualizer.endPreview()
    }

    Timer {
        id: accessPromptTimer
        interval: 900
        onTriggered: {
            if (visualizer.visible && !backend.keyCaptureAvailable)
                visualizer.showAccessPrompt = true
        }
    }

    Connections {
        target: backend
        function onKeyCaptureAvailableChanged() {
            visualizer.resetCtrlShift()
            visualizer.showAccessPrompt = false
            if (!backend.keyCaptureAvailable && visualizer.visible)
                accessPromptTimer.restart()
        }
    }

    // Compact height comes from a fixed sample, not the typed keys, so fallback
    // fonts (Thai stacked marks, key symbols) cannot make the bubble jump.
    Text {
        id: measure
        visible: false
        text: "Agjy ␣⌫↵⇥⌦←→↑↓ ปั้ฟ้ญูฎุกิ๊"
        font.family: Qt.application.font.family
        font.pixelSize: visualizer.fontSize
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(26, height / 3)
        color: Theme.componentSurfaceFor("key-visualizer")
        // Border and opacity are set in Settings > Keys (no room for a card menu).
        border.width: Theme.cardBorderVisible("key-visualizer") ? 1 : 0
        border.color: Theme.cardOutline

        Text {
            objectName: "key-visualizer-display"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: visualizer.keyAreaHeight
            anchors.leftMargin: visualizer.paddingX
            anchors.rightMargin: visualizer.paddingX
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

        Text {
            visible: visualizer.showAccessPrompt
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 17
            text: "Keys everywhere: off"
            color: Theme.text
            font.pixelSize: 12
        }

        Rectangle {
            objectName: "key-capture-access-button"
            visible: visualizer.showAccessPrompt
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            width: 134
            height: 32
            radius: 10
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: backend.keyCaptureGrantPending ? "Waiting..." : "Allow temporarily"
                color: Theme.accentText
                font.pixelSize: 11
                font.weight: Font.Medium
            }
            MouseArea {
                anchors.fill: parent
                enabled: !backend.keyCaptureGrantPending
                onClicked: backend.grantKeyCaptureAccess()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => contextMenu.popup(mouse.x, mouse.y)
    }

    Controls.Menu {
        id: contextMenu
        objectName: "key-visualizer-context-menu"
        width: 140
        padding: 4
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onClosed: visualizer.forceActiveFocus()

        background: Rectangle {
            radius: 10
            color: Theme.cardSurface
            border.width: 1
            border.color: Theme.line
        }

        Controls.MenuItem {
            id: clearAction
            objectName: "key-visualizer-clear"
            text: "Clear"
            implicitHeight: 36
            hoverEnabled: true
            onTriggered: visualizer.clearHistory()

            contentItem: Text {
                text: clearAction.text
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 7
                color: clearAction.hovered ? Theme.controlHover : "transparent"
            }
        }
    }

    Connections {
        target: visualizer.Window.window
        function onActiveChanged() {
            if (!visualizer.Window.window.active) {
                contextMenu.close()
                if (!backend.keyCaptureAvailable) visualizer.resetCtrlShift()
            }
        }
    }

    Component.onCompleted: {
        componentReady = true
        if (visible) {
            forceActiveFocus()
            accessPromptTimer.start()
        }
    }
    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            accessPromptTimer.restart()
        } else {
            resetCtrlShift()
            accessPromptTimer.stop()
            showAccessPrompt = false
        }
    }
}
