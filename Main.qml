import QtQuick
import QtQuick.Window
import "components"

Window {
    id: desktop

    visible: true
    width: 1500
    height: 900
    visibility: Window.Maximized
    flags: Qt.FramelessWindowHint
    title: "Zhyprbola Desktop"
    color: "transparent"

    Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: Math.max(width, 1500)
        contentHeight: Math.max(height, 900)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: stage
            width: scroller.contentWidth
            height: scroller.contentHeight
            readonly property real layoutProgress: Math.max(0, Math.min(1,
                Math.min((width - 1500) / 548, (height - 900) / 252)))
            readonly property real leftScale: 1 + 0.28 * layoutProgress
            readonly property real rightScale: 1 + 0.15 * layoutProgress
            property bool clockEnabled: true
            property bool musicEnabled: true
            property bool appsEnabled: true
            property bool systemEnabled: true
            property bool todoEnabled: true
            property bool calendarEnabled: true
            property bool spectrumEnabled: true

            function loadComponentSettings() {
                clockEnabled = backend.componentEnabled("clock")
                musicEnabled = backend.componentEnabled("music")
                appsEnabled = backend.componentEnabled("apps")
                systemEnabled = backend.componentEnabled("system")
                todoEnabled = backend.componentEnabled("todo")
                calendarEnabled = backend.componentEnabled("calendar")
                spectrumEnabled = backend.componentEnabled("spectrum")
            }

            Component.onCompleted: loadComponentSettings()

            Connections {
                target: backend
                function onComponentSettingsChanged() {
                    stage.loadComponentSettings()
                }
            }

            Bar {
                x: 0
                y: 0
                width: stage.width
                onManagerRequested: componentManager.opened = true
                onWifiRequested: wifiPanel.opened = true
                onBluetoothRequested: bluetoothPanel.opened = true
            }

            Item {
                x: 90 + 40 * stage.layoutProgress
                y: 100 + 5 * stage.layoutProgress
                width: 480 * stage.leftScale
                height: 172 * stage.leftScale
                visible: stage.clockEnabled
                enabled: visible

                ClockWeather {
                    scale: stage.leftScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                x: 90 + 40 * stage.layoutProgress
                y: 310 + 60 * stage.layoutProgress
                width: 390 * stage.leftScale
                height: 230 * stage.leftScale
                visible: stage.musicEnabled
                enabled: visible

                MusicPlayer {
                    scale: stage.leftScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                x: 90 + 40 * stage.layoutProgress
                y: 550 + 210 * stage.layoutProgress
                width: 420 * stage.leftScale
                height: 245 * stage.leftScale
                visible: stage.appsEnabled
                enabled: visible

                Apps {
                    scale: stage.leftScale
                    transformOrigin: Item.TopLeft
                    onSettingsRequested: componentManager.opened = true
                }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 35 - 15 * stage.layoutProgress
                y: 100 + 5 * stage.layoutProgress
                width: 528
                height: 195
                visible: stage.systemEnabled
                enabled: visible

                SystemStatus { }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 70 - 35 * stage.layoutProgress
                y: 305 + 30 * stage.layoutProgress
                width: 360 * stage.rightScale
                height: 280 * stage.rightScale
                visible: stage.todoEnabled
                enabled: visible

                Todo {
                    scale: stage.rightScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 70 - 35 * stage.layoutProgress
                y: 600 + 100 * stage.layoutProgress
                width: 360 * stage.rightScale
                height: 290 * stage.rightScale
                visible: stage.calendarEnabled
                enabled: visible

                Calendar {
                    scale: stage.rightScale
                    transformOrigin: Item.TopLeft
                }
            }

            AudioSpectrum {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(200, Math.max(72, stage.height - 1080))
                visible: stage.spectrumEnabled
                enabled: visible
            }

            ComponentManager {
                id: componentManager
                opened: false
                onCloseRequested: opened = false
            }

            WifiPanel {
                id: wifiPanel
                opened: false
                onCloseRequested: opened = false
            }

            BluetoothPanel {
                id: bluetoothPanel
                opened: false
                onCloseRequested: opened = false
            }

        }
    }
}
