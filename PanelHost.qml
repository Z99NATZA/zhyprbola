import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel
    readonly property int panelWidth: panelName === "clock-weather" || panelName === "audio-spectrum"
        ? 440
        : (panelName === "system-status" ? 430 : 430)
    readonly property int panelHeight: panelName === "wifi"
        ? 576
        : (panelName === "clock-weather" || panelName === "audio-spectrum"
            ? 172
            : (panelName === "system-status" ? 150 : 548))
    readonly property string panelTitle: {
        if (panelName === "wifi")
            return "Zhyprbola Wi-Fi"
        if (panelName === "clock-weather")
            return "Zhyprbola Clock & Weather"
        if (panelName === "system-status")
            return "Zhyprbola System Status"
        if (panelName === "audio-spectrum")
            return "Zhyprbola Audio Spectrum"
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
        onCloseRequested: Qt.quit()
    }

    WifiPanel {
        id: wifiPanel
        anchors.fill: parent
        standalone: true
        opened: false
        onCloseRequested: Qt.quit()
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

    Rectangle {
        anchors.fill: parent
        z: 200
        visible: host.panelName !== "clock-weather"
            && host.panelName !== "system-status"
            && host.panelName !== "audio-spectrum"
        radius: 18
        color: "transparent"
        border.color: Theme.secondary
        border.width: 1
    }
}
