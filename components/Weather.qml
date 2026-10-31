import QtQuick

ClockWeatherCard {
    id: card

    width: 256
    height: 172
    componentKey: "weather"
    property date now: new Date()
    readonly property bool isDaytime: now.getHours() >= 6 && now.getHours() < 18
    readonly property int temperature: backend.temperature
    readonly property string condition: backend.condition
    readonly property int high: backend.high
    readonly property int low: backend.low
    readonly property string location: backend.location
    readonly property color accentColor: Theme.clockAccent

    Timer {
        interval: 60000
        running: card.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: card.now = new Date()
    }

    Column {
        anchors {
            left: parent.left

            leftMargin: 26

            right: parent.right

            rightMargin: 24

            verticalCenter: parent.verticalCenter
        }

        spacing: 8

        // ------------------------------------------
        // Weather icon + temp
        // ------------------------------------------

        Row {
            id: weatherSummary
            width: parent.width
            spacing: 12

            // --------------------------------------
            // Weather icon
            // --------------------------------------

            Item {
                id: weatherIcon
                width: 64
                height: 58

                FlatIcon {
                    anchors.fill: parent
                    name: card.isDaytime ? "weather-sun" : "weather-moon"
                    ink: card.accentColor
                }

                FlatIcon {
                    id: cloudIcon
                    anchors.fill: parent
                    name: "weather-cloud"
                    ink: card.accentColor

                    transform: Translate {
                        SequentialAnimation on y {
                            running: cloudIcon.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 0
                                to: -3
                                duration: 2200
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                from: -3
                                to: 0
                                duration: 2200
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }

            // --------------------------------------
            // Temperature
            // --------------------------------------

            Column {
                anchors.verticalCenter: parent.verticalCenter

                width: weatherSummary.width - weatherIcon.width - weatherSummary.spacing

                spacing: 2

                PopText {
                    animate: card.ready

                    text: backend.weatherAvailable ? card.temperature + "°" : "--°"

                    color: card.textColor

                    font {
                        family: card.family

                        pixelSize: 35

                        weight: Font.Medium
                    }
                }

                Item {
                    id: conditionArea
                    width: parent.width
                    height: conditionText.implicitHeight
                    clip: true

                    PopText {
                        id: conditionText
                        animate: card.ready
                        text: card.condition
                        color: card.dimColor

                        font {
                            family: card.family
                            pixelSize: 13
                        }

                        x: 0

                        SequentialAnimation on x {
                            running: conditionText.width > conditionArea.width
                            loops: Animation.Infinite

                            PauseAnimation {
                                duration: 1000
                            }

                            NumberAnimation {
                                to: conditionArea.width - conditionText.width
                                duration: 8000
                                easing.type: Easing.InOutSine
                            }

                            PauseAnimation {
                                duration: 1000
                            }

                            NumberAnimation {
                                to: 0
                                duration: 8000
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------
        // High + low
        // ------------------------------------------

        Row {
            spacing: 10

            Text {
                text: "↑ " + (backend.weatherAvailable ? card.high : "--") + "°"

                color: card.dimColor

                font {
                    family: card.family

                    pixelSize: 12
                }
            }

            Text {
                text: "↓ " + (backend.weatherAvailable ? card.low : "--") + "°"

                color: card.dimColor

                font {
                    family: card.family

                    pixelSize: 12
                }
            }

            Text {
                text: "⌁"

                color: Qt.alpha(card.textColor, 0.55)

                font.pixelSize: 13
            }

            Text {
                text: card.isDaytime ? "☼" : "☾"

                color: Qt.alpha(card.textColor, 0.55)

                font.pixelSize: 12
            }
        }

        // ------------------------------------------
        // Location
        // ------------------------------------------

        Row {
            spacing: 6

            Canvas {
                width: 11
                height: 14

                anchors.verticalCenter: parent.verticalCenter

                property color pinColor: card.dimColor

                onPinColorChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");

                    ctx.reset();

                    ctx.strokeStyle = pinColor;

                    ctx.lineWidth = 1.4;

                    ctx.beginPath();

                    ctx.arc(5.5, 5.2, 4, Math.PI * 0.8, Math.PI * 2.2);

                    ctx.lineTo(5.5, 13);

                    ctx.closePath();

                    ctx.stroke();

                    ctx.beginPath();

                    ctx.arc(5.5, 5.2, 1.4, 0, Math.PI * 2);

                    ctx.stroke();
                }
            }

            Text {
                text: card.location

                color: card.dimColor

                font {
                    family: card.family

                    pixelSize: 12
                }
            }
        }
    }
}
