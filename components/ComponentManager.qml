import QtQuick

Item {
    id: manager

    property bool opened: false
    readonly property string family: Qt.application.font.family
    readonly property color surfaceColor: Theme.componentSurfaceFor("component-manager")
    readonly property color textColor: Theme.text
    readonly property color dimTextColor: Qt.alpha(textColor, 0.70)
    readonly property color accentColor: Theme.accent
    readonly property var componentItems: [
        { key: "clock", title: "Clock & Weather", detail: "Time, date, and forecast" },
        { key: "music", title: "Music Player", detail: "MPRIS player controls" },
        { key: "apps", title: "Launcher", detail: "Application shortcuts" },
        { key: "system", title: "System Status", detail: "CPU, RAM, and disk" },
        { key: "todo", title: "Tasks", detail: "Local checklist" },
        { key: "calendar", title: "Calendar", detail: "Monthly calendar" },
        { key: "spectrum", title: "Audio Spectrum", detail: "Bottom music visualizer" }
    ]

    signal closeRequested()

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 100

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: manager.closeRequested()
    }

    Rectangle {
        id: panel

        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 34
            topMargin: 84
        }

        width: 390
        height: 548
        radius: 18
        color: manager.surfaceColor

        transform: Translate {
            id: panelTransform

            y: manager.opened ? 0 : -10

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

        Row {
            id: header

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 22
            }

            height: 34
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - resetButton.width - closeButton.width - parent.spacing * 2
                text: "Components"
                color: manager.textColor
                elide: Text.ElideRight
                font {
                    family: manager.family
                    pixelSize: 22
                    weight: Font.DemiBold
                }
            }

            TextButton {
                id: resetButton
                label: "Reset"
                onClicked: backend.resetComponentSettings()
            }

            IconButton {
                id: closeButton
                label: "x"
                onClicked: manager.closeRequested()
            }
        }

        Column {
            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
                bottom: parent.bottom
                leftMargin: 18
                rightMargin: 18
                topMargin: 18
                bottomMargin: 18
            }

            spacing: 10

            Repeater {
                model: manager.componentItems

                ToggleRow {
                    width: parent.width
                    key: modelData.key
                    title: modelData.title
                    detail: modelData.detail
                }
            }
        }
    }

    component TextButton: Item {
        id: button

        property string label: ""
        signal clicked()

        width: 58
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: 8
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
            color: manager.textColor
            font {
                family: manager.family
                pixelSize: 12
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

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        FlatIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            name: "close"
            ink: manager.textColor
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component ToggleRow: Rectangle {
        id: toggle

        property string key: ""
        property string title: ""
        property string detail: ""
        property bool checked: true

        height: 56
        radius: 8
        color: toggleMouse.containsMouse
            ? Theme.controlHover
            : Theme.control

        Component.onCompleted: checked = backend.componentEnabled(key)

        Connections {
            target: backend
            function onComponentSettingsChanged() {
                toggle.checked = backend.componentEnabled(toggle.key)
            }
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Column {
            anchors {
                left: parent.left
                right: switchTrack.left
                verticalCenter: parent.verticalCenter
                leftMargin: 14
                rightMargin: 14
            }

            spacing: 2

            Text {
                width: parent.width
                text: toggle.title
                color: manager.textColor
                elide: Text.ElideRight
                font {
                    family: manager.family
                    pixelSize: 14
                    weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                text: toggle.detail
                color: manager.dimTextColor
                elide: Text.ElideRight
                font {
                    family: manager.family
                    pixelSize: 11
                }
            }
        }

        Rectangle {
            id: switchTrack

            anchors {
                right: parent.right
                rightMargin: 14
                verticalCenter: parent.verticalCenter
            }

            width: 44
            height: 24
            radius: 12
            color: toggle.checked
                ? Theme.selectedStrong
                : Theme.controlHover

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                x: toggle.checked ? 22 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: toggle.checked
                    ? Theme.accentText
                    : Theme.text

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setComponentEnabled(toggle.key, !toggle.checked)
        }
    }
}
