import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel === "tasks" || requestedPanel === "task"
        ? "todo" : requestedPanel
    readonly property bool resizablePanel: panelName === "todo"
    readonly property Item panelItem: panelLoader.item as Item
    property bool hostInitialized: false
    readonly property int panelWidth: {
        switch (panelName) {
        case "clock-weather": return 480
        case "key-visualizer": return panelItem ? panelItem.implicitWidth : 180
        case "audio-spectrum": return 440
        case "system-status": return 528
        case "music": return 414
        case "sound": return 384
        case "settings": return 660
        case "todo":
        case "calendar": return 384
        default: return 430
        }
    }
    readonly property int panelHeight: {
        switch (panelName) {
        case "wifi": return 576
        case "clock-weather":
        case "audio-spectrum": return 172
        case "key-visualizer": return panelItem ? panelItem.implicitHeight : 78
        case "system-status": return 195
        case "music": return 254
        case "sound": return sound.error.length > 0 ? 214 : 184
        case "settings": return panelItem ? panelItem.implicitHeight : 510
        case "todo": return 360
        case "calendar": return 314
        default: return 548
        }
    }
    readonly property string panelTitle: {
        if (panelName === "wifi")
            return "Zhyprbola Wi-Fi"
        if (panelName === "clock-weather")
            return "Zhyprbola Clock & Weather"
        if (panelName === "key-visualizer")
            return "Zhyprbola Key Visualizer"
        if (panelName === "system-status")
            return "Zhyprbola System Status"
        if (panelName === "audio-spectrum")
            return "Zhyprbola Audio Spectrum"
        if (panelName === "music")
            return "Zhyprbola Music Player"
        if (panelName === "sound")
            return "Zhyprbola Sound"
        if (panelName === "todo")
            return "Zhyprbola Tasks"
        if (panelName === "calendar")
            return "Zhyprbola Calendar"
        if (panelName === "settings")
            return "Zhyprbola Settings"
        return "Zhyprbola Bluetooth"
    }

    visible: panelLoader.status === Loader.Ready
    width: panelWidth
    height: panelHeight
    minimumWidth: panelWidth
    minimumHeight: panelHeight
    maximumWidth: resizablePanel ? 640 : panelWidth
    maximumHeight: resizablePanel ? 720 : panelHeight
    // Normal windows participate in the compositor's minimize/restore animation.
    flags: Qt.FramelessWindowHint | Qt.Window
    color: "transparent"
    title: panelTitle

    function loadPanel() {
        const files = {
            bluetooth: "BluetoothPanel.qml", wifi: "WifiPanel.qml",
            "clock-weather": "ClockWeather.qml", "key-visualizer": "KeyVisualizer.qml",
            "system-status": "SystemStatus.qml", "audio-spectrum": "AudioSpectrumBubble.qml",
            music: "MusicPlayer.qml", sound: "SoundPanel.qml", todo: "Todo.qml",
            calendar: "Calendar.qml", settings: "SettingsPanel.qml"
        }
        const radio = panelName === "wifi" || panelName === "bluetooth"
        // Radio cards must start in standalone mode, before their anchors run.
        // Setting it after creation can retain an off-window anchored position.
        panelLoader.setSource(Qt.resolvedUrl("components/" + (files[panelName] || "BluetoothPanel.qml")),
            radio ? {standalone: true, opened: true} : {})
    }

    Component.onCompleted: {
        hostInitialized = true
        loadPanel()
    }
    onPanelNameChanged: { if (hostInitialized) loadPanel() }

    function syncActivity() {
        const showing = host.visible && host.visibility !== Window.Minimized
        backend.setPanelActive(showing)
        if ((panelName === "wifi" || panelName === "bluetooth") && panelLoader.item)
            panelLoader.item.opened = showing
        if (panelName === "key-visualizer") {
            if (showing && panelItem) {
                panelItem.forceActiveFocus()
                backend.startKeyCapture()
            } else {
                backend.stopKeyCapture()
            }
        }
    }

    onVisibilityChanged: syncActivity()
    onActiveChanged: {
        if (active && panelName === "key-visualizer" && panelItem)
            panelItem.forceActiveFocus()
    }

    Loader {
        id: panelLoader
        objectName: "panel-loader"
        anchors.fill: parent
        focus: true
        visible: host.visible && host.visibility !== Window.Minimized
        onLoaded: host.syncActivity()
    }

    Connections {
        target: panelLoader.item
        ignoreUnknownSignals: true
        function onCloseRequested() { host.showMinimized() }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        visible: host.panelName === "key-visualizer"
        onClicked: {
            host.requestActivate()
            if (host.panelItem) host.panelItem.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 200
        visible: host.panelName === "bluetooth" || host.panelName === "wifi"
        radius: 18
        color: "transparent"
        border.color: Theme.secondary
        border.width: 1
    }

    Item {
        id: resizeHandle
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 28
        height: 28
        visible: host.resizablePanel
        z: 300

        Canvas {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 7
            anchors.bottomMargin: 7
            width: 13
            height: 13
            opacity: resizeMouse.containsMouse ? 0.72 : 0.34

            onOpacityChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Theme.text
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(5, 12)
                ctx.lineTo(12, 5)
                ctx.moveTo(9, 12)
                ctx.lineTo(12, 9)
                ctx.stroke()
            }
        }

        MouseArea {
            id: resizeMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeFDiagCursor
            onPressed: host.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }

}
