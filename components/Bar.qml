import QtQuick

Item {
    id: win

    width: 1340
    height: 80
    property date currentTime: new Date()

    signal managerRequested()
    signal wifiRequested()
    signal bluetoothRequested()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: win.currentTime = new Date()
    }


    // ==================================================
    // Background
    // ==================================================


    // ==================================================
    // Moving background circles
    // ==================================================


    // ==================================================
    // Top Bar
    // ==================================================

    Item {
        id: topBar

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top

            margins: 16
        }

        height: 48

        // --------------------------------------------------
        // Style — same family as ClockWeather
        // --------------------------------------------------

        property color surfaceColor: Theme.componentSurfaceFor("bar")


        property color textColor: Theme.text

        property color dimTextColor:
            Qt.alpha(textColor, 0.75)

        property color accentColor: Theme.accent

        property real cornerRadius:
            14



        readonly property string family:
            Qt.application.font.family

        // ==================================================
        // Intro animation
        // ==================================================

        opacity: 0

        transform: Translate {
            id: enterTransform
            y: -12
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

            from: -12
            to: 0

            duration: 700

            easing.type:
                Easing.OutCubic

            running: true
        }

        // ==================================================
        // Hover animation
        // ==================================================

        scale:
            topBarHover.hovered
                ? 1.006
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        HoverHandler {
            id: topBarHover
        }

        // ==================================================
        // Flat surface
        // ==================================================

        Rectangle {
            anchors.fill: parent
            radius: topBar.cornerRadius
            color: topBar.surfaceColor
        }

        // ==================================================
        // Left
        // ==================================================

        Row {
            id: leftRow

            anchors {
                left:
                    parent.left

                leftMargin:
                    14

                verticalCenter:
                    parent.verticalCenter
            }

            spacing:
                14

            // --------------------------------------------------
            // User
            // --------------------------------------------------

            Item {
                id: userBlock

                width:
                    96

                height:
                    28

                Row {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    spacing:
                        10

                    Rectangle {
                        width:
                            22

                        height:
                            22

                        radius:
                            11

                        color:
                            topBar.accentColor

                        Canvas {
                            anchors.centerIn:
                                parent

                            width:
                                12

                            height:
                                12

                            readonly property color themePaintColor: Theme.accentText
                            onThemePaintColorChanged: requestPaint()

                            onPaint: {
                                var ctx =
                                    getContext("2d")

                                ctx.reset()

                                ctx.strokeStyle =
                                    themePaintColor

                                ctx.lineWidth =
                                    1.5

                                ctx.beginPath()

                                ctx.arc(
                                    6,
                                    6,
                                    4,
                                    -1.0,
                                    2.2,
                                    false
                                )

                                ctx.stroke()

                                ctx.beginPath()

                                ctx.moveTo(
                                    6,
                                    2
                                )

                                ctx.lineTo(
                                    6,
                                    6
                                )

                                ctx.stroke()
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text:
                            backend.userName

                        color:
                            topBar.textColor

                        font {
                            family:
                                topBar.family

                            pixelSize:
                                14

                            weight:
                                Font.DemiBold
                        }
                    }
                }
            }

            // --------------------------------------------------
            // Workspaces
            // --------------------------------------------------

            Row {
                id: workspaceRow

                spacing:
                    8

                WorkspaceButton {
                    label: "1"
                    active: true
                }

                WorkspaceButton {
                    label: "2"
                }

                WorkspaceButton {
                    label: "3"
                }

                WorkspaceButton {
                    label: "4"
                }

                WorkspaceButton {
                    label: "○"
                    circleStyle: true
                }
            }
        }

        // ==================================================
        // Center
        // ==================================================

        Text {
            anchors.centerIn:
                parent

            text:
                Qt.formatDateTime(win.currentTime, "ddd, MMM d   hh:mm")

            color:
                topBar.textColor

            font {
                family:
                    topBar.family

                pixelSize:
                    15

                weight:
                    Font.DemiBold
            }
        }

        // ==================================================
        // Right
        // ==================================================

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: rightRow.width + 24
            height: 34
            radius: 11
            color: Theme.control
        }

        Row {
            id: rightRow

            anchors {
                right:
                    parent.right

                rightMargin:
                    22

                verticalCenter:
                    parent.verticalCenter
            }

            spacing:
                13

            StatusIcon {
                glyph:
                    Component { SpeakerGlyph { } }
            }

            StatusIcon {
                active:
                    backend.bluetoothEnabled

                tooltipTitle:
                    backend.bluetoothDeviceName

                tooltipDetail:
                    backend.bluetoothStatusText

                onClicked:
                    win.bluetoothRequested()

                glyph:
                    Component { BluetoothGlyph { } }
            }

            StatusIcon {
                active:
                    backend.wifiConnected

                tooltipTitle:
                    backend.wifiSsid

                tooltipDetail:
                    backend.wifiStatusText

                onClicked:
                    win.wifiRequested()

                glyph:
                    Component {
                        WifiGlyph {
                            connected:
                                backend.wifiConnected

                            strength:
                                backend.wifiSignalStrength
                        }
                    }
            }

            Item {
                visible: backend.batteryAvailable
                width:
                    66

                height:
                    22

                Row {
                    anchors.centerIn:
                        parent

                    spacing:
                        8

                    BatteryIcon { }

                    Text {
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text:
                            backend.batteryPercent + "%"

                        color:
                            topBar.textColor

                        font {
                            family:
                                topBar.family

                            pixelSize:
                                14

                            weight:
                                Font.DemiBold
                        }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 17
                color: Qt.rgba(1, 1, 1, 0.17)
            }

            StatusIcon {
                tooltipTitle:
                    "Components"

                tooltipDetail:
                    "Manage desktop modules"

                onClicked:
                    win.managerRequested()

                glyph:
                    Component { ManagerGlyph { } }
            }

            StatusIcon {
                glyph:
                    Component { SearchGlyph { } }
            }

            StatusIcon {
                glyph:
                    Component { PowerGlyph { } }
            }
        }
    }

    // ==================================================
    // Workspace Button
    // ==================================================

    component WorkspaceButton: Item {
        id: workspace

        property string label:
            "1"

        property bool active:
            false

        property bool circleStyle:
            false

        width:
            32

        height:
            26

        scale:
            workspaceHover.hovered
                ? 1.08
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
            }
        }

        Rectangle {
            anchors.fill:
                parent

            radius:
                workspace.circleStyle
                    ? height / 2
                    : 8

            color:
                workspace.active
                    ? topBar.accentColor
                    : (workspaceHover.hovered ? Theme.controlHover : Theme.control)

            Behavior on color {
                ColorAnimation {
                    duration:
                        140
                }
            }
        }

        Text {
            anchors.centerIn:
                parent

            text:
                workspace.label

            color:
                workspace.active
                    ? Theme.accentText
                    : topBar.textColor

            font {
                family:
                    topBar.family

                pixelSize:
                    13

                weight:
                    Font.DemiBold
            }
        }

        HoverHandler {
            id: workspaceHover
        }

        MouseArea {
            anchors.fill:
                parent

            cursorShape:
                Qt.PointingHandCursor
        }
    }

    // ==================================================
    // Status Icon
    // ==================================================

    component StatusIcon: Item {
        id: statusIcon

        property Component glyph
        property bool active:
            false

        property string tooltipTitle:
            ""

        property string tooltipDetail:
            ""

        signal clicked()

        width:
            24

        height:
            24

        scale:
            statusHover.hovered
                ? 1.12
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
            }
        }

        Rectangle {
            anchors.centerIn:
                parent

            width:
                30

            height:
                30

            radius:
                9

            color:
                statusIcon.active
                    ? Theme.selected
                    : (statusHover.hovered ? Theme.controlHover : Theme.control)

            Behavior on color {
                ColorAnimation {
                    duration:
                        140
                }
            }
        }

        Loader {
            anchors.centerIn:
                parent

            sourceComponent:
                statusIcon.glyph
        }

        Item {
            z:
                40

            visible:
                statusHover.hovered
                    && statusIcon.tooltipTitle !== ""

            opacity:
                visible
                    ? 1
                    : 0

            anchors.horizontalCenter:
                parent.horizontalCenter

            y:
                34

            width:
                172

            height:
                58

            Behavior on opacity {
                NumberAnimation {
                    duration:
                        120
                }
            }

            Rectangle {
                anchors.fill:
                    parent

                radius:
                    14

                color:
                    Theme.panelSurface
            }

            Column {
                anchors {
                    left:
                        parent.left

                    right:
                        parent.right

                    verticalCenter:
                        parent.verticalCenter

                    margins:
                        14
                }

                spacing:
                    3

                Text {
                    width:
                        parent.width

                    text:
                        statusIcon.tooltipTitle

                    color:
                        topBar.textColor

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            topBar.family

                        pixelSize:
                            13

                        weight:
                            Font.DemiBold
                    }
                }

                Text {
                    width:
                        parent.width

                    text:
                        statusIcon.tooltipDetail

                    color:
                        topBar.dimTextColor

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            topBar.family

                        pixelSize:
                            11
                    }
                }
            }
        }

        HoverHandler {
            id: statusHover
        }

        MouseArea {
            anchors.fill:
                parent

            anchors.margins:
                -4

            cursorShape:
                Qt.PointingHandCursor

            onClicked:
                statusIcon.clicked()
        }
    }

    // ==================================================
    // Battery
    // ==================================================

    component BatteryIcon: Item {
        width:
            26

        height:
            14

        Rectangle {
            x: 0
            y: 1

            width:
                22

            height:
                12

            radius:
                3

            color:
                Theme.control

            border.width:
                1

            border.color: Theme.text

            Rectangle {
                x: 2
                y: 2

                width:
                    18 * backend.batteryPercent / 100

                height:
                    6

                radius:
                    2

                color:
                    Theme.text
            }
        }

        Rectangle {
            x:
                22

            y:
                4

            width:
                3

            height:
                6

            radius:
                1.5

            color:
                Qt.rgba(
                    1,
                    1,
                    1,
                    0.85
                )
        }
    }

    // ==================================================
    // Speaker
    // ==================================================

    component SpeakerGlyph: Canvas {
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()
        width:
            20

        height:
            20

        onPaint: {
            var ctx =
                getContext("2d")

            ctx.reset()
            ctx.scale(20 / 18, 20 / 18)

            ctx.fillStyle =
                Theme.text

            ctx.strokeStyle =
                Theme.text

            ctx.lineWidth =
                1.6

            ctx.lineCap =
                "round"

            ctx.beginPath()

            ctx.moveTo(
                3,
                7
            )

            ctx.lineTo(
                6,
                7
            )

            ctx.lineTo(
                10,
                4
            )

            ctx.lineTo(
                10,
                14
            )

            ctx.lineTo(
                6,
                11
            )

            ctx.lineTo(
                3,
                11
            )

            ctx.closePath()
            ctx.fill()

            ctx.beginPath()

            ctx.arc(
                10,
                9,
                4,
                -0.7,
                0.7,
                false
            )

            ctx.stroke()

            ctx.beginPath()

            ctx.arc(
                10,
                9,
                6,
                -0.7,
                0.7,
                false
            )

            ctx.stroke()
        }
    }

    // ==================================================
    // Bluetooth
    // ==================================================

    component BluetoothGlyph: Canvas {
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()
        width:
            17

        height:
            20

        onPaint: {
            var ctx =
                getContext("2d")

            ctx.reset()
            ctx.scale(17 / 14, 20 / 18)

            ctx.strokeStyle =
                Theme.text

            ctx.lineWidth =
                1.8

            ctx.lineCap =
                "round"

            ctx.lineJoin =
                "round"

            ctx.beginPath()

            ctx.moveTo(
                7,
                1
            )

            ctx.lineTo(
                7,
                17
            )

            ctx.lineTo(
                12,
                12
            )

            ctx.lineTo(
                4,
                9
            )

            ctx.lineTo(
                12,
                6
            )

            ctx.lineTo(
                7,
                1
            )

            ctx.stroke()
        }
    }

    // ==================================================
    // WiFi
    // ==================================================

    component WifiGlyph: Canvas {
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()
        property bool connected:
            true

        property int strength:
            100

        width:
            20

        height:
            20

        onConnectedChanged:
            requestPaint()

        onStrengthChanged:
            requestPaint()

        onPaint: {
            var ctx =
                getContext("2d")

            ctx.reset()
            ctx.scale(20 / 18, 20 / 18)

            ctx.strokeStyle =
                connected
                    ? Theme.text
                    : Qt.alpha(Theme.text, 0.42)

            ctx.lineWidth =
                1.6

            ctx.lineCap =
                "round"

            if (connected && strength >= 55) {
                ctx.beginPath()

                ctx.arc(
                    9,
                    15,
                    7,
                    Math.PI * 1.20,
                    Math.PI * 1.80,
                    false
                )

                ctx.stroke()
            }

            if (connected && strength >= 28) {
                ctx.beginPath()

                ctx.arc(
                    9,
                    15,
                    4.5,
                    Math.PI * 1.22,
                    Math.PI * 1.78,
                    false
                )

                ctx.stroke()
            }

            ctx.beginPath()

            ctx.arc(
                9,
                15,
                2,
                Math.PI * 1.25,
                Math.PI * 1.75,
                false
            )

            ctx.stroke()

            ctx.beginPath()

            ctx.fillStyle =
                Theme.text

            ctx.arc(
                9,
                15,
                1.2,
                0,
                Math.PI * 2
            )

            ctx.fill()

            if (!connected) {
                ctx.strokeStyle =
                    Qt.alpha(Theme.text, 0.72)

                ctx.lineWidth =
                    1.7

                ctx.beginPath()

                ctx.moveTo(
                    4,
                    4
                )

                ctx.lineTo(
                    14,
                    14
                )

                ctx.stroke()
            }
        }
    }

    // ==================================================
    // Manager
    // ==================================================

    component ManagerGlyph: Canvas {
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()
        width:
            20

        height:
            20

        onPaint: {
            var ctx =
                getContext("2d")

            ctx.reset()
            ctx.scale(20 / 18, 20 / 18)

            ctx.strokeStyle =
                Theme.text

            ctx.fillStyle =
                Theme.text

            ctx.lineWidth =
                1.7

            ctx.lineCap =
                "round"

            ctx.lineJoin =
                "round"

            ctx.beginPath()

            ctx.arc(
                9,
                9,
                3,
                0,
                Math.PI * 2
            )

            ctx.stroke()

            for (var i = 0; i < 8; ++i) {
                var angle = i * Math.PI / 4
                var inner = 5.4
                var outer = 7.2
                var x1 = 9 + Math.cos(angle) * inner
                var y1 = 9 + Math.sin(angle) * inner
                var x2 = 9 + Math.cos(angle) * outer
                var y2 = 9 + Math.sin(angle) * outer

                ctx.beginPath()
                ctx.moveTo(x1, y1)
                ctx.lineTo(x2, y2)
                ctx.stroke()
            }
        }
    }

    // ==================================================
    // Search
    // ==================================================

    component SearchGlyph: Canvas {
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()
        width:
            20

        height:
            20

        onPaint: {
            var ctx =
                getContext("2d")

            ctx.reset()
            ctx.scale(20 / 18, 20 / 18)

            ctx.strokeStyle =
                Theme.text

            ctx.lineWidth =
                1.8

            ctx.lineCap =
                "round"

            ctx.beginPath()

            ctx.arc(
                7.5,
                7.5,
                4.5,
                0,
                Math.PI * 2
            )

            ctx.stroke()

            ctx.beginPath()

            ctx.moveTo(
                11,
                11
            )

            ctx.lineTo(
                15,
                15
            )

            ctx.stroke()
        }
    }

    // ==================================================
    // Power
    // ==================================================

    component PowerGlyph: Canvas {
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()
        width:
            20

        height:
            20

        onPaint: {
            var ctx =
                getContext("2d")

            ctx.reset()
            ctx.scale(20 / 18, 20 / 18)

            ctx.strokeStyle =
                Theme.text

            ctx.lineWidth =
                1.8

            ctx.lineCap =
                "round"

            ctx.beginPath()

            ctx.arc(
                9,
                10,
                6,
                -Math.PI / 4,
                Math.PI * 1.25,
                false
            )

            ctx.stroke()

            ctx.beginPath()

            ctx.moveTo(
                9,
                2
            )

            ctx.lineTo(
                9,
                8
            )

            ctx.stroke()
        }
    }
}
