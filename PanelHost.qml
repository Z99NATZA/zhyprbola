import QtQuick
import QtQuick.Window
import "components"

Window {
    id: host

    property string requestedPanel: "bluetooth"
    readonly property string panelName: requestedPanel
    readonly property int panelWidth: 500
    readonly property int panelHeight: panelName === "wifi" ? 640 : 620

    visible: true
    width: panelWidth
    height: panelHeight
    minimumWidth: panelWidth
    minimumHeight: panelHeight
    maximumWidth: panelWidth
    maximumHeight: panelHeight
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Zhyprbola Panel"

    Component.onCompleted: {
        if (panelName === "wifi") {
            wifiPanel.opened = true
        } else {
            bluetoothPanel.opened = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    BluetoothPanel {
        id: bluetoothPanel
        anchors.fill: parent
        opened: false
        onCloseRequested: Qt.quit()
    }

    WifiPanel {
        id: wifiPanel
        anchors.fill: parent
        opened: false
        onCloseRequested: Qt.quit()
    }
}
