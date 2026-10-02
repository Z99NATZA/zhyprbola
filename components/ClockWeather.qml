import QtQuick

Item {
    id: win

    width: 440
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

        width: 440
        height: 172

        // ----------------------------------------------
        // Data
        // ----------------------------------------------

        property date now: new Date()

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

        property color glassColor: Theme.cardSurface

        property color borderColor: Theme.cardBorder

        property color accentColor: Theme.clockAccent

        property real cornerRadius: 26

        property real rimStrength: 0.20

        property int rimSize: 4

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
        // Intro + hover animation
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

        scale: hover.hovered
            ? 1.025
            : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        HoverHandler {
            id: hover
        }

        // --------------------------------------------------
        // Glass body
        // --------------------------------------------------

        Rectangle {
            anchors.fill: parent

            radius: card.cornerRadius

            color: card.glassColor

            border.width: 1
            border.color: card.borderColor

            // ----------------------------------------------
            // Glass soft gradient
            // ----------------------------------------------

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1

                radius: parent.radius - 1

                gradient: Gradient {
                    GradientStop {
                        position: 0.0

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.07
                            )
                    }

                    GradientStop {
                        position: 0.50

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.01
                            )
                    }

                    GradientStop {
                        position: 1.0

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.03
                            )
                    }
                }
            }

            // ----------------------------------------------
            // Inner rim
            // ----------------------------------------------

            Repeater {
                model: card.rimSize

                delegate: Rectangle {
                    required property int index

                    anchors.fill: parent

                    anchors.margins:
                        1 + index

                    radius: Math.max(
                        0,
                        card.cornerRadius
                            - 1
                            - index
                    )

                    color: "transparent"

                    border.width: 1

                    border.color:
                        Qt.rgba(
                            1,
                            1,
                            1,
                            card.rimStrength
                                * Math.pow(
                                    1
                                        - index
                                        / card.rimSize,
                                    2
                                )
                        )
                }
            }

            // ----------------------------------------------
            // Moving sheen
            // ----------------------------------------------

            Rectangle {
                id: sheen

                property real p: 0

                anchors.fill: parent
                anchors.margins: 1

                radius: parent.radius - 1

                gradient: Gradient {
                    orientation:
                        Gradient.Horizontal

                    GradientStop {
                        position: 0.0

                        color:
                            "transparent"
                    }

                    GradientStop {
                        position:
                            Math.max(
                                0.01,
                                Math.min(
                                    0.99,
                                    sheen.p
                                )
                            )

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.12
                                    * Math.sin(
                                        Math.PI
                                            * sheen.p
                                    )
                            )
                    }

                    GradientStop {
                        position: 1.0

                        color:
                            "transparent"
                    }
                }

                SequentialAnimation on p {
                    loops:
                        Animation.Infinite

                    PauseAnimation {
                        duration: 5000
                    }

                    NumberAnimation {
                        from: 0
                        to: 1

                        duration: 1800

                        easing.type:
                            Easing.InOutSine
                    }
                }
            }
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

            width:
                parent.width * 0.51

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
        // Divider
        // --------------------------------------------------

        Rectangle {
            x: left.width

            anchors.verticalCenter:
                parent.verticalCenter

            width: 1
            height: 118

            gradient: Gradient {
                GradientStop {
                    position: 0.0

                    color:
                        "transparent"
                }

                GradientStop {
                    position: 0.5

                    color:
                        Qt.alpha(
                            card.textColor,
                            0.40
                        )
                }

                GradientStop {
                    position: 1.0

                    color:
                        "transparent"
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

                    verticalCenter:
                        parent.verticalCenter
                }

                spacing: 8

                // ------------------------------------------
                // Weather icon + temp
                // ------------------------------------------

                Row {
                    spacing: 12

                    // --------------------------------------
                    // Weather icon
                    // --------------------------------------

                    Item {
                        width: 64
                        height: 58

                        // Soft halo

                        Rectangle {
                            anchors.centerIn:
                                parent

                            width: 54
                            height: 54

                            radius:
                                width / 2

                            color:
                                Qt.alpha(
                                    card.accentColor,
                                    0.06
                                )

                            SequentialAnimation on scale {
                                loops:
                                    Animation.Infinite

                                NumberAnimation {
                                    to: 1.15

                                    duration:
                                        2200

                                    easing.type:
                                        Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 0.93

                                    duration:
                                        2200

                                    easing.type:
                                        Easing.InOutSine
                                }
                            }
                        }

                        Item {
                            id: weatherIcon

                            anchors.fill:
                                parent

                            SequentialAnimation on y {
                                loops:
                                    Animation.Infinite

                                NumberAnimation {
                                    to: -3

                                    duration:
                                        1800

                                    easing.type:
                                        Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 2

                                    duration:
                                        1800

                                    easing.type:
                                        Easing.InOutSine
                                }
                            }

                            SequentialAnimation on rotation {
                                loops:
                                    Animation.Infinite

                                NumberAnimation {
                                    to: 2

                                    duration:
                                        2400

                                    easing.type:
                                        Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: -2

                                    duration:
                                        2400

                                    easing.type:
                                        Easing.InOutSine
                                }
                            }

                            Canvas {
                                anchors.fill:
                                    parent

                                onPaint: {
                                    var ctx =
                                        getContext("2d")

                                    ctx.reset()

                                    // ----------------------
                                    // Moon
                                    // ----------------------

                                    var moon =
                                        ctx.createLinearGradient(
                                            8,
                                            6,
                                            40,
                                            42
                                        )

                                    moon.addColorStop(
                                        0,
                                        "#FFF6D8"
                                    )

                                    moon.addColorStop(
                                        1,
                                        "#E4DDF5"
                                    )

                                    ctx.fillStyle =
                                        moon

                                    ctx.beginPath()

                                    ctx.arc(
                                        24,
                                        21,
                                        17,
                                        0,
                                        Math.PI * 2
                                    )

                                    ctx.fill()

                                    // Moon cutout

                                    ctx.globalCompositeOperation =
                                        "destination-out"

                                    ctx.beginPath()

                                    ctx.arc(
                                        35,
                                        14,
                                        14,
                                        0,
                                        Math.PI * 2
                                    )

                                    ctx.fill()

                                    ctx.globalCompositeOperation =
                                        "source-over"

                                    // ----------------------
                                    // Cloud
                                    // ----------------------

                                    var cloud =
                                        ctx.createLinearGradient(
                                            0,
                                            27,
                                            0,
                                            58
                                        )

                                    cloud.addColorStop(
                                        0,
                                        "#FFFFFF"
                                    )

                                    cloud.addColorStop(
                                        1,
                                        "#D3D9EA"
                                    )

                                    ctx.fillStyle =
                                        cloud

                                    ctx.beginPath()

                                    ctx.arc(
                                        22,
                                        46,
                                        9,
                                        0,
                                        Math.PI * 2
                                    )

                                    ctx.fill()

                                    ctx.beginPath()

                                    ctx.arc(
                                        36,
                                        39,
                                        13,
                                        0,
                                        Math.PI * 2
                                    )

                                    ctx.fill()

                                    ctx.beginPath()

                                    ctx.arc(
                                        50,
                                        46,
                                        9,
                                        0,
                                        Math.PI * 2
                                    )

                                    ctx.fill()

                                    ctx.fillRect(
                                        22,
                                        46,
                                        28,
                                        9
                                    )
                                }
                            }

                            // ----------------------------------
                            // Sparkle 1
                            // ----------------------------------

                            Text {
                                x: 47
                                y: 1

                                text: "✦"

                                color:
                                    card.accentColor

                                font.pixelSize:
                                    11

                                SequentialAnimation on opacity {
                                    loops:
                                        Animation.Infinite

                                    NumberAnimation {
                                        to: 0.2

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

                            // ----------------------------------
                            // Sparkle 2
                            // ----------------------------------

                            Text {
                                x: 57
                                y: 14

                                text: "✦"

                                color:
                                    card.accentColor

                                font.pixelSize:
                                    7

                                SequentialAnimation on opacity {
                                    loops:
                                        Animation.Infinite

                                    NumberAnimation {
                                        to: 1

                                        duration:
                                            700
                                    }

                                    NumberAnimation {
                                        to: 0.2

                                        duration:
                                            1100
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

                        PopText {
                            animate:
                                card.ready

                            text:
                                card.condition

                            color:
                                card.dimColor

                            font {
                                family:
                                    card.family

                                pixelSize:
                                    13
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
                        text: "☼"

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
