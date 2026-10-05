import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel === "tasks" || requestedPanel === "task"
        ? "todo" : requestedPanel
    readonly property bool resizablePanel: panelName === "todo"
    readonly property int panelWidth: {
        switch (panelName) {
        case "clock-weather": return 480
        case "audio-spectrum": return 440
        case "system-status": return 528
        case "music": return 414
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
        case "system-status": return 195
        case "music": return 254
        case "settings": return 510
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
        if (panelName === "system-status")
            return "Zhyprbola System Status"
        if (panelName === "audio-spectrum")
            return "Zhyprbola Audio Spectrum"
        if (panelName === "music")
            return "Zhyprbola Music Player"
        if (panelName === "todo")
            return "Zhyprbola Tasks"
        if (panelName === "calendar")
            return "Zhyprbola Calendar"
        if (panelName === "settings")
            return "Zhyprbola Settings"
        return "Zhyprbola Bluetooth"
    }

    visible: true
    width: panelWidth
    height: panelHeight
    minimumWidth: panelWidth
    minimumHeight: panelHeight
    maximumWidth: resizablePanel ? 640 : panelWidth
    maximumHeight: resizablePanel ? 720 : panelHeight
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    title: panelTitle

    Component.onCompleted: {
        if (panelName === "wifi") {
            wifiPanel.opened = true
        } else if (panelName === "bluetooth") {
            bluetoothPanel.opened = true
        }
    }

    BluetoothPanel {
        id: bluetoothPanel
        anchors.fill: parent
        standalone: true
        opened: false
        onCloseRequested: host.showMinimized()
    }

    WifiPanel {
        id: wifiPanel
        anchors.fill: parent
        standalone: true
        opened: false
        onCloseRequested: host.showMinimized()
    }

    ClockWeather {
        anchors.centerIn: parent
        visible: host.panelName === "clock-weather"
    }

    SystemStatus {
        anchors.centerIn: parent
        visible: host.panelName === "system-status"
    }

    AudioSpectrumBubble {
        anchors.centerIn: parent
        visible: host.panelName === "audio-spectrum"
    }

    MusicPlayer {
        anchors.centerIn: parent
        visible: host.panelName === "music"
    }

    Todo {
        anchors.fill: parent
        visible: host.panelName === "todo"
    }

    Calendar {
        anchors.centerIn: parent
        visible: host.panelName === "calendar"
    }

    SettingsPanel {
        anchors.centerIn: parent
        visible: host.panelName === "settings"
        onCloseRequested: host.showMinimized()
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
