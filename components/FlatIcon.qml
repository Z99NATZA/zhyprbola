import QtQuick

Canvas {
    property string name: ""
    property color ink: Theme.text

    width: 24
    height: 24

    onNameChanged: requestPaint()
    onInkChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.scale(width / 24, height / 24)
        ctx.strokeStyle = ink
        ctx.fillStyle = ink
        ctx.lineWidth = 2.2
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        if (name === "microphone" || name === "microphone-off") {
            ctx.beginPath()
            ctx.roundedRect(9, 3, 6, 12, 3, 3)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(6, 10)
            ctx.lineTo(6, 12)
            ctx.arc(12, 12, 6, Math.PI, 0, true)
            ctx.lineTo(18, 10)
            ctx.moveTo(12, 18)
            ctx.lineTo(12, 22)
            ctx.moveTo(8, 22)
            ctx.lineTo(16, 22)
            ctx.stroke()
            if (name === "microphone-off") {
                ctx.beginPath()
                ctx.moveTo(3, 3)
                ctx.lineTo(21, 21)
                ctx.stroke()
            }
        } else if (name === "speaker" || name === "speaker-off") {
            ctx.beginPath()
            ctx.moveTo(11, 4)
            ctx.lineTo(6, 8)
            ctx.lineTo(3, 8)
            ctx.lineTo(3, 16)
            ctx.lineTo(6, 16)
            ctx.lineTo(11, 20)
            ctx.closePath()
            ctx.stroke()
            ctx.beginPath()
            if (name === "speaker-off") {
                ctx.moveTo(16, 9)
                ctx.lineTo(22, 15)
                ctx.moveTo(22, 9)
                ctx.lineTo(16, 15)
            } else {
                ctx.arc(12, 12, 6, -Math.PI / 3, Math.PI / 3)
                ctx.moveTo(17, 3.34)
                ctx.arc(12, 12, 10, -Math.PI / 3, Math.PI / 3)
            }
            ctx.stroke()
        } else if (name === "close") {
            ctx.beginPath()
            ctx.moveTo(5, 5)
            ctx.lineTo(19, 19)
            ctx.moveTo(19, 5)
            ctx.lineTo(5, 19)
            ctx.stroke()
        } else if (name === "edit") {
            ctx.beginPath()
            ctx.moveTo(5, 18.5)
            ctx.lineTo(8.8, 17.7)
            ctx.lineTo(18.3, 8.2)
            ctx.quadraticCurveTo(19.2, 7.3, 18.3, 6.4)
            ctx.lineTo(17.1, 5.2)
            ctx.quadraticCurveTo(16.2, 4.3, 15.3, 5.2)
            ctx.lineTo(5.8, 14.7)
            ctx.lineTo(5, 18.5)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(13.9, 6.6)
            ctx.lineTo(16.9, 9.6)
            ctx.stroke()
        } else if (name === "trash") {
            ctx.beginPath()
            ctx.moveTo(5, 7)
            ctx.lineTo(19, 7)
            ctx.moveTo(9.5, 4.5)
            ctx.lineTo(14.5, 4.5)
            ctx.moveTo(10.5, 4.5)
            ctx.lineTo(10, 7)
            ctx.moveTo(13.5, 4.5)
            ctx.lineTo(14, 7)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(7.5, 9)
            ctx.lineTo(8.4, 19.5)
            ctx.quadraticCurveTo(8.5, 20.5, 9.5, 20.5)
            ctx.lineTo(14.5, 20.5)
            ctx.quadraticCurveTo(15.5, 20.5, 15.6, 19.5)
            ctx.lineTo(16.5, 9)
            ctx.stroke()

            ctx.lineWidth = 1.8
            ctx.beginPath()
            ctx.moveTo(11, 11.5)
            ctx.lineTo(11, 17.5)
            ctx.moveTo(13, 11.5)
            ctx.lineTo(13, 17.5)
            ctx.stroke()
        } else if (name === "add") {
            ctx.beginPath()
            ctx.moveTo(12, 4)
            ctx.lineTo(12, 20)
            ctx.moveTo(4, 12)
            ctx.lineTo(20, 12)
            ctx.stroke()
        } else if (name === "power") {
            ctx.beginPath()
            ctx.moveTo(12, 3)
            ctx.lineTo(12, 12)
            ctx.moveTo(7.5, 5.5)
            ctx.arc(12, 12, 8, -Math.PI * 0.69, Math.PI * 1.69)
            ctx.stroke()
        } else if (name === "bluetooth") {
            ctx.beginPath()
            ctx.moveTo(11, 2)
            ctx.lineTo(11, 22)
            ctx.lineTo(17, 17)
            ctx.lineTo(7, 8)
            ctx.moveTo(11, 2)
            ctx.lineTo(17, 7)
            ctx.lineTo(7, 16)
            ctx.stroke()
        } else if (name === "wifi") {
            for (const radius of [9, 5.5]) {
                ctx.beginPath()
                ctx.arc(12, 17, radius, Math.PI * 1.19, Math.PI * 1.81)
                ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(12, 18.5, 1.5, 0, Math.PI * 2)
            ctx.fill()
        } else if (name === "weather-moon") {
            ctx.beginPath()
            ctx.moveTo(10, 2.5)
            ctx.bezierCurveTo(5, 1, 2, 5, 3.5, 9)
            ctx.bezierCurveTo(5, 13, 10, 14, 13, 10.5)
            ctx.bezierCurveTo(8, 11, 6.5, 6, 10, 2.5)
            ctx.closePath()
            ctx.stroke()
        } else if (name === "weather" || name === "weather-sun" || name === "weather-cloud") {
            if (name !== "weather-cloud") {
                ctx.beginPath()
                ctx.arc(8, 8, 3.2, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(8, 2)
                ctx.lineTo(8, 1)
                ctx.moveTo(2, 8)
                ctx.lineTo(1, 8)
                ctx.moveTo(4, 4)
                ctx.lineTo(3, 3)
                ctx.moveTo(12, 4)
                ctx.lineTo(13, 3)
                ctx.stroke()
            }
            if (name !== "weather-sun") {
                ctx.beginPath()
                ctx.moveTo(5, 19)
                ctx.bezierCurveTo(2, 19, 2, 15, 5, 15)
                ctx.bezierCurveTo(5, 11, 10, 10, 12, 13)
                ctx.bezierCurveTo(15, 11, 20, 13, 20, 16)
                ctx.bezierCurveTo(22, 18, 20, 21, 17, 21)
                ctx.lineTo(5, 21)
                ctx.stroke()
            }
        } else if (name === "code") {
            ctx.beginPath()
            ctx.moveTo(9, 5)
            ctx.lineTo(3, 12)
            ctx.lineTo(9, 19)
            ctx.moveTo(15, 5)
            ctx.lineTo(21, 12)
            ctx.lineTo(15, 19)
            ctx.moveTo(14, 4)
            ctx.lineTo(10, 20)
            ctx.stroke()
        } else if (name === "browser") {
            ctx.beginPath()
            ctx.arc(12, 12, 9, 0, Math.PI * 2)
            ctx.moveTo(4, 8)
            ctx.lineTo(20, 8)
            ctx.moveTo(12, 3)
            ctx.bezierCurveTo(5, 7, 8, 17, 12, 21)
            ctx.moveTo(12, 3)
            ctx.bezierCurveTo(19, 7, 16, 17, 12, 21)
            ctx.stroke()
        } else if (name === "terminal") {
            ctx.strokeRect(3, 5, 18, 14)
            ctx.beginPath()
            ctx.moveTo(6, 9)
            ctx.lineTo(9, 12)
            ctx.lineTo(6, 15)
            ctx.moveTo(12, 16)
            ctx.lineTo(17, 16)
            ctx.stroke()
        } else if (name === "files") {
            ctx.beginPath()
            ctx.moveTo(3, 7)
            ctx.lineTo(9, 7)
            ctx.lineTo(11, 10)
            ctx.lineTo(21, 10)
            ctx.lineTo(21, 19)
            ctx.lineTo(3, 19)
            ctx.closePath()
            ctx.stroke()
        } else if (name === "docker") {
            for (const x of [4, 9, 14]) {
                ctx.strokeRect(x, 7, 4, 4)
                ctx.strokeRect(x, 12, 4, 4)
            }
            ctx.beginPath()
            ctx.moveTo(3, 18)
            ctx.bezierCurveTo(8, 21, 16, 21, 21, 17)
            ctx.stroke()
        } else if (name === "git") {
            ctx.beginPath()
            ctx.moveTo(8, 5)
            ctx.lineTo(8, 18)
            ctx.moveTo(8, 10)
            ctx.bezierCurveTo(8, 14, 16, 10, 16, 15)
            ctx.stroke()
            for (const point of [[8, 5], [8, 19], [16, 16]]) {
                ctx.beginPath()
                ctx.arc(point[0], point[1], 2, 0, Math.PI * 2)
                ctx.fill()
            }
        } else if (name === "settings") {
            ctx.beginPath()
            ctx.arc(12, 12, 4.3, 0, Math.PI * 2)
            ctx.stroke()
            for (let step = 0; step < 8; step++) {
                const angle = step * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(12 + Math.cos(angle) * 7, 12 + Math.sin(angle) * 7)
                ctx.lineTo(12 + Math.cos(angle) * 10, 12 + Math.sin(angle) * 10)
                ctx.stroke()
            }
        }
    }
}
