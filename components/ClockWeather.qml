import QtQuick

Item {
    id: win

    width: 480
    height: 172


    // --------------------------------------------------
    // Reusable animated text
    // --------------------------------------------------

    component PopText: Text {
        id: popText

        property bool animate: false

        onTextChanged: {
            if (animate)
                pop.restart()
        }

        ParallelAnimation {
            id: pop

            NumberAnimation {
                target: popText
                property: "opacity"
                from: 0.3
                to: 1
                duration: 350
            }

            NumberAnimation {
                target: popText
                property: "scale"
                from: 0.9
                to: 1
                duration: 450
                easing.type: Easing.OutBack
            }
        }
    }

    // --------------------------------------------------
    // Background
    // --------------------------------------------------


    // --------------------------------------------------
    // Decorative background circles
    // --------------------------------------------------


    // --------------------------------------------------
    // Clock + Weather Card
    // --------------------------------------------------

    Item {
        id: card

        anchors.centerIn: parent

        width: parent.width
        height: 172

        // ----------------------------------------------
        // Data
        // ----------------------------------------------

        property date now: new Date()

        readonly property bool isDaytime: now.getHours() >= 6 && now.getHours() < 18

        property bool use24Hour: true

        property int temperature: backend.temperature

        property string condition: backend.condition

        property int high: backend.high
        property int low: backend.low

        property string location: backend.location

        // ----------------------------------------------
        // Style
        // ----------------------------------------------

        property color textColor: Theme.text

        property color surfaceColor: Theme.componentSurfaceFor("clock-weather")


        property color accentColor: Theme.clockAccent

        property real cornerRadius: 26



        readonly property color dimColor:
            Qt.alpha(textColor, 0.75)

        readonly property string family:
            Qt.application.font.family

        property bool ready: false

        // ----------------------------------------------
        // Clock timer
        // ----------------------------------------------

        Timer {
            interval: 1000
            running: true
            repeat: true

            onTriggered: {
                card.now = new Date()
            }
        }

        Component.onCompleted: {
            ready = true
        }

        // ----------------------------------------------
        // Intro animation
        // ----------------------------------------------

        opacity: 0

        transform: Translate {
            id: enterTransform
            y: 14
        }

        NumberAnimation on opacity {
            from: 0
            to: 1

            duration: 600

            easing.type:
                Easing.OutCubic
        }

        NumberAnimation {
            target: enterTransform

            property: "y"

            from: 14
            to: 0

            duration: 700

            easing.type:
                Easing.OutCubic

            running: true
        }

        // --------------------------------------------------
        // Flat surface
        // --------------------------------------------------

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
        }

        // --------------------------------------------------
        // Left side - Clock
        // --------------------------------------------------

        Item {
            id: left

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width: 224

            Column {
                anchors.centerIn: parent

                anchors.verticalCenterOffset:
                    0

                spacing: 10

                // ------------------------------------------
                // Time
                // ------------------------------------------

                Row {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    spacing: 3

                    PopText {
                        animate:
                            card.ready

                        text:
                            Qt.formatDateTime(
                                card.now,
                                card.use24Hour
                                    ? "HH"
                                    : "hh"
                            )

                        color:
                            card.textColor

                        font {
                            family:
                                card.family

                            pixelSize:
                                58

                            weight:
                                Font.Medium
                        }
                    }

                    Text {
                        text: ":"

                        color:
                            card.textColor

                        font {
                            family:
                                card.family

                            pixelSize:
                                58

                            weight:
                                Font.Medium
                        }

                        SequentialAnimation on opacity {
                            loops:
                                Animation.Infinite

                            NumberAnimation {
                                to: 0.35

                                duration:
                                    900

                                easing.type:
                                    Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 1

                                duration:
                                    900

                                easing.type:
                                    Easing.InOutSine
                            }
                        }
                    }

                    PopText {
                        animate:
                            card.ready

                        text:
                            Qt.formatDateTime(
                                card.now,
                                "mm"
                            )

                        color:
                            card.textColor

                        font {
                            family:
                                card.family

                            pixelSize:
                                58

                            weight:
                                Font.Medium
                        }
                    }
                }

                // ------------------------------------------
                // Date
                // ------------------------------------------

                PopText {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    animate:
                        card.ready

                    text:
                        Qt.formatDateTime(
                            card.now,
                            "ddd, MMM d, yyyy"
                        )

                    color:
                        card.dimColor

                    font {
                        family:
                            card.family

                        pixelSize:
                            14
                    }
                }
            }
        }

        // --------------------------------------------------
        // Right side - Weather
        // --------------------------------------------------

        Item {
            id: weatherSide

            anchors {
                left: left.right
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }

            Column {
                anchors {
                    left:
                        parent.left

                    leftMargin:
                        26

                    right:
                        parent.right

                    rightMargin:
                        24

                    verticalCenter:
                        parent.verticalCenter
                }

                spacing: 8

                // ------------------------------------------
                // Weather icon + temp
                // ------------------------------------------

                Row {
                    id: weatherSummary
                    width: parent.width
                    spacing: 12

                    // --------------------------------------
                    // Weather icon
                    // --------------------------------------

                    Item {
                        id: weatherIcon
                        width: 64
                        height: 58

                        FlatIcon {
                            anchors.fill: parent
                            name: card.isDaytime ? "weather-sun" : "weather-moon"
                            ink: card.accentColor
                        }

                        FlatIcon {
                            id: cloudIcon
                            anchors.fill: parent
                            name: "weather-cloud"
                            ink: card.accentColor

                            transform: Translate {
                                SequentialAnimation on y {
                                    running: cloudIcon.visible
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        from: 0
                                        to: -3
                                        duration: 2200
                                        easing.type: Easing.InOutSine
                                    }

                                    NumberAnimation {
                                        from: -3
                                        to: 0
                                        duration: 2200
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }
                        }
                    }

                    // --------------------------------------
                    // Temperature
                    // --------------------------------------

                    Column {
                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: weatherSummary.width - weatherIcon.width - weatherSummary.spacing

                        spacing: 2

                        PopText {
                            animate:
                                card.ready

                            text:
                                backend.weatherAvailable
                                    ? card.temperature + "°"
                                    : "--°"

                            color:
                                card.textColor

                            font {
                                family:
                                    card.family

                                pixelSize:
                                    35

                                weight:
                                    Font.Medium
                            }
                        }

                        Item {
                            id: conditionArea
                            width: parent.width
                            height: conditionText.implicitHeight
                            clip: true

                            PopText {
                                id: conditionText
                                animate: card.ready
                                text: card.condition
                                color: card.dimColor

                                font {
                                    family: card.family
                                    pixelSize: 13
                                }

                                x: 0

                                SequentialAnimation on x {
                                    running: conditionText.width > conditionArea.width
                                    loops: Animation.Infinite

                                    PauseAnimation { duration: 1000 }

                                    NumberAnimation {
                                        to: conditionArea.width - conditionText.width
                                        duration: 8000
                                        easing.type: Easing.InOutSine
                                    }

                                    PauseAnimation { duration: 1000 }

                                    NumberAnimation {
                                        to: 0
                                        duration: 8000
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------
                // High + low
                // ------------------------------------------

                Row {
                    spacing: 10

                    Text {
                        text:
                            "↑ "
                                + (backend.weatherAvailable ? card.high : "--")
                                + "°"

                        color:
                            card.dimColor

                        font {
                            family:
                                card.family

                            pixelSize:
                                12
                        }
                    }

                    Text {
                        text:
                            "↓ "
                                + (backend.weatherAvailable ? card.low : "--")
                                + "°"

                        color:
                            card.dimColor

                        font {
                            family:
                                card.family

                            pixelSize:
                                12
                        }
                    }

                    Text {
                        text: "⌁"

                        color:
                            Qt.alpha(
                                card.textColor,
                                0.55
                            )

                        font.pixelSize:
                            13
                    }

                    Text {
                        text: card.isDaytime ? "☼" : "☾"

                        color:
                            Qt.alpha(
                                card.textColor,
                                0.55
                            )

                        font.pixelSize:
                            12
                    }
                }

                // ------------------------------------------
                // Location
                // ------------------------------------------

                Row {
                    spacing: 6

                    Canvas {
                        width: 11
                        height: 14

                        anchors.verticalCenter:
                            parent.verticalCenter

                        property color pinColor:
                            card.dimColor

                        onPinColorChanged:
                            requestPaint()

                        onPaint: {
                            var ctx =
                                getContext("2d")

                            ctx.reset()

                            ctx.strokeStyle =
                                pinColor

                            ctx.lineWidth =
                                1.4

                            ctx.beginPath()

                            ctx.arc(
                                5.5,
                                5.2,
                                4,
                                Math.PI * 0.8,
                                Math.PI * 2.2
                            )

                            ctx.lineTo(
                                5.5,
                                13
                            )

                            ctx.closePath()

                            ctx.stroke()

                            ctx.beginPath()

                            ctx.arc(
                                5.5,
                                5.2,
                                1.4,
                                0,
                                Math.PI * 2
                            )

                            ctx.stroke()
                        }
                    }

                    Text {
                        text:
                            card.location

                        color:
                            card.dimColor

                        font {
                            family:
                                card.family

                            pixelSize:
                                12
                        }
                    }
                }
            }
        }
    }
}
