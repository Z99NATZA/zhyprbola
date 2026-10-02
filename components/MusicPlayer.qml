import QtQuick

Item {
    id: win

    width: 390
    height: 230


    // ==================================================
    // Background
    // ==================================================



    // ==================================================
    // Music card
    // ==================================================

    Item {
        id: card

        anchors.centerIn: parent

        width: 390
        height: 230

        property string songTitle: backend.songTitle
        property string artist: backend.artist
        property string coverSource: backend.coverSource

        property bool liked: false
        property bool playing: backend.playing
        property bool shuffle: false
        property bool repeat: false

        property int currentSeconds: backend.positionSeconds
        property int totalSeconds: backend.durationSeconds

        readonly property real progress:
            totalSeconds > 0
                ? currentSeconds / totalSeconds
                : 0

        property color textColor: Theme.text

        property color glassColor: Theme.cardSurface

        property color borderColor: Theme.cardBorder

        property color accentColor: Theme.accent

        property real cornerRadius: 24
        property real rimStrength: 0.20
        property int rimSize: 4

        readonly property color dimColor:
            Qt.alpha(textColor, 0.75)

        readonly property string family:
            Qt.application.font.family

        function formatTime(seconds) {
            var minute = Math.floor(seconds / 60)
            var second = seconds % 60

            return minute
                + ":"
                + (second < 10 ? "0" : "")
                + second
        }

        scale:
            hover.hovered
                ? 1.02
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

        // ==================================================
        // Glass
        // ==================================================

        Rectangle {
            anchors.fill: parent

            radius: card.cornerRadius
            color: card.glassColor

            border.width: 1
            border.color: card.borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1

                radius: parent.radius - 1

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.01)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(1, 1, 1, 0.03)
                    }
                }
            }

            Repeater {
                model: card.rimSize

                delegate: Rectangle {
                    required property int index

                    anchors.fill: parent
                    anchors.margins: index + 1

                    radius:
                        Math.max(
                            0,
                            card.cornerRadius - 1 - index
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
                                    1 - index / card.rimSize,
                                    2
                                )
                        )
                }
            }

            Rectangle {
                id: sheen

                property real p: 0

                anchors.fill: parent
                anchors.margins: 1

                radius: parent.radius - 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position:
                            Math.max(
                                0.01,
                                Math.min(0.99, sheen.p)
                            )

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.12
                                    * Math.sin(
                                        Math.PI * sheen.p
                                    )
                            )
                    }

                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }

                SequentialAnimation on p {
                    loops: Animation.Infinite

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

        // ==================================================
        // Album
        // ==================================================

        Rectangle {
            id: album

            anchors {
                left: parent.left
                top: parent.top

                leftMargin: 19
                topMargin: 17
            }

            width: 96
            height: 96

            radius: 15
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.sky ? "#D7EEFF" : (Theme.light ? "#B8DCEB" : "#efb1d2")
                }

                GradientStop {
                    position: 1
                    color: Theme.sky ? "#70B5F3" : (Theme.light ? "#5B96B8" : "#9377b3")
                }
            }

            Image {
                anchors.fill: parent

                source: card.coverSource

                visible:
                    card.coverSource !== ""

                fillMode:
                    Image.PreserveAspectCrop

                smooth: true
            }

            Repeater {
                visible:
                    card.coverSource === ""

                model: 6

                delegate: Rectangle {
                    required property int index

                    width: 17 + index * 2
                    height: width

                    radius: width / 2

                    x: -5 + index * 16
                    y: 68 - index * 12

                    color: "#FFFFFF"
                    opacity: 0.18
                }
            }

            Text {
                anchors.centerIn: parent

                visible:
                    card.coverSource === ""

                text: "♪"

                color: "#FFFFFF"

                font {
                    family: card.family
                    pixelSize: 34
                }
            }

            Rectangle {
                anchors.fill: parent

                radius: parent.radius

                color: "transparent"

                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
            }
        }

        // ==================================================
        // Song info
        // ==================================================

        Column {
            anchors {
                left: album.right
                leftMargin: 15

                verticalCenter:
                    album.verticalCenter
            }

            anchors.verticalCenterOffset: -1

            spacing: 6

            Text {
                width: 172

                text: card.songTitle

                color: card.textColor

                elide: Text.ElideRight

                font {
                    family: card.family
                    pixelSize: 17
                    weight: Font.DemiBold
                }
            }

            Text {
                width: 172

                text: card.artist

                color: card.dimColor

                elide: Text.ElideRight

                font {
                    family: card.family
                    pixelSize: 14
                }
            }
        }

        // ==================================================
        // Heart
        // ==================================================

        Item {
            visible: false
            anchors {
                right: parent.right
                top: parent.top

                rightMargin: 22
                topMargin: 26
            }

            width: 32
            height: 32

            Text {
                anchors.centerIn: parent

                text:
                    card.liked
                        ? "♥"
                        : "♡"

                color: card.accentColor

                font {
                    family: card.family
                    pixelSize: 20
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked:
                    card.liked =
                        !card.liked
            }
        }

        // ==================================================
        // Bottom area
        // ==================================================

        Item {
            id: bottomArea

            anchors {
                left: parent.left
                right: parent.right

                leftMargin: 19
                rightMargin: 19

                top: album.bottom
                topMargin: 13

                bottom: parent.bottom
                bottomMargin: 31
            }

            // ==================================================
            // Progress
            // ==================================================

            Item {
                id: progressArea

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }

                height: 10

                Rectangle {
                    id: track

                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: parent.width
                    height: 6

                    radius: 3

                    color:
                        Qt.rgba(1, 1, 1, 0.30)
                }

                Rectangle {
                    anchors {
                        left: track.left
                        verticalCenter:
                            track.verticalCenter
                    }

                    width:
                        track.width
                            * card.progress

                    height:
                        track.height

                    radius:
                        track.radius

                    color:
                        card.accentColor
                }

                Rectangle {
                    width: 10
                    height: 10

                    radius: 5

                    anchors.verticalCenter:
                        parent.verticalCenter

                    color: Theme.light ? Theme.accent : "#F8B6D7"

                    x:
                        Math.max(
                            0,
                            Math.min(
                                track.width - width,
                                track.width
                                    * card.progress
                                    - width / 2
                            )
                        )
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: backend.hasPlayer && card.totalSeconds > 0

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        var p =
                            mouse.x / width

                        backend.seek(Math.round(card.totalSeconds * p))
                    }
                }
            }

            // ==================================================
            // Time row
            // ==================================================

            Item {
                id: timeRow

                anchors {
                    left: parent.left
                    right: parent.right

                    top: progressArea.bottom
                    topMargin: 1
                }

                height: 20

                Text {
                    anchors.left:
                        parent.left

                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        card.formatTime(
                            card.currentSeconds
                        )

                    color:
                        card.dimColor

                    font {
                        family:
                            card.family

                        pixelSize: 12
                    }
                }

                Text {
                    anchors.right:
                        parent.right

                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        card.formatTime(
                            card.totalSeconds
                        )

                    color:
                        card.dimColor

                    font {
                        family:
                            card.family

                        pixelSize: 12
                    }
                }
            }

            // ==================================================
            // Controls
            // ==================================================

            Item {
                id: controls

                anchors {
                    left: parent.left
                    right: parent.right

                    top: timeRow.bottom
                    topMargin: 0

                    bottom: parent.bottom
                }

                // --------------------------------------------------
                // Shuffle
                // --------------------------------------------------

                Text {
                    visible: false
                    anchors {
                        left: parent.left
                        leftMargin: 10

                        verticalCenter:
                            parent.verticalCenter
                    }

                    text: "⤨"

                    color:
                        card.shuffle
                            ? card.accentColor
                            : card.dimColor

                    font {
                        family: card.family
                        pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -9

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            card.shuffle =
                                !card.shuffle
                    }
                }

                // --------------------------------------------------
                // Previous
                // --------------------------------------------------

                Item {
                    anchors {
                        left:
                            parent.left

                        leftMargin:
                            parent.width * 0.25 - width / 2

                        verticalCenter:
                            parent.verticalCenter
                    }

                    width: 27
                    height: 28

                    Rectangle {
                        x: 5
                        y: 5

                        width: 2
                        height: 18

                        radius: 1

                        color:
                            card.dimColor
                    }

                    Canvas {
                        anchors.fill: parent

                        onPaint: {
                            var ctx =
                                getContext("2d")

                            ctx.reset()

                            ctx.fillStyle =
                                card.dimColor

                            ctx.beginPath()

                            ctx.moveTo(21, 5)
                            ctx.lineTo(9, 14)
                            ctx.lineTo(21, 23)

                            ctx.closePath()
                            ctx.fill()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: backend.hasPlayer
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.previousTrack()
                    }
                }

                // --------------------------------------------------
                // Play / Pause
                // --------------------------------------------------

                Item {
                    id: playButton

                    anchors.centerIn: parent

                    width: 42
                    height: 42

                    scale: playHover.hovered ? 1.06 : 1

                    Behavior on scale {
                        SpringAnimation {
                            spring: 3
                            damping: 0.28
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: card.accentColor
                    }

                    Item {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        visible: card.playing

                        Rectangle {
                            x: 2
                            y: 1
                            width: 4
                            height: 15
                            radius: 1.5
                            color: Theme.light ? Theme.accentText : "#584158"
                        }

                        Rectangle {
                            x: 10
                            y: 1
                            width: 4
                            height: 15
                            radius: 1.5
                            color: Theme.light ? Theme.accentText : "#584158"
                        }
                    }

                    Canvas {
                        anchors.centerIn: parent
                        width: 18
                        height: 20
                        visible: !card.playing

                        readonly property color themePaintColor: Theme.light ? Theme.accentText : "#584158"
                        onThemePaintColorChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = themePaintColor

                            ctx.beginPath()
                            ctx.moveTo(4, 3)
                            ctx.lineTo(14, 10)
                            ctx.lineTo(4, 17)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }

                    HoverHandler {
                        id: playHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: backend.hasPlayer
                        cursorShape: Qt.PointingHandCursor

                        onClicked: backend.togglePlayback()
                    }
                }

                // --------------------------------------------------
                // Next
                // --------------------------------------------------

                Item {
                    anchors {
                        right:
                            parent.right

                        rightMargin:
                            parent.width * 0.25 - width / 2

                        verticalCenter:
                            parent.verticalCenter
                    }

                    width: 27
                    height: 28

                    Rectangle {
                        x: 20
                        y: 5

                        width: 2
                        height: 18

                        radius: 1

                        color:
                            card.dimColor
                    }

                    Canvas {
                        anchors.fill: parent

                        onPaint: {
                            var ctx =
                                getContext("2d")

                            ctx.reset()

                            ctx.fillStyle =
                                card.dimColor

                            ctx.beginPath()

                            ctx.moveTo(6, 5)
                            ctx.lineTo(18, 14)
                            ctx.lineTo(6, 23)

                            ctx.closePath()
                            ctx.fill()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: backend.hasPlayer
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.nextTrack()
                    }
                }

                // --------------------------------------------------
                // Repeat
                // --------------------------------------------------

                Text {
                    visible: false
                    anchors {
                        right: parent.right
                        rightMargin: 10

                        verticalCenter:
                            parent.verticalCenter
                    }

                    text: "↻"

                    color:
                        card.repeat
                            ? card.accentColor
                            : card.dimColor

                    font {
                        family: card.family
                        pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -9

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            card.repeat =
                                !card.repeat
                    }
                }
            }
        }
    }
}
