import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    property bool standalone: false
    readonly property var operation: backend.connectionActions.bluetooth || ({})
    readonly property bool operationBusy: Boolean(operation.busy)
    readonly property bool powerBusy: operationBusy && String(operation.action || "").startsWith("power-")
    property string activeTab: "devices"
    property var pendingDeviceActions: ({})
    readonly property bool deviceActionBusy: Object.keys(pendingDeviceActions).length > 0
    readonly property string family: Qt.application.font.family
    readonly property color surfaceColor: Theme.componentSurfaceFor("bluetooth")
    readonly property color textColor: Theme.text
    readonly property color dimTextColor: Qt.alpha(textColor, 0.68)
    readonly property color accentColor: Theme.accent
    readonly property color accentTextColor: Theme.accentText

    signal closeRequested()

    function runDeviceAction(address, connect) {
        if (!address || deviceActionBusy || operationBusy || !backend.bluetoothEnabled)
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

                RadioOrb {
                    id: bluetoothOrb
                    objectName: "bluetoothOrb"
                    animationEnabled: panelRoot.opened
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 18
                    }

                    powered: backend.bluetoothEnabled
                    connected: backend.bluetoothConnected
                    working: panelRoot.powerBusy
                        || (panelRoot.operationBusy && panelRoot.operation.action === "scan")
                        || panelRoot.deviceActionBusy
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
                        text: panelRoot.powerBusy
                            ? (panelRoot.operation.action === "power-on" ? "Turning on…" : "Turning off…")
                            : backend.bluetoothStatusText
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
                    busy: panelRoot.powerBusy
                    pendingChecked: panelRoot.operation.action === "power-on"
                    enabled: !panelRoot.operationBusy && !panelRoot.deviceActionBusy
                    onClicked: backend.setBluetoothEnabled(!backend.bluetoothEnabled)
                }
            }

            Item {
                id: tabs
                width: parent.width
                height: 34
                readonly property real tabWidth: (width - 8) / 2

                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        x: index * (tabs.tabWidth + 8)
                        width: tabs.tabWidth
                        height: tabs.height
                        radius: 9
                        color: Theme.control
                    }
                }

                Rectangle {
                    objectName: "bluetoothTabIndicator"
                    x: panelRoot.activeTab === "devices" ? 0 : parent.tabWidth + 8
                    width: parent.tabWidth
                    height: parent.height
                    radius: 9
                    color: panelRoot.accentColor
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                Row {
                    anchors.fill: parent
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
            }

            Item {
                width: parent.width
                height: 158
                clip: true

                Item {
                    objectName: "bluetoothDevicesPage"
                    anchors.fill: parent
                    opacity: panelRoot.activeTab === "devices" ? 1 : 0
                    visible: opacity > 0
                    enabled: panelRoot.activeTab === "devices"
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate {
                        x: panelRoot.activeTab === "devices" ? 0 : -14
                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

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
                            revealIndex: index
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
                    objectName: "bluetoothDetailsPage"
                    width: parent.width
                    spacing: 4
                    opacity: panelRoot.activeTab === "details" ? 1 : 0
                    visible: opacity > 0
                    enabled: panelRoot.activeTab === "details"
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate {
                        x: panelRoot.activeTab === "details" ? 0 : 14
                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

                    InfoRow {
                        revealIndex: 0
                        label: "Device"
                        value: backend.bluetoothConnected ? backend.bluetoothDeviceName : "Not connected"
                    }

                    InfoRow {
                        revealIndex: 1
                        label: "Radio"
                        value: backend.bluetoothEnabled ? "On" : "Off"
                    }

                    InfoRow {
                        revealIndex: 2
                        label: "Adapter"
                        value: backend.bluetoothAvailable ? "Available" : "Unavailable"
                    }

                    InfoRow {
                        revealIndex: 3
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
                    enabled: !panelRoot.operationBusy && backend.bluetoothEnabled && !panelRoot.deviceActionBusy
                    onClicked: backend.scanBluetoothDevices()
                }

                TextButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Settings"
                    objectName: "settingsButton"
                    busy: panelRoot.operationBusy && panelRoot.operation.action === "settings"
                    enabled: !panelRoot.operationBusy && !panelRoot.deviceActionBusy
                    onClicked: backend.openBluetoothSettings()
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row

        property int revealIndex: 0
        readonly property bool revealing: panelRoot.opened && panelRoot.activeTab === "devices"
        property real revealProgress: revealing ? 1 : 0
        opacity: revealProgress
        transform: Translate { y: (1 - row.revealProgress) * 16 }
        Behavior on revealProgress {
            SequentialAnimation {
                PauseAnimation { duration: row.revealing ? Math.min(row.revealIndex, 6) * 45 : 0 }
                NumberAnimation { duration: row.revealing ? 300 : 120; easing.type: Easing.OutCubic }
            }
        }

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
        border.width: 1
        border.color: pendingAction ? Qt.alpha(panelRoot.accentColor, 0.4) : "transparent"
        Behavior on border.color { ColorAnimation { duration: 180 } }

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
            objectName: "bluetoothDeviceAction-" + row.address
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 12
            }

            width: 94
            height: 30
            radius: 8
            visible: row.connected || row.paired
            enabled: !panelRoot.deviceActionBusy && !panelRoot.operationBusy && backend.bluetoothEnabled
            opacity: enabled || row.pendingAction ? 1 : 0.5
            scale: actionMouse.pressed ? 0.94 : actionMouse.containsMouse && enabled ? 1.03 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on color { ColorAnimation { duration: 160 } }
            color: row.connected
                ? (actionMouse.containsMouse && enabled ? Theme.controlHover : Theme.control)
                : (actionMouse.containsMouse && enabled ? Qt.lighter(panelRoot.accentColor, 1.1) : panelRoot.accentColor)

            Row {
                anchors.centerIn: parent
                spacing: 5
                ActivitySpinner {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    running: Boolean(row.pendingAction) && panelRoot.opened
                    ink: row.connected ? panelRoot.textColor : panelRoot.accentTextColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.pendingAction ? "Wait…" : (row.connected ? "Disconnect" : "Connect")
                    color: row.connected ? panelRoot.textColor : panelRoot.accentTextColor
                    font {
                        family: panelRoot.family
                        pixelSize: 11
                        weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panelRoot.runDeviceAction(row.address, !row.connected)
            }
        }
    }

    component InfoRow: Rectangle {
        id: row

        objectName: "bluetoothDetail-" + label
        property int revealIndex: 0
        readonly property bool revealing: panelRoot.opened && panelRoot.activeTab === "details"
        property real revealProgress: revealing ? 1 : 0
        opacity: revealProgress
        transform: Translate { y: (1 - row.revealProgress) * 16 }
        Behavior on revealProgress {
            SequentialAnimation {
                PauseAnimation { duration: row.revealing ? row.revealIndex * 55 : 0 }
                NumberAnimation { duration: row.revealing ? 300 : 120; easing.type: Easing.OutCubic }
            }
        }

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
        scale: buttonMouse.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: buttonMouse.containsMouse && !button.active
                ? Qt.alpha(panelRoot.accentColor, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.active ? panelRoot.accentTextColor : panelRoot.textColor
            Behavior on color { ColorAnimation { duration: 180 } }
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

}
