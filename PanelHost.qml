import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel
    readonly property int panelWidth: {
        switch (panelName) {
        case "clock-weather": return 480
        case "audio-spectrum": return 440
        case "system-status": return 528
        case "music": return 414
        case "settings": return 560
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
        case "settings": return 420
        case "todo": return 304
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
            return "Zhyprbola Today"
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
    maximumWidth: panelWidth
    maximumHeight: panelHeight
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
        anchors.centerIn: parent
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
}
