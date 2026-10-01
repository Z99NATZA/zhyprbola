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
    title: "Zpola Desktop"
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

        }
    }
}
