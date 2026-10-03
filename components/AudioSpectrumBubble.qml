import QtQuick

Item {
    id: win

    width: 440
    height: 172
    focus: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_O) {
            bars.cycleOrientation()
            event.accepted = true
        }
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: 440
        height: 172

        property color surfaceColor: Theme.cardSurface
        property color textColor: Theme.text
        property color dimColor: Theme.mutedText
        property color accentColor: Theme.accent
        property string family: Qt.application.font.family
        property real cornerRadius: 26

        opacity: 0

        transform: Translate {
            id: enterTransform
            y: 14
        }

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: enterTransform
            property: "y"
            from: 14
            to: 0
            duration: 700
            easing.type: Easing.OutCubic
            running: true
        }

        scale: hover.hovered ? 1.025 : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
                epsilon: 0.001
            }
        }

        HoverHandler {
            id: hover
        }

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
        }

        Text {
            id: title

            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 24
                topMargin: 18
            }

            text: "Audio Spectrum"
            color: card.textColor

            font {
                family: card.family
                pixelSize: 20
                weight: Font.DemiBold
            }
        }

        Text {
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 24
                topMargin: 24
            }

            text: bars.orientationLabel
            color: card.dimColor

            font {
                family: card.family
                pixelSize: 12
                weight: Font.Medium
            }
        }

        SpectrumBars {
            id: bars

            anchors {
                left: parent.left
                right: parent.right
                top: title.bottom
                bottom: parent.bottom
                leftMargin: 26
                rightMargin: 26
                topMargin: 14
                bottomMargin: 22
            }

            barCount: 48
            gap: 4
            minimumBarHeight: 4
            sensitivity: 1.35
            barColor: card.accentColor
            barOpacity: 0.82
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {
                win.forceActiveFocus()
            }
        }
    }
}
