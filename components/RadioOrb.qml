import QtQuick

Item {
    id: orb
    property string iconName: "bluetooth"
    property bool animationEnabled: true

    property bool powered: false
    property bool connected: false
    property bool working: false
    readonly property bool animating: animationEnabled && (powered || working)
    property real phase: 0

    width: 86
    height: 86

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: orb.connected
            ? Theme.heroControlHover
            : Theme.heroControl
        opacity: orb.powered || orb.working ? 1 : 0.5

        Behavior on color { ColorAnimation { duration: 240 } }
        Behavior on opacity { NumberAnimation { duration: 240 } }
    }

    // One clock keeps the three expanding radar rings evenly spaced.
    NumberAnimation on phase {
        from: 0
        to: 1
        duration: orb.working ? 1200 : 2700
        loops: Animation.Infinite
        running: orb.animating
    }

    Item {
        anchors.fill: parent
        opacity: orb.animating ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real progress: (orb.phase + index / 3) % 1
                anchors.centerIn: parent
                width: orb.width
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.heroText
                scale: 0.38 + progress * 0.76
                opacity: Math.sin(progress * Math.PI) * (orb.working ? 0.5 : 0.26)
            }
        }

        Canvas {
            id: orbitArc
            anchors.fill: parent
            opacity: orb.working ? 0.85 : 0.45
            onPaint: {
                const context = getContext("2d")
                context.clearRect(0, 0, width, height)
                context.strokeStyle = Theme.heroText
                context.lineWidth = 1.5
                context.lineCap = "round"
                const radius = width / 2 - 2
                context.beginPath()
                context.arc(width / 2, height / 2, radius, 0, Math.PI * 0.55)
                context.stroke()
                context.globalAlpha = 0.4
                context.beginPath()
                context.arc(width / 2, height / 2, radius, Math.PI, Math.PI * 1.25)
                context.stroke()
                context.globalAlpha = 1
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            NumberAnimation on rotation {
                from: 0
                to: -360
                duration: orb.working ? 1500 : 6500
                loops: Animation.Infinite
                running: orb.animating
            }
        }
    }

    FlatIcon {
        anchors.centerIn: parent
        width: 36
        height: 36
        name: orb.iconName
        ink: Theme.heroText
        opacity: orb.powered || orb.working ? 1 : 0.55
        scale: orb.working ? 0.94 : 1
        Behavior on opacity { NumberAnimation { duration: 240 } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
}
