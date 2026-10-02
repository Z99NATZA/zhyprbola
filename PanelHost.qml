import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel
    readonly property int panelWidth: 430
    readonly property int panelHeight: panelName === "wifi" ? 576 : 548

    visible: true
    width: panelWidth
    height: panelHeight
    minimumWidth: panelWidth
    minimumHeight: panelHeight
    maximumWidth: panelWidth
    maximumHeight: panelHeight
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: panelName === "wifi" ? "Zhyprbola Wi-Fi" : "Zhyprbola Bluetooth"

    Component.onCompleted: {
        if (panelName === "wifi") {
            wifiPanel.opened = true
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
}
