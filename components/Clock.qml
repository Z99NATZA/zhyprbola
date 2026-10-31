import QtQuick

ClockWeatherCard {
    id: card

    width: 352
    height: 172
    componentKey: "clock"
    property date now: new Date()
    property bool use24Hour: true

    Timer {
        interval: 1000
        running: card.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: card.now = new Date()
    }

    Column {
        anchors.centerIn: parent

        anchors.verticalCenterOffset: 0

        spacing: 10

        // ------------------------------------------
        // Time
        // ------------------------------------------

        Row {
            anchors.horizontalCenter: parent.horizontalCenter

            spacing: 3

            PopText {
                animate: card.ready

                text: Qt.formatDateTime(card.now, card.use24Hour ? "HH" : "hh")

                color: card.textColor

                font {
                    family: card.family

                    pixelSize: 58

                    weight: Font.Medium
                }
            }

            Text {
                text: ":"

                color: card.textColor

                font {
                    family: card.family

                    pixelSize: 58

                    weight: Font.Medium
                }
            }

            PopText {
                id: minutesText

                animate: card.ready

                text: Qt.formatDateTime(card.now, "mm")

                color: card.textColor

                font {
                    family: card.family

                    pixelSize: 58

                    weight: Font.Medium
                }
            }

            Text {
                anchors.baseline: minutesText.baseline

                text: Qt.formatDateTime(card.now, ":ss")
                color: card.textColor

                font {
                    family: card.family
                    pixelSize: 58
                    weight: Font.Medium
                }
            }
        }

        // ------------------------------------------
        // Date
        // ------------------------------------------

        PopText {
            anchors.horizontalCenter: parent.horizontalCenter

            animate: card.ready

            text: Qt.formatDateTime(card.now, "ddd, MMM d, yyyy")

            color: card.dimColor

            font {
                family: card.family

                pixelSize: 14
            }
        }
    }
}
