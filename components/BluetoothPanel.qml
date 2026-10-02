import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    property bool standalone: false
    property string activeTab: "devices"
    readonly property string family: Qt.application.font.family
    readonly property color surfaceColor: Theme.panelSurface
    readonly property color textColor: Theme.text
    readonly property color dimTextColor: Qt.alpha(textColor, 0.68)
    readonly property color accentColor: Theme.accent
    readonly property color accentTextColor: Theme.accentText

    signal closeRequested()

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 111

    onOpenedChanged: {
        if (opened)
            backend.scanBluetoothDevices()
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
        height: panelRoot.standalone ? parent.height : 540
        radius: 18
        color: panelRoot.surfaceColor

        transform: Translate {
            y: panelRoot.opened ? 0 : -10

            Behavior on y {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
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
                    text: "Bluetooth"
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
                height: 138
                radius: 14
                color: Theme.heroSurface

                BluetoothOrb {
                    id: bluetoothOrb
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                    }

                    powered: backend.bluetoothEnabled
                    connected: backend.bluetoothConnected
                }

                Column {
                    anchors {
                        left: bluetoothOrb.right
                        right: powerButton.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                        rightMargin: 14
                    }

                    spacing: 6

                    Text {
                        width: parent.width
                        text: backend.bluetoothDeviceName
                        color: Theme.heroText
                        elide: Text.ElideRight
                        font {
                            family: panelRoot.family
                            pixelSize: 20
                            weight: Font.DemiBold
                        }
                    }

                    Text {
                        width: parent.width
                        text: backend.bluetoothStatusText
                        color: Theme.heroMutedText
                        elide: Text.ElideRight
                        font {
                            family: panelRoot.family
                            pixelSize: 12
                        }
                    }

                    Row {
                        spacing: 8

                        Pill {
                            label: backend.bluetoothEnabled ? "Radio on" : "Radio off"
                            active: backend.bluetoothEnabled
                        }

                        Pill {
                            label: backend.bluetoothConnected ? "Connected" : "Idle"
                            active: backend.bluetoothConnected
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

                    checked: backend.bluetoothEnabled
                    onClicked: backend.setBluetoothEnabled(!backend.bluetoothEnabled)
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: 8

                TabButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Devices"
                    active: panelRoot.activeTab === "devices"
                    onClicked: panelRoot.activeTab = "devices"
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
                height: 204

                Item {
                    anchors.fill: parent
                    visible: panelRoot.activeTab === "devices"

                    ListView {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                        }

                        clip: true
                        spacing: 8
                        model: backend.bluetoothDevices

                        delegate: DeviceRow {
                            width: ListView.view.width
                            address: modelData["address"] || ""
                            name: modelData["name"] || address
                            iconName: modelData["icon"] || ""
                            paired: modelData["paired"] || false
                            trusted: modelData["trusted"] || false
                            connected: modelData["connected"] || false
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: backend.bluetoothDevices.length === 0
                        text: backend.bluetoothEnabled ? "No devices found" : "Bluetooth is off"
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
                        label: "Device"
                        value: backend.bluetoothConnected ? backend.bluetoothDeviceName : "Not connected"
                    }

                    InfoRow {
                        label: "Radio"
                        value: backend.bluetoothEnabled ? "On" : "Off"
                    }

                    InfoRow {
                        label: "Adapter"
                        value: backend.bluetoothAvailable ? "Available" : "Unavailable"
                    }

                    InfoRow {
                        label: "Backend"
                        value: "BlueZ"
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
                    onClicked: backend.openBluetoothSettings()
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row

        property string address: ""
        property string name: ""
        property string iconName: ""
        property bool paired: false
        property bool trusted: false
        property bool connected: false

        height: 50
        radius: 9
        color: connected
            ? Theme.selected
            : (rowMouse.containsMouse ? Theme.controlHover : Theme.control)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        DeviceGlyph {
            id: deviceGlyph
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }

            connected: row.connected
            iconName: row.iconName
        }

        Column {
            anchors {
                left: deviceGlyph.right
                right: actionLabel.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
                rightMargin: 10
            }

            spacing: 2

            Text {
                width: parent.width
                text: row.name
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
                text: row.connected ? "Connected" : (row.paired ? "Paired" : "Available")
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

            width: 82
            horizontalAlignment: Text.AlignRight
            text: row.connected ? (rowMouse.containsMouse ? "Disconnect" : "Current") : (rowMouse.containsMouse ? "Connect" : (row.paired ? "Saved" : "Pair"))
            color: row.connected ? panelRoot.accentColor : panelRoot.dimTextColor
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
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.connected) {
                    backend.disconnectBluetoothDevice(row.address)
                } else {
                    backend.connectBluetoothDevice(row.address)
                }
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
        color: active ? Theme.heroControlHover : Theme.heroControl

        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: parent.active ? Theme.heroText : Theme.heroMutedText
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
        }

        FlatIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            name: "close"
            ink: panelRoot.textColor
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
            color: powerMouse.containsMouse ? Theme.heroControlHover : Theme.heroControl
        }

        FlatIcon {
            anchors.centerIn: parent
            width: 22
            height: 22
            name: "power"
            ink: Theme.heroText
        }

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }

    component DeviceGlyph: FlatIcon {
        property bool connected: false
        property string iconName: ""

        width: 24
        height: 24
        name: "bluetooth"
        ink: connected ? panelRoot.accentColor : panelRoot.textColor
    }

    component BluetoothOrb: Item {
        id: orb

        property bool powered: false
        property bool connected: false

        width: 86
        height: 86

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: orb.connected
                ? Theme.heroControlHover
                : Theme.heroControl
        }

        DeviceGlyph {
            anchors.centerIn: parent
            width: 36
            height: 36
            connected: orb.powered
            ink: Theme.heroText
        }
    }
}
