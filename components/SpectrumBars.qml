import QtQuick

Item {
    id: visualizer

    enum Orientation {
        Bottom,
        Top,
        Center,
        Mirror
    }

    property var levels: backend.spectrum
    property int orientation: SpectrumBars.Bottom
    property int barCount: Math.max(24, Math.round(width / 10))
    property int gap: 4
    property real minimumBarHeight: 5
    property real sensitivity: 1.25
    property real barOpacity: 0.82
    property color barColor: Theme.accent

    readonly property string orientationLabel: {
        if (orientation === SpectrumBars.Top)
            return "Top"
        if (orientation === SpectrumBars.Center)
            return "Center"
        if (orientation === SpectrumBars.Mirror)
            return "Mirror"
        return "Bottom"
    }

    function cycleOrientation() {
        orientation = (orientation + 1) % 4
        bars.requestPaint()
    }

    onLevelsChanged: bars.requestPaint()
    onOrientationChanged: bars.requestPaint()
    onBarColorChanged: bars.requestPaint()
    onBarOpacityChanged: bars.requestPaint()
    onWidthChanged: bars.requestPaint()
    onHeightChanged: bars.requestPaint()

    Canvas {
        id: bars
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const count = Math.max(1, visualizer.barCount)
            const totalGap = visualizer.gap * (count - 1)
            const barWidth = Math.max(2, (width - totalGap) / count)
            const source = visualizer.levels || []

            ctx.globalAlpha = visualizer.barOpacity
            ctx.fillStyle = visualizer.barColor

            for (let index = 0; index < count; index++) {
                const t = count === 1 ? 0 : index / (count - 1)
                let sourceT = t

                if (visualizer.orientation === SpectrumBars.Top)
                    sourceT = 1 - t
                else if (visualizer.orientation === SpectrumBars.Mirror)
                    sourceT = Math.abs(t - 0.5) * 2

                let level = 0
                if (source.length > 0) {
                    const sample = Math.min(source.length - 1,
                        Math.floor(sourceT * source.length))
                    level = Math.sqrt(Math.max(0, source[sample])) * visualizer.sensitivity
                }

                const boundedLevel = Math.min(1, Math.max(0, level))
                const barHeight = visualizer.minimumBarHeight
                    + (height - visualizer.minimumBarHeight) * boundedLevel
                const x = index * (barWidth + visualizer.gap)
                let y = height - barHeight

                if (visualizer.orientation === SpectrumBars.Top)
                    y = 0
                else if (visualizer.orientation === SpectrumBars.Center
                    || visualizer.orientation === SpectrumBars.Mirror)
                    y = (height - barHeight) / 2

                ctx.fillRect(x, y, barWidth, barHeight)
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
}
