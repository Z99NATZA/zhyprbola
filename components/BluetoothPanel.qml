import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    property bool standalone: false
    readonly property var operation: backend.connectionActions.bluetooth || ({})
    readonly property bool operationBusy: Boolean(operation.busy)
    property string activeTab: "devices"
    property var pendingDeviceActions: ({})
    readonly property string family: Qt.application.font.family
    readonly property color surfaceColor: Theme.componentSurfaceFor("bluetooth")
    readonly property color textColor: Theme.text
    readonly property color dimTextColor: Qt.alpha(textColor, 0.68)
    readonly property color accentColor: Theme.accent
    readonly property color accentTextColor: Theme.accentText

    signal closeRequested()

    function runDeviceAction(address, connect) {
        if (!address || pendingDeviceActions[address] || operationBusy || !backend.bluetoothEnabled)
            return

        const actions = Object.assign({}, pendingDeviceActions)
        actions[address] = {connect: connect, expiresAt: Date.now() + 7000}
        pendingDeviceActions = actions

        if (connect)
            backend.connectBluetoothDevice(address)
        else
            backend.disconnectBluetoothDevice(address)
    }

    function reconcileDeviceActions() {
        const actions = Object.assign({}, pendingDeviceActions)
        let changed = false

        for (const address in actions) {
            const device = backend.bluetoothDevices.find(item => item.address === address)
            if ((device && Boolean(device.connected) === actions[address].connect)
                    || Date.now() >= actions[address].expiresAt) {
                delete actions[address]
                changed = true
            }
        }

        if (changed)
            pendingDeviceActions = actions
    }

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 111

    onOpenedChanged: {
        if (opened && backend.bluetoothEnabled)
            backend.scanBluetoothDevices()
    }

    Connections {
        target: backend
        function onBluetoothDevicesChanged() { panelRoot.reconcileDeviceActions() }
    }

    Timer {
        interval: 500
        running: Object.keys(panelRoot.pendingDeviceActions).length > 0
        repeat: true
        onTriggered: panelRoot.reconcileDeviceActions()
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

                RadioPowerButton {
                    id: powerButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 18
                    }

                    checked: backend.bluetoothEnabled
                    busy: panelRoot.operationBusy && panelRoot.operation.action.startsWith("power-")
                    enabled: !panelRoot.operationBusy && Object.keys(panelRoot.pendingDeviceActions).length === 0
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
                height: 158

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
                        text: panelRoot.operationBusy && panelRoot.operation.action === "scan"
                            ? "Looking for devices…"
                            : backend.bluetoothEnabled ? "No devices found" : "Bluetooth is off"
                        color: panelRoot.dimTextColor
                        font {
                            family: panelRoot.family
                            pixelSize: 13
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
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

            Text {
                width: parent.width
                height: 32
                text: panelRoot.operation.message || ""
                color: panelRoot.operation.success === false ? panelRoot.accentColor : panelRoot.dimTextColor
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.family: panelRoot.family
                font.pixelSize: 11
            }

            Row {
                width: parent.width
                height: 36
                spacing: 10

                TextButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Refresh"
                    objectName: "scanButton"
                    busy: panelRoot.operationBusy && panelRoot.operation.action === "scan"
                    enabled: !panelRoot.operationBusy && backend.bluetoothEnabled && Object.keys(panelRoot.pendingDeviceActions).length === 0
                    onClicked: backend.scanBluetoothDevices()
                }

                TextButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Settings"
                    objectName: "settingsButton"
                    busy: panelRoot.operationBusy && panelRoot.operation.action === "settings"
                    enabled: !panelRoot.operationBusy
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
        readonly property var pendingAction: panelRoot.pendingDeviceActions[address]

        height: 50
        radius: 9
        color: connected ? Theme.selected : Theme.control

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
                right: actionButton.visible ? actionButton.left : parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 12
                rightMargin: actionButton.visible ? 10 : 12
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
                text: row.pendingAction
                    ? (row.pendingAction.connect ? "Connecting…" : "Disconnecting…")
                    : (row.connected ? "Connected" : (row.paired ? "Paired" : "Available"))
                color: panelRoot.dimTextColor
                elide: Text.ElideRight
                font {
                    family: panelRoot.family
                    pixelSize: 11
                }
            }
        }

        Rectangle {
            id: actionButton
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 12
            }

            width: 94
            height: 30
            radius: 8
            visible: row.connected || row.paired
            opacity: row.pendingAction || !backend.bluetoothEnabled ? 0.6 : 1
            color: row.connected
                ? (actionMouse.containsMouse ? Theme.controlHover : Theme.control)
                : (actionMouse.containsMouse ? Qt.lighter(panelRoot.accentColor, 1.1) : panelRoot.accentColor)

            Text {
                anchors.centerIn: parent
                text: row.pendingAction ? "Wait…" : (row.connected ? "Disconnect" : "Connect")
                color: row.connected ? panelRoot.textColor : panelRoot.accentTextColor
                font {
                    family: panelRoot.family
                    pixelSize: 11
                    weight: Font.DemiBold
                }
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                enabled: !row.pendingAction && !panelRoot.operationBusy && backend.bluetoothEnabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panelRoot.runDeviceAction(row.address, !row.connected)
            }
        }
    }

    component InfoRow: Rectangle {
        id: row

        property string label: ""
        property string value: ""

        width: parent.width
        height: 36
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
        property bool busy: false
        opacity: enabled || busy ? 1 : 0.5
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

        Row {
            anchors.centerIn: parent
            spacing: 6
            ActivitySpinner {
                anchors.verticalCenter: parent.verticalCenter
                running: button.busy
                ink: panelRoot.textColor
            }
            Text {
                text: button.busy ? (button.label === "Refresh" ? "Scanning…" : "Opening…") : button.label
                color: panelRoot.textColor
                font.family: panelRoot.family
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !button.busy
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
