import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    readonly property string family: Qt.application.font.family
    readonly property color glassColor: Qt.rgba(0.08, 0.06, 0.11, 0.91)
    readonly property color borderColor: Qt.rgba(1, 1, 1, 0.18)
    readonly property color textColor: "#FFFFFF"
    readonly property color dimTextColor: Qt.alpha(textColor, 0.70)
    readonly property color accentColor: "#F3A5CD"

    signal closeRequested()

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 110

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.16)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panelRoot.closeRequested()
    }

    Rectangle {
        id: panel

        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 34
            topMargin: 84
        }

        width: 380
        height: 350
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
                    color: Qt.rgba(1, 1, 1, 0.085)
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

            spacing: 16

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
                width: parent.width
                height: 126
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.075)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)

                SignalRing {
                    id: signalRing
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                    }

                    strength: backend.wifiSignalStrength
                    enabledState: backend.wifiEnabled
                    connected: backend.wifiConnected
                }

                Column {
                    anchors {
                        left: signalRing.right
                        right: wifiSwitch.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                        rightMargin: 14
                    }

                    spacing: 5

                    Text {
                        width: parent.width
                        text: backend.wifiSsid
                        color: panelRoot.textColor
                        elide: Text.ElideRight
                        font {
                            family: panelRoot.family
                            pixelSize: 18
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
                }

                SwitchControl {
                    id: wifiSwitch
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 18
                    }

                    checked: backend.wifiEnabled
                    onClicked: backend.setWifiEnabled(!backend.wifiEnabled)
                }
            }

            Column {
                width: parent.width
                spacing: 8

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

    component InfoRow: Rectangle {
        id: row

        property string label: ""
        property string value: ""

        width: parent.width
        height: 34
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.055)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

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

    component TextButton: Item {
        id: button

        property string label: ""
        signal clicked()

        height: 36

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: buttonMouse.containsMouse
                ? Qt.rgba(1, 1, 1, 0.14)
                : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

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
                ? Qt.rgba(1, 1, 1, 0.14)
                : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
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

    component SwitchControl: Item {
        id: control

        property bool checked: false
        signal clicked()

        width: 48
        height: 28

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: control.checked
                ? Qt.rgba(0.95, 0.65, 0.80, 0.88)
                : Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            x: control.checked ? 24 : 4
            anchors.verticalCenter: parent.verticalCenter
            color: control.checked
                ? "#6D4F6B"
                : Qt.rgba(1, 1, 1, 0.82)

            Behavior on x {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }

    component SignalRing: Item {
        id: ring

        property int strength: 0
        property bool enabledState: false
        property bool connected: false

        width: 72
        height: 72

        Canvas {
            id: ringCanvas

            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                var center = width / 2
                var radius = 29
                var start = -Math.PI / 2
                var end = start + Math.PI * 2 * Math.max(0, Math.min(100, ring.strength)) / 100

                ctx.reset()
                ctx.lineWidth = 6
                ctx.lineCap = "round"
                ctx.strokeStyle = "rgba(255, 255, 255, 0.14)"
                ctx.beginPath()
                ctx.arc(center, center, radius, 0, Math.PI * 2)
                ctx.stroke()

                ctx.strokeStyle = ring.connected
                    ? "#F3A5CD"
                    : "rgba(255, 255, 255, 0.34)"
                ctx.beginPath()
                ctx.arc(center, center, radius, start, ring.connected ? end : start + Math.PI * 0.35)
                ctx.stroke()
            }

            Connections {
                target: ring
                function onStrengthChanged() { ringCanvas.requestPaint() }
                function onConnectedChanged() { ringCanvas.requestPaint() }
                function onEnabledStateChanged() { ringCanvas.requestPaint() }
            }
        }

        Text {
            anchors.centerIn: parent
            text: ring.connected ? ring.strength + "%" : (ring.enabledState ? "--" : "Off")
            color: panelRoot.textColor
            font {
                family: panelRoot.family
                pixelSize: 14
                weight: Font.DemiBold
            }
        }
    }
}
