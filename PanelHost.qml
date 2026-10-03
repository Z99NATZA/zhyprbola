import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel
    readonly property int panelWidth: panelName === "clock-weather" ? 500 : 430
    readonly property int panelHeight: panelName === "wifi" ? 576 : (panelName === "clock-weather" ? 302 : 548)

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
        : (panelName === "clock-weather" ? "Zhyprbola Clock & Weather" : "Zhyprbola Bluetooth")

    Component.onCompleted: {
        if (panelName === "wifi") {
            wifiPanel.opened = true
        } else if (panelName === "clock-weather") {
            clockWeatherPanel.opened = true
        } else {
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

    ClockWeatherPanel {
        id: clockWeatherPanel
        anchors.fill: parent
        standalone: true
        opened: false
        onCloseRequested: Qt.quit()
    }

    Rectangle {
        anchors.fill: parent
        z: 200
        radius: 18
        color: "transparent"
        border.color: Theme.secondary
        border.width: 1
    }
}
