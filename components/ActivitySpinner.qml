import QtQuick

Item {
    id: spinner
    property bool running: false
    property color ink: Theme.text
    width: 16
    height: 16
    visible: running

    Canvas {
        id: spinnerCanvas
        anchors.fill: parent
        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.strokeStyle = spinner.ink
            context.lineWidth = 2
            context.lineCap = "round"
            context.beginPath()
            context.arc(width / 2, height / 2, Math.min(width, height) / 2 - 2,
                        0, Math.PI * 1.5)
            context.stroke()
        }
        Connections {
            target: spinner
            function onInkChanged() { spinnerCanvas.requestPaint() }
        }
    }

    NumberAnimation on rotation {
        from: 0
        to: 360
        duration: 800
        loops: Animation.Infinite
        running: spinner.running
    }
}
