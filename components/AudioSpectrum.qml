import QtQuick

Item {
    id: visualizer
    width: 1500
    height: 200

    readonly property int barCount: Math.max(24, Math.round(width / 16))
    readonly property int minimumBarHeight: 6
    readonly property int transitionDuration: 1
    property real sensitivity: 1.25
    property color barColor: "#F3A5CD"

    Row {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: visualizer.barCount

            delegate: Item {
                required property int index
                width: (visualizer.width - (visualizer.barCount - 1) * 6)
                    / visualizer.barCount
                height: visualizer.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: {
                        const levels = backend.spectrum
                        if (levels.length === 0)
                            return visualizer.minimumBarHeight
                        const center = (visualizer.barCount - 1) / 2
                        const distance = Math.abs(index - center) / Math.max(1, center)
                        const sample = Math.min(levels.length - 1,
                            Math.floor(distance * levels.length))
                        const level = Math.min(1,
                            Math.sqrt(Math.max(0, levels[sample])) * visualizer.sensitivity)
                        return visualizer.minimumBarHeight
                            + (visualizer.height - visualizer.minimumBarHeight) * level
                    }
                    radius: width / 2
                    color: visualizer.barColor
                    opacity: 0.8

                    Behavior on height {
                        NumberAnimation {
                            duration: visualizer.transitionDuration
                            easing.type: Easing.Linear
                        }
                    }
                }
            }
        }
    }
}
