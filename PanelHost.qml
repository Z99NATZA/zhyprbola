import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel
    readonly property int panelWidth: panelName === "clock-weather" ? 440 : (panelName === "system-status" ? 430 : 430)
    readonly property int panelHeight: panelName === "wifi"
        ? 576
        : (panelName === "clock-weather" ? 172 : (panelName === "system-status" ? 150 : 548))

    visible: true
    width: panelWidth
    height: panelHeight
    minimumWidth: panelWidth
    minimumHeight: panelHeight
    maximumWidth: panelWidth
    maximumHeight: panelHeight
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: panelName === "wifi"
        ? "Zhyprbola Wi-Fi"
        : (panelName === "clock-weather"
            ? "Zhyprbola Clock & Weather"
            : (panelName === "system-status" ? "Zhyprbola System Status" : "Zhyprbola Bluetooth"))

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

    Rectangle {
        anchors.fill: parent
        z: 200
        visible: host.panelName !== "clock-weather" && host.panelName !== "system-status"
        radius: 18
        color: "transparent"
        border.color: Theme.secondary
        border.width: 1
    }
}
