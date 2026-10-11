import QtQuick

Item {
    id: control
    objectName: "radioPowerButton"
    property bool checked: false
    property bool busy: false
    property bool pendingChecked: !checked
    property real clickPulse: 0
    signal clicked()
    width: 56
    height: 56
    Accessible.role: Accessible.Button
    Accessible.name: busy ? (pendingChecked ? "Turning radio on" : "Turning radio off")
        : checked ? "Radio on. Turn off" : "Radio off. Turn on"
    Accessible.onPressAction: { if (enabled && !busy) clicked() }
    scale: powerMouse.pressed ? 0.9 : powerMouse.containsMouse && enabled ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    SequentialAnimation {
        id: clickFeedback
        NumberAnimation { target: control; property: "clickPulse"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
        PropertyAction { target: control; property: "clickPulse"; value: 0 }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.heroText
        scale: 1 + control.clickPulse * 0.35
        opacity: control.clickPulse > 0 ? (1 - control.clickPulse) * 0.6 : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: powerMouse.containsMouse && control.enabled
            ? Theme.heroControlHover : control.checked ? Theme.heroControl : "transparent"
        border.width: control.checked ? 0 : 2
        border.color: Theme.heroMutedText
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
    }

    Item {
        anchors.fill: parent
        visible: control.busy
        Canvas {
            id: progressArc
            anchors.fill: parent
            onPaint: {
                const context = getContext("2d")
                context.clearRect(0, 0, width, height)
                context.strokeStyle = Theme.heroText
                context.lineWidth = 2
                context.lineCap = "round"
                context.beginPath()
                context.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 1.25)
                context.stroke()
            }
        }
        NumberAnimation on rotation {
            from: 0
            to: -360
            duration: 900
            loops: Animation.Infinite
            running: control.busy && control.visible
        }
    }

    FlatIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: 20
        height: 20
        name: "power"
        ink: control.checked || control.busy ? Theme.heroText : Theme.heroMutedText
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34
        text: control.busy ? (control.pendingChecked ? "On…" : "Off…") : control.checked ? "On" : "Off"
        color: control.checked || control.busy ? Theme.heroText : Theme.heroMutedText
        font.family: Qt.application.font.family
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: powerMouse
        anchors.fill: parent
        enabled: !control.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            clickFeedback.restart()
            control.clicked()
        }
    }
}
