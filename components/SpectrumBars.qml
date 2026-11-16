import QtQuick

Item {
    id: visualizer

    enum Orientation {
        Bottom,
        Top,
        Center,
        Mirror,
        Inward
    }

    property var levels: backend.spectrum
    property int orientation: SpectrumBars.Bottom
    property int barCount: Math.max(24, Math.round(width / 10))
    property int gap: 4
    property real minimumBarHeight: 5
    property real sensitivity: 1.25
    property real barOpacity: 0.82
    property bool flatBaseline: false
    property color barColor: Theme.accent
    property int smoothingDuration: 130
    property bool adaptiveSmoothing: false
    property int riseDuration: 45
    property int fallDuration: 100
    // Peak focus: only bins that stand above the recent average move, so a
    // wide strip bounces at a few points instead of along its whole length.
    // The floor is a running average (peakFollow per frame, ~200 ms at 60 fps)
    // times peakFloor, so a beat that lifts every bin still pops out; what is
    // left is raised to peakCurve (above 1 keeps small rises small).
    property bool peakFocus: false
    property real peakFloor: 1.0
    property real peakCurve: 1.2
    property real peakFollow: 0.08
    property real recentAverage: -1
    property var focusedLevels: []
    // Wave (Inward only): one filled shape with no gaps. Neighbouring bars are
    // merged about every waveSpacing px (their tallest wins) and joined with
    // smooth curves, so peaks rise as broad hills; rise/fall timing matches bars.
    property bool wave: false
    property real waveSpacing: 48
    property var waveHeights: []
    readonly property bool showWave: wave && orientation === SpectrumBars.Inward
    readonly property int inwardBarCount: Math.max(2, barCount - barCount % 2)
    readonly property int inwardHalfCount: inwardBarCount / 2
    readonly property real inwardBarWidth: Math.max(2,
        (width - (inwardBarCount - 1) * gap) / inwardBarCount)

    function focusPeaks(source) {
        if (!source || source.length === 0)
            return []
        let sum = 0
        for (let index = 0; index < source.length; index++)
            sum += Math.max(0, source[index])
        const average = sum / source.length
        recentAverage = recentAverage < 0 ? average
            : recentAverage + (average - recentAverage) * peakFollow
        const floor = Math.min(0.9, recentAverage * peakFloor)
        const shaped = []
        for (let index = 0; index < source.length; index++)
            shaped.push(Math.pow(Math.max(0, source[index] - floor) / (1 - floor), peakCurve))
        return shaped
    }

    function updateWave() {
        const step = inwardBarWidth + gap
        const group = Math.max(1, Math.round(waveSpacing / step))
        const count = Math.ceil(inwardBarCount / group)
        const frame = 1000 / 60
        const rise = 1 - Math.exp(-3 * frame / Math.max(1, riseDuration))
        const fall = 1 - Math.exp(-3 * frame / Math.max(1, fallDuration))
        const previous = waveHeights.length === count ? waveHeights : []
        const next = []
        for (let point = 0; point < count; point++) {
            let target = minimumBarHeight
            const end = Math.min(inwardBarCount, (point + 1) * group)
            for (let index = point * group; index < end; index++)
                target = Math.max(target, inwardHeight(index))
            const current = point < previous.length ? previous[point] : target
            next.push(current + (target - current) * (target > current ? rise : fall))
        }
        waveHeights = next
        waveCanvas.requestPaint()
    }

    function inwardHeight(index) {
        const source = (peakFocus ? focusedLevels : levels) || []
        if (source.length === 0)
            return minimumBarHeight

        const mirroredIndex = Math.min(index, inwardBarCount - 1 - index)
        const sourceT = inwardHalfCount === 1 ? 0
            : 1 - mirroredIndex / (inwardHalfCount - 1)
        const sample = Math.min(source.length - 1,
            Math.floor(sourceT * (source.length - 1)))
        const value = Math.max(0, source[sample])
        const level = Math.min(1, (peakFocus ? value : Math.sqrt(value)) * sensitivity)
        return minimumBarHeight + (height - minimumBarHeight) * level
    }

    readonly property string orientationLabel: {
        if (orientation === SpectrumBars.Top)
            return "Top"
        if (orientation === SpectrumBars.Center)
            return "Center"
        if (orientation === SpectrumBars.Mirror)
            return "Mirror"
        if (orientation === SpectrumBars.Inward)
            return "Inward"
        return "Bottom"
    }

    function cycleOrientation() {
        orientation = (orientation + 1) % 5
        bars.requestPaint()
    }

    onLevelsChanged: {
        if (peakFocus)
            focusedLevels = focusPeaks(levels)
        if (showWave)
            updateWave()
        if (orientation !== SpectrumBars.Inward)
            bars.requestPaint()
    }
    onOrientationChanged: bars.requestPaint()
    onBarCountChanged: bars.requestPaint()
    onGapChanged: bars.requestPaint()
    onMinimumBarHeightChanged: bars.requestPaint()
    onSensitivityChanged: bars.requestPaint()
    onBarColorChanged: bars.requestPaint()
    onBarOpacityChanged: bars.requestPaint()
    onWidthChanged: bars.requestPaint()
    onHeightChanged: bars.requestPaint()

    Canvas {
        id: bars
        anchors.fill: parent
        visible: visualizer.orientation !== SpectrumBars.Inward

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

    onShowWaveChanged: if (showWave) updateWave()

    Canvas {
        id: waveCanvas
        objectName: "spectrum-wave"
        anchors.fill: parent
        visible: visualizer.showWave

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            const heights = visualizer.waveHeights
            if (heights.length === 0)
                return
            const span = width / heights.length
            const pointX = index => (index + 0.5) * span
            const pointY = index => height - heights[index]

            ctx.globalAlpha = visualizer.barOpacity
            ctx.fillStyle = visualizer.barColor
            ctx.beginPath()
            ctx.moveTo(0, height)
            ctx.lineTo(0, pointY(0))
            ctx.lineTo(pointX(0), pointY(0))
            // Curves pass through midpoints with the samples as control
            // points, so the surface never dips below the baseline.
            for (let index = 1; index < heights.length - 1; index++) {
                ctx.quadraticCurveTo(pointX(index), pointY(index),
                    (pointX(index) + pointX(index + 1)) / 2,
                    (pointY(index) + pointY(index + 1)) / 2)
            }
            const last = heights.length - 1
            ctx.lineTo(pointX(last), pointY(last))
            ctx.lineTo(width, pointY(last))
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fill()
        }
    }

    Item {
        id: inwardBars
        anchors.fill: parent
        visible: visualizer.orientation === SpectrumBars.Inward && !visualizer.showWave
        opacity: visualizer.barOpacity

        Repeater {
            // No bar delegates (and their per-frame bindings) while the wave shows.
            model: visualizer.showWave ? 0 : visualizer.inwardBarCount

            delegate: Item {
                id: bar
                required property int index
                readonly property real targetHeight: visualizer.inwardHeight(index)
                property real displayedHeight: visualizer.minimumBarHeight
                property int transitionDuration: visualizer.smoothingDuration

                onTargetHeightChanged: {
                    if (!visualizer.adaptiveSmoothing)
                        return
                    transitionDuration = targetHeight > displayedHeight
                        ? visualizer.riseDuration : visualizer.fallDuration
                    displayedHeight = targetHeight
                }

                Behavior on displayedHeight {
                    enabled: visualizer.adaptiveSmoothing
                    NumberAnimation {
                        duration: bar.transitionDuration
                        easing.type: Easing.OutCubic
                    }
                }

                x: index * (visualizer.inwardBarWidth + visualizer.gap)
                width: visualizer.inwardBarWidth
                height: inwardBars.height

                Rectangle {
                    id: roundedBar
                    anchors.bottom: parent.bottom
                    width: bar.width
                    height: visualizer.adaptiveSmoothing
                        ? bar.displayedHeight : bar.targetHeight
                    radius: width / 2
                    color: visualizer.barColor

                    Behavior on height {
                        enabled: !visualizer.adaptiveSmoothing
                        NumberAnimation {
                            duration: visualizer.smoothingDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: bar.width
                    height: Math.min(roundedBar.height, roundedBar.radius)
                    color: visualizer.barColor
                    visible: visualizer.flatBaseline
                }
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
