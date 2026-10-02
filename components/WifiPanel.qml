import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    property bool standalone: false
    property string activeTab: "networks"
    readonly property string family: Qt.application.font.family
    readonly property color glassColor: Theme.panelSurface
    readonly property color borderColor: Theme.panelBorder
    readonly property color textColor: Theme.text
    readonly property color dimTextColor: Qt.alpha(textColor, 0.68)
    readonly property color accentColor: Theme.accent
    readonly property color accentTextColor: Theme.accentText

    signal closeRequested()

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 110

    onOpenedChanged: {
        if (opened)
            backend.scanWifiNetworks()
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        visible: !panelRoot.standalone
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
    }

    MouseArea {
        visible: !panelRoot.standalone
        anchors.fill: parent
        onClicked: panelRoot.closeRequested()
    }

    Rectangle {
        id: panel

        anchors.right: panelRoot.standalone ? undefined : parent.right
        anchors.top: panelRoot.standalone ? undefined : parent.top
        anchors.rightMargin: panelRoot.standalone ? 0 : 34
        anchors.topMargin: panelRoot.standalone ? 0 : 84
        width: panelRoot.standalone ? parent.width : 430
        height: panelRoot.standalone ? parent.height : 560
        radius: 18
        color: panelRoot.glassColor
        border.width: 1
        border.color: panelRoot.borderColor

        transform: Translate {
            y: panelRoot.opened ? 0 : -10

            Behavior on y {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.09)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(1, 1, 1, 0.02)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors {
                fill: parent
                margins: 20
            }

            spacing: 14

            Row {
                width: parent.width
                height: 34
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - closeButton.width - parent.spacing
                    text: "Wi-Fi"
                    color: panelRoot.textColor
                    elide: Text.ElideRight
                    font {
                        family: panelRoot.family
                        pixelSize: 22
                        weight: Font.DemiBold
                    }
                }

                IconButton {
                    id: closeButton
                    label: "x"
                    onClicked: panelRoot.closeRequested()
                }
            }

            Rectangle {
                id: hero

                width: parent.width
                height: 148
                radius: 14
                color: Theme.control
                border.width: 1
                border.color: Theme.controlBorder

                SignalOrb {
                    id: signalOrb
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                    }

                    strength: backend.wifiSignalStrength
                    powered: backend.wifiEnabled
                    connected: backend.wifiConnected
                }

                Column {
                    anchors {
                        left: signalOrb.right
                        right: powerButton.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                        rightMargin: 14
                    }

                    spacing: 6

                    Text {
                        width: parent.width
                        text: backend.wifiSsid
                        color: panelRoot.textColor
                        elide: Text.ElideRight
                        font {
                            family: panelRoot.family
                            pixelSize: 20
                            weight: Font.DemiBold
                        }
                    }

                    Text {
                        width: parent.width
                        text: backend.wifiStatusText
                        color: panelRoot.dimTextColor
                        elide: Text.ElideRight
                        font {
                            family: panelRoot.family
                            pixelSize: 12
                        }
                    }

                    Row {
                        spacing: 8

                        Pill {
                            label: backend.wifiEnabled ? "Radio on" : "Radio off"
                            active: backend.wifiEnabled
                        }

                        Pill {
                            label: backend.wifiConnected ? "Connected" : "Idle"
                            active: backend.wifiConnected
                        }
                    }
                }

                PowerButton {
                    id: powerButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 18
                    }

                    checked: backend.wifiEnabled
                    onClicked: backend.setWifiEnabled(!backend.wifiEnabled)
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: 8

                TabButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Networks"
                    active: panelRoot.activeTab === "networks"
                    onClicked: panelRoot.activeTab = "networks"
                }

                TabButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Details"
                    active: panelRoot.activeTab === "details"
                    onClicked: panelRoot.activeTab = "details"
                }
            }

            Item {
                width: parent.width
                height: 224

                Item {
                    anchors.fill: parent
                    visible: panelRoot.activeTab === "networks"

                    Row {
                        id: networkHeader

                        width: parent.width
                        height: 34
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - scanButton.width - parent.spacing
                            text: "Available networks"
                            color: panelRoot.textColor
                            elide: Text.ElideRight
                            font {
                                family: panelRoot.family
                                pixelSize: 14
                                weight: Font.DemiBold
                            }
                        }

                        TextButton {
                            id: scanButton
                            width: 76
                            label: "Scan"
                            onClicked: backend.scanWifiNetworks()
                        }
                    }

                    ListView {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: networkHeader.bottom
                            bottom: parent.bottom
                            topMargin: 8
                        }

                        clip: true
                        spacing: 8
                        model: backend.wifiNetworks

                        delegate: NetworkRow {
                            width: ListView.view.width
                            ssid: modelData["ssid"] || ""
                            signal: modelData["signal"] || 0
                            security: modelData["security"] || "Open"
                            secure: modelData["secure"] || false
                            active: modelData["active"] || false
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: backend.wifiNetworks.length === 0
                        text: backend.wifiEnabled ? "No networks found" : "Wi-Fi is off"
                        color: panelRoot.dimTextColor
                        font {
                            family: panelRoot.family
                            pixelSize: 13
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: panelRoot.activeTab === "details"

                    InfoRow {
                        label: "Network"
                        value: backend.wifiConnected ? backend.wifiSsid : "Not connected"
                    }

                    InfoRow {
                        label: "Signal"
                        value: backend.wifiConnected ? backend.wifiSignalStrength + "%" : "--"
                    }

                    InfoRow {
                        label: "Radio"
                        value: backend.wifiEnabled ? "On" : "Off"
                    }

                    InfoRow {
                        label: "Backend"
                        value: "NetworkManager"
                    }
                }
            }

            Row {
                width: parent.width
                height: 36
                spacing: 10

                TextButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Refresh"
                    onClicked: backend.refreshStatus()
                }

                TextButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Settings"
                    onClicked: backend.openWifiSettings()
                }
            }
        }
    }

    component NetworkRow: Rectangle {
        id: row

        property string ssid: ""
        property int signal: 0
        property string security: ""
        property bool secure: false
        property bool active: false

        height: 48
        radius: 9
        color: active
            ? Theme.selected
            : (rowMouse.containsMouse ? Theme.controlHover : Theme.control)
        border.width: 1
        border.color: active
            ? Theme.selectedBorder
            : Theme.control

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        WifiGlyphSmall {
            id: rowIcon
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }
            strength: row.signal
            active: row.active
        }

        Column {
            anchors {
                left: rowIcon.right
                right: actionLabel.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
                rightMargin: 10
            }

            spacing: 2

            Text {
                width: parent.width
                text: row.ssid
                color: panelRoot.textColor
                elide: Text.ElideRight
                font {
                    family: panelRoot.family
                    pixelSize: 13
                    weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                text: row.signal + "%  " + (row.secure ? row.security : "Open")
                color: panelRoot.dimTextColor
                elide: Text.ElideRight
                font {
                    family: panelRoot.family
                    pixelSize: 11
                }
            }
        }

        Text {
            id: actionLabel
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 12
            }

            width: 68
            horizontalAlignment: Text.AlignRight
            text: row.active ? "Current" : (rowMouse.containsMouse ? "Connect" : (row.secure ? "Locked" : "Open"))
            color: row.active ? panelRoot.accentColor : panelRoot.dimTextColor
            elide: Text.ElideRight
            font {
                family: panelRoot.family
                pixelSize: 11
                weight: Font.DemiBold
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (!row.active)
                    backend.connectWifiNetwork(row.ssid)
            }
        }
    }

    component InfoRow: Rectangle {
        id: row

        property string label: ""
        property string value: ""

        width: parent.width
        height: 40
        radius: 9
        color: Theme.control
        border.width: 1
        border.color: Theme.control

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }

            text: row.label
            color: panelRoot.dimTextColor
            font {
                family: panelRoot.family
                pixelSize: 12
            }
        }

        Text {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 12
            }

            width: parent.width * 0.58
            horizontalAlignment: Text.AlignRight
            text: row.value
            color: panelRoot.textColor
            elide: Text.ElideRight
            font {
                family: panelRoot.family
                pixelSize: 12
                weight: Font.DemiBold
            }
        }
    }

    component Pill: Rectangle {
        property string label: ""
        property bool active: false

        width: pillText.width + 18
        height: 22
        radius: 11
        color: active ? Theme.selected : Theme.control
        border.width: 1
        border.color: active ? Theme.selectedBorder : Theme.control

        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: parent.active ? panelRoot.accentColor : panelRoot.dimTextColor
            font {
                family: panelRoot.family
                pixelSize: 10
                weight: Font.DemiBold
            }
        }
    }

    component TabButton: Item {
        id: button

        property string label: ""
        property bool active: false
        signal clicked()

        height: 34

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: button.active
                ? panelRoot.accentColor
                : (buttonMouse.containsMouse ? Theme.controlHover : Theme.control)
            border.width: button.active ? 0 : 1
            border.color: Theme.controlBorder

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.active ? panelRoot.accentTextColor : panelRoot.textColor
            font {
                family: panelRoot.family
                pixelSize: 13
                weight: Font.DemiBold
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component TextButton: Item {
        id: button

        property string label: ""
        signal clicked()

        height: 36

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: buttonMouse.containsMouse
                ? Theme.controlHover
                : Theme.control
            border.width: 1
            border.color: Theme.controlBorder

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.label
            color: panelRoot.textColor
            font {
                family: panelRoot.family
                pixelSize: 13
                weight: Font.DemiBold
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component IconButton: Item {
        id: button

        property string label: ""
        signal clicked()

        width: 30
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: buttonMouse.containsMouse
                ? Theme.controlHover
                : Theme.control
            border.width: 1
            border.color: Theme.controlBorder
        }

        Text {
            anchors.centerIn: parent
            text: button.label
            color: panelRoot.textColor
            font {
                family: panelRoot.family
                pixelSize: 14
                weight: Font.DemiBold
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component PowerButton: Item {
        id: control

        property bool checked: false
        signal clicked()

        width: 56
        height: 56

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: control.checked
                ? panelRoot.accentColor
                : (powerMouse.containsMouse ? Theme.controlHover : Theme.control)
            border.width: control.checked ? 0 : 1
            border.color: Theme.controlBorder

            Behavior on color {
                ColorAnimation { duration: 160 }
            }
        }

        Canvas {
            anchors.centerIn: parent
            readonly property color themePaintColor: Theme.text
            onThemePaintColorChanged: requestPaint()
            width: 22
            height: 22
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = control.checked ? panelRoot.accentTextColor : panelRoot.textColor
                ctx.lineWidth = 2.1
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(11, 3)
                ctx.lineTo(11, 11)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(11, 12, 7, -Math.PI * 0.72, Math.PI * 1.72)
                ctx.stroke()
            }
        }

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }

    component WifiGlyphSmall: Canvas {
        id: glyph
        readonly property color themePaintColor: Theme.text
        onThemePaintColorChanged: requestPaint()

        property int strength: 0
        property bool active: false

        width: 22
        height: 22

        onStrengthChanged: requestPaint()
        onActiveChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.scale(22 / 18, 22 / 18)
            ctx.strokeStyle = active ? panelRoot.accentColor : panelRoot.textColor
            ctx.fillStyle = ctx.strokeStyle
            ctx.globalAlpha = active ? 1 : 0.82
            ctx.lineWidth = 1.6
            ctx.lineCap = "round"

            if (strength >= 55) {
                ctx.beginPath()
                ctx.arc(9, 15, 7, Math.PI * 1.20, Math.PI * 1.80, false)
                ctx.stroke()
            }
            if (strength >= 28) {
                ctx.beginPath()
                ctx.arc(9, 15, 4.5, Math.PI * 1.22, Math.PI * 1.78, false)
                ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(9, 15, 1.2, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    component SignalOrb: Item {
        id: orb

        property int strength: 0
        property bool powered: false
        property bool connected: false

        width: 86
        height: 86

        Canvas {
            id: orbCanvas
            readonly property color themePaintColor: Theme.text
            onThemePaintColorChanged: requestPaint()

            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                var center = width / 2
                var radius = 35
                var start = -Math.PI / 2
                var clamped = Math.max(0, Math.min(100, orb.strength))
                var end = start + Math.PI * 2 * clamped / 100

                ctx.reset()
                ctx.lineWidth = 7
                ctx.lineCap = "round"
                ctx.strokeStyle = Theme.track
                ctx.beginPath()
                ctx.arc(center, center, radius, 0, Math.PI * 2)
                ctx.stroke()

                ctx.strokeStyle = orb.connected ? panelRoot.accentColor : Theme.mutedText
                ctx.beginPath()
                ctx.arc(center, center, radius, start, orb.connected ? end : start + Math.PI * 0.35)
                ctx.stroke()
            }

            Connections {
                target: orb
                function onStrengthChanged() { orbCanvas.requestPaint() }
                function onConnectedChanged() { orbCanvas.requestPaint() }
                function onPoweredChanged() { orbCanvas.requestPaint() }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: -1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: orb.connected ? orb.strength + "%" : (orb.powered ? "--" : "Off")
                color: panelRoot.textColor
                font {
                    family: panelRoot.family
                    pixelSize: 15
                    weight: Font.DemiBold
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wi-Fi"
                color: panelRoot.dimTextColor
                font {
                    family: panelRoot.family
                    pixelSize: 10
                }
            }
        }
    }
}
