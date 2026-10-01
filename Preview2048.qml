import QtQuick
import QtQuick.Window
import "components"

Window {
    id: desktop

    visible: true
    width: 2048
    height: 1152
    title: "Zpola Desktop"
    color: "#4a3566"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#d99ab8" }
            GradientStop { position: 0.55; color: "#9a6a9c" }
            GradientStop { position: 1.0; color: "#4a3566" }
        }
    }

    Repeater {
        model: [
            { x: 0.12, y: 0.25, size: 300, color: "#ffd1e3" },
            { x: 0.70, y: 0.65, size: 380, color: "#b79cff" },
            { x: 0.45, y: 0.05, size: 240, color: "#ffb3c7" }
        ]

        delegate: Rectangle {
            required property var modelData
            width: modelData.size
            height: modelData.size
            radius: width / 2
            x: desktop.width * modelData.x - width / 2
            y: desktop.height * modelData.y - height / 2
            color: modelData.color
            opacity: 0.22
        }
    }

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
            readonly property real dockScale: 1 + 0.25 * layoutProgress

            Bar {
                x: 0
                y: 0
                width: stage.width
            }

            Item {
                x: 90 + 40 * stage.layoutProgress
                y: 100 + 5 * stage.layoutProgress
                width: 440 * stage.leftScale
                height: 172 * stage.leftScale

                ClockWeather {
                    scale: stage.leftScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                x: 90 + 40 * stage.layoutProgress
                y: 310 + 60 * stage.layoutProgress
                width: 390 * stage.leftScale
                height: 210 * stage.leftScale

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

                Apps {
                    scale: stage.leftScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 35 - 15 * stage.layoutProgress
                y: 100 + 5 * stage.layoutProgress
                width: 430
                height: 150

                SystemStatus { }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 70 - 35 * stage.layoutProgress
                y: 270 + 30 * stage.layoutProgress
                width: 360 * stage.rightScale
                height: 280 * stage.rightScale

                Todo {
                    scale: stage.rightScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                anchors.right: parent.right
                anchors.rightMargin: 70 - 35 * stage.layoutProgress
                y: 565 + 100 * stage.layoutProgress
                width: 360 * stage.rightScale
                height: 290 * stage.rightScale

                Calendar {
                    scale: stage.rightScale
                    transformOrigin: Item.TopLeft
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 600 * stage.dockScale
                height: 124 * stage.dockScale

                Dock {
                    scale: stage.dockScale
                    transformOrigin: Item.TopLeft
                }
            }
        }
    }
    Timer {
        interval: 1200
        running: true
        onTriggered: desktop.contentItem.grabToImage(function(result) {
            result.saveToFile("/tmp/zpola-2048.png")
            Qt.quit()
        })
    }
}
