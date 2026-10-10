import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    property bool standalone: false
    readonly property var operation: backend.connectionActions.wifi || ({})
    readonly property bool operationBusy: Boolean(operation.busy)
    property string activeTab: "networks"
    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string passwordSsid: ""
    property string passwordError: ""
    property string failedSsid: ""
    property string failureMessage: ""
    readonly property bool actionBusy: operationBusy || connectingSsid.length > 0 || disconnectingSsid.length > 0
    readonly property string family: Qt.application.font.family
    readonly property color surfaceColor: Theme.componentSurfaceFor("wifi")
    readonly property color textColor: Theme.text
    readonly property color dimTextColor: Qt.alpha(textColor, 0.68)
    readonly property color accentColor: Theme.accent
    readonly property color accentTextColor: Theme.accentText

    signal closeRequested()

    function showPassword(ssid) {
        passwordSsid = ssid
        passwordError = ""
        wifiPasswordInput.text = ""
        wifiPasswordInput.forceActiveFocus()
    }

    function connectNetwork(ssid, secure, saved) {
        if (!ssid || actionBusy || !backend.wifiEnabled)
            return

        failedSsid = ""
        if (secure && !saved) {
            showPassword(ssid)
            return
        }

        connectingSsid = ssid
        backend.connectWifiNetwork(ssid, secure, saved, "")
    }

    function disconnectNetwork(ssid) {
        if (!ssid || actionBusy || !backend.wifiConnected)
            return

        failedSsid = ""
        disconnectingSsid = ssid
        backend.disconnectWifiNetwork(ssid)
    }

    function submitPassword() {
        if (!passwordSsid || actionBusy || !wifiPasswordInput.text)
            return

        const ssid = passwordSsid
        const password = wifiPasswordInput.text
        wifiPasswordInput.text = ""
        passwordError = ""
        connectingSsid = ssid
        backend.connectWifiNetwork(ssid, true, false, password)
    }

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 110

    onOpenedChanged: {
        if (opened && backend.wifiEnabled)
            backend.scanWifiNetworks()
    }

    Connections {
        target: backend
        function onWifiConnectionFinished(ssid, success, needsPassword) {
            if (ssid !== panelRoot.connectingSsid)
                return

            panelRoot.connectingSsid = ""
            if (success) {
                panelRoot.passwordSsid = ""
                panelRoot.passwordError = ""
                panelRoot.failedSsid = ""
            } else if (needsPassword) {
                panelRoot.showPassword(ssid)
            } else if (panelRoot.passwordSsid === ssid) {
                panelRoot.passwordError = "Could not connect. Check the password."
            } else {
                panelRoot.failedSsid = ssid
                panelRoot.failureMessage = "Could not connect"
            }
        }

        function onWifiDisconnectionFinished(ssid, success) {
            if (ssid !== panelRoot.disconnectingSsid)
                return

            panelRoot.disconnectingSsid = ""
            if (!success) {
                panelRoot.failedSsid = ssid
                panelRoot.failureMessage = "Could not disconnect"
            }
        }
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
                color: Theme.heroSurface

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
                        text: backend.wifiStatusText
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
                            label: backend.wifiEnabled ? "Radio on" : "Radio off"
                            active: backend.wifiEnabled
                        }

                        Pill {
                            label: backend.wifiConnected ? "Connected" : "Idle"
                            active: backend.wifiConnected
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

                    checked: backend.wifiEnabled
                    busy: panelRoot.operationBusy && panelRoot.operation.action.startsWith("power-")
                    enabled: !panelRoot.operationBusy && !panelRoot.actionBusy
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
                height: 178

                Item {
                    anchors.fill: parent
                    visible: panelRoot.activeTab === "networks"

                    ListView {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
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
                            saved: modelData["saved"] || false
                            active: modelData["active"] || false
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: backend.wifiNetworks.length === 0
                        text: panelRoot.operationBusy && panelRoot.operation.action === "scan"
                            ? "Looking for networks…"
                            : backend.wifiEnabled ? "No networks found" : "Wi-Fi is off"
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
                    enabled: !panelRoot.operationBusy && backend.wifiEnabled && !panelRoot.actionBusy
                    onClicked: backend.scanWifiNetworks()
                }

                TextButton {
                    width: (parent.width - parent.spacing) / 2
                    label: "Settings"
                    objectName: "settingsButton"
                    busy: panelRoot.operationBusy && panelRoot.operation.action === "settings"
                    enabled: !panelRoot.operationBusy
                    onClicked: backend.openWifiSettings()
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: panelRoot.passwordSsid.length > 0
            color: Qt.rgba(0, 0, 0, 0.24)
            z: 2

            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                width: parent.width - 40
                height: panelRoot.passwordError ? 242 : 222
                anchors.centerIn: parent
                radius: 14
                color: panelRoot.surfaceColor

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Text {
                        width: parent.width
                        text: "Connect to Wi-Fi"
                        color: panelRoot.textColor
                        font {
                            family: panelRoot.family
                            pixelSize: 18
                            weight: Font.DemiBold
                        }
                    }

                    Text {
                        width: parent.width
                        text: panelRoot.passwordSsid
                        color: panelRoot.dimTextColor
                        elide: Text.ElideRight
                        font {
                            family: panelRoot.family
                            pixelSize: 13
                        }
                    }

                    Text {
                        text: "Password"
                        color: panelRoot.textColor
                        font {
                            family: panelRoot.family
                            pixelSize: 12
                            weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: 9
                        color: Theme.control

                        TextInput {
                            id: wifiPasswordInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: panelRoot.textColor
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                            enabled: !panelRoot.connectingSsid
                            font {
                                family: panelRoot.family
                                pixelSize: 14
                            }
                            Keys.onReturnPressed: panelRoot.submitPassword()
                            Keys.onEscapePressed: {
                                if (!panelRoot.connectingSsid)
                                    panelRoot.passwordSsid = ""
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: panelRoot.passwordError.length > 0
                        text: panelRoot.passwordError
                        color: panelRoot.accentColor
                        wrapMode: Text.WordWrap
                        font {
                            family: panelRoot.family
                            pixelSize: 11
                        }
                    }

                    Row {
                        width: parent.width
                        height: 36
                        spacing: 10

                        TextButton {
                            width: (parent.width - parent.spacing) / 2
                            label: "Cancel"
                            onClicked: {
                                if (!panelRoot.connectingSsid)
                                    panelRoot.passwordSsid = ""
                            }
                        }

                        Rectangle {
                            width: (parent.width - parent.spacing) / 2
                            height: 36
                            radius: 9
                            color: panelRoot.accentColor
                            opacity: panelRoot.connectingSsid ? 0.6 : 1

                            Text {
                                anchors.centerIn: parent
                                text: panelRoot.connectingSsid ? "Connecting…" : "Connect"
                                color: panelRoot.accentTextColor
                                font {
                                    family: panelRoot.family
                                    pixelSize: 13
                                    weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !panelRoot.connectingSsid
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panelRoot.submitPassword()
                            }
                        }
                    }
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
        property bool saved: false
        property bool active: false
        readonly property bool enterpriseSetup: !saved
            && (security.indexOf("802.1X") >= 0 || security.indexOf("EAP") >= 0)

        height: 48
        radius: 9
        color: active ? Theme.selected : Theme.control

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
                right: actionButton.left
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
                text: panelRoot.connectingSsid === row.ssid
                    ? "Connecting…"
                    : panelRoot.disconnectingSsid === row.ssid
                        ? "Disconnecting…"
                        : panelRoot.failedSsid === row.ssid
                            ? panelRoot.failureMessage
                            : row.signal + "%  " + (row.secure ? row.security : "Open")
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
            opacity: panelRoot.actionBusy || !backend.wifiEnabled ? 0.6 : 1
            color: row.active
                ? (actionMouse.containsMouse ? Theme.controlHover : Theme.control)
                : (actionMouse.containsMouse
                    ? Qt.lighter(panelRoot.accentColor, 1.1)
                    : panelRoot.accentColor)

            Text {
                anchors.centerIn: parent
                text: panelRoot.connectingSsid === row.ssid
                    || panelRoot.disconnectingSsid === row.ssid
                    ? "Wait…" : (row.active ? "Disconnect" : (row.enterpriseSetup ? "Settings" : "Connect"))
                color: row.active ? panelRoot.textColor : panelRoot.accentTextColor
                font {
                    family: panelRoot.family
                    pixelSize: 11
                    weight: Font.DemiBold
                }
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                enabled: !panelRoot.actionBusy && backend.wifiEnabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (row.active)
                        panelRoot.disconnectNetwork(row.ssid)
                    else if (row.enterpriseSetup)
                        backend.openWifiSettings()
                    else
                        panelRoot.connectNetwork(row.ssid, row.secure, row.saved)
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

    component WifiGlyphSmall: FlatIcon {
        property int strength: 0
        property bool active: false

        width: 22
        height: 22
        name: "wifi"
        ink: active ? panelRoot.accentColor : panelRoot.textColor
    }

    component SignalOrb: Item {
        id: orb

        property int strength: 0
        property bool powered: false
        property bool connected: false

        width: 86
        height: 86

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: orb.connected ? Theme.heroControlHover : Theme.heroControl
        }

        FlatIcon {
            anchors.centerIn: parent
            name: "wifi"
            ink: Theme.heroText
            width: 36
            height: 36
        }
    }
}
