import QtQuick

Item {
    id: win

    width: 528
    height: 195
    // ==================================================
    // Background
    // ==================================================



    // ==================================================
    // Ring stat component
    // ==================================================

    component RingStat: Item {
        id: stat

        property string title: "CPU"
        property int value: 0
        property string detail: "Ryzen 5 5600"
        property color accentColor: Theme.accent

        width: 114
        height: 128

        readonly property color textColor: Theme.text
        readonly property color dimColor: Qt.alpha(textColor, 0.72)
        readonly property color trackColor: Theme.track
        readonly property string family: Qt.application.font.family

        Item {
            id: ringArea

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 8
            }

            width: 96
            height: 96

            Canvas {
                id: ring
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var cx = width / 2
                    var cy = height / 2
                    var radius = 37
                    var lineWidth = 7
                    var start = -Math.PI / 2
                    var end = start + Math.PI * 2 * stat.value / 100

                    ctx.beginPath()
                    ctx.lineWidth = lineWidth
                    ctx.strokeStyle = stat.trackColor
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.lineWidth = lineWidth
                    ctx.lineCap = "round"

                    ctx.strokeStyle = stat.accentColor
                    ctx.arc(cx, cy, radius, start, end)
                    ctx.stroke()
                }

                Connections {
                    target: stat

                    function onValueChanged() {
                        ring.requestPaint()
                    }

                    function onAccentColorChanged() {
                        ring.requestPaint()
                    }

                    function onTrackColorChanged() {
                        ring.requestPaint()
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: stat.title
                    color: stat.textColor

                    font {
                        family: stat.family
                        pixelSize: 13
                        weight: Font.DemiBold
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: stat.value + "%"
                    color: stat.textColor

                    font {
                        family: stat.family
                        pixelSize: 16
                        weight: Font.DemiBold
                    }
                }
            }
        }

        // --------------------------------------------------
        // Marquee detail label
        // --------------------------------------------------

        Item {
            id: detailArea

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: ringArea.bottom
                topMargin: 0
            }

            width: 114
            height: 18
            clip: true
            readonly property real marqueeSpeed: 12 // pixels per second
            readonly property int scrollDuration: Math.round(
                Math.max(0, detailText.width - width) * 1000 / marqueeSpeed)

            Text {
                id: detailText

                y: (detailArea.height - height) / 2

                text: stat.detail
                color: stat.dimColor

                font {
                    family: stat.family
                    pixelSize: 11
                    weight: Font.Medium
                }

                x: width <= detailArea.width
                    ? (detailArea.width - width) / 2
                    : 0

                SequentialAnimation on x {
                    running: detailText.width > detailArea.width
                    loops: Animation.Infinite

                    PauseAnimation {
                        duration: 1000
                    }

                    NumberAnimation {
                        to: detailArea.width - detailText.width
                        duration: detailArea.scrollDuration
                        easing.type: Easing.Linear
                    }

                    PauseAnimation {
                        duration: 1000
                    }

                    NumberAnimation {
                        to: 0
                        duration: detailArea.scrollDuration
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    // ==================================================
    // Main card
    // ==================================================

    Item {
        id: card

        anchors.centerIn: parent
        scale: 1.3

        property int paddingX: 22
        property int paddingY: 6

        implicitWidth: content.implicitWidth + paddingX * 2
        implicitHeight: content.implicitHeight + paddingY * 2

        width: implicitWidth
        height: implicitHeight + 10

        property color surfaceColor: Theme.componentSurfaceFor("system-status")
        property real cornerRadius: 24

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
        }

        // ==================================================
        // Content
        // ==================================================

        Row {
            id: content

            x: card.paddingX
            y: card.paddingY
            spacing: 8

            RingStat {
                title: "CPU"
                value: backend.cpuPercent
                detail: backend.cpuDetail
            }

            RingStat {
                title: "RAM"
                value: backend.ramPercent
                detail: backend.ramDetail
            }

            RingStat {
                title: "Disk"
                value: backend.diskPercent
                detail: backend.diskDetail
            }
        }
    }
}
