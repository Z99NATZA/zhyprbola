import QtQuick

Item {
    id: win

    width: 360
    height: 290


    // ==================================================
    // Background
    // ==================================================



    // ==================================================
    // Calendar Card
    // ==================================================

    Item {
        id: card

        anchors.centerIn: parent

        width: 360
        height: 290

        property color textColor: Theme.text
        property color dimColor: Qt.alpha(textColor, 0.68)

        property color surfaceColor: Theme.cardSurface


        property color accentColor: Theme.accent

        property real cornerRadius: 26

        readonly property string family:
            Qt.application.font.family

        property int year: new Date().getFullYear()
        property int month: new Date().getMonth()
        property int selectedDay: new Date().getDate()

        readonly property var monthNames: [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December"
        ]

        readonly property var weekNames: [
            "Su",
            "Mo",
            "Tu",
            "We",
            "Th",
            "Fr",
            "Sa"
        ]

        function daysInMonth(y, m) {
            return new Date(y, m + 1, 0).getDate()
        }

        function firstDayOfMonth(y, m) {
            return new Date(y, m, 1).getDay()
        }

        function previousMonth() {
            if (month === 0) {
                month = 11
                year--
            } else {
                month--
            }
        }

        function nextMonth() {
            if (month === 11) {
                month = 0
                year++
            } else {
                month++
            }
        }

        scale:
            hover.hovered
                ? 1.015
                : 1.0

        Behavior on scale {
            SpringAnimation {
                spring: 3
                damping: 0.28
            }
        }

        HoverHandler {
            id: hover
        }

        // ==================================================
        // Flat surface
        // ==================================================

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
        }

        // ==================================================
        // Header
        // ==================================================

        Text {
            id: monthTitle

            anchors {
                left: parent.left
                top: parent.top

                leftMargin: 24
                topMargin: 20
            }

            text:
                card.monthNames[card.month]
                    + " "
                    + card.year

            color: card.textColor

            font {
                family: card.family
                pixelSize: 19
                weight: Font.DemiBold
            }
        }

        // Previous month

        Item {
            id: prevButton

            anchors {
                right: nextButton.left
                rightMargin: 12

                verticalCenter:
                    monthTitle.verticalCenter
            }

            width: 28
            height: 28

            Text {
                anchors.centerIn: parent

                text: "‹"
                color: card.dimColor

                font {
                    family: card.family
                    pixelSize: 28
                    weight: Font.Light
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked:
                    card.previousMonth()
            }
        }

        // Next month

        Item {
            id: nextButton

            anchors {
                right: parent.right
                rightMargin: 20

                verticalCenter:
                    monthTitle.verticalCenter
            }

            width: 28
            height: 28

            Text {
                anchors.centerIn: parent

                text: "›"
                color: card.dimColor

                font {
                    family: card.family
                    pixelSize: 28
                    weight: Font.Light
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked:
                    card.nextMonth()
            }
        }

        // ==================================================
        // Week header
        // ==================================================

        Row {
            id: weekHeader

            anchors {
                left: parent.left
                right: parent.right

                top: monthTitle.bottom
                topMargin: 20

                leftMargin: 20
                rightMargin: 20
            }

            Repeater {
                model: card.weekNames

                delegate: Item {
                    required property string modelData

                    width: weekHeader.width / 7
                    height: 24

                    Text {
                        anchors.centerIn: parent

                        text: modelData
                        color: card.dimColor

                        font {
                            family: card.family
                            pixelSize: 13
                            weight: Font.Medium
                        }
                    }
                }
            }
        }

        // ==================================================
        // Calendar Grid
        // ==================================================

        Grid {
            id: calendarGrid

            anchors {
                left: parent.left
                right: parent.right

                top: weekHeader.bottom
                topMargin: 8

                leftMargin: 20
                rightMargin: 20
            }

            columns: 7
            rows: 6

            property int firstDay:
                card.firstDayOfMonth(
                    card.year,
                    card.month
                )

            property int days:
                card.daysInMonth(
                    card.year,
                    card.month
                )

            Repeater {
                model: 42

                delegate: Item {
                    required property int index

                    width: calendarGrid.width / 7
                    height: 34

                    property int dayNumber:
                        index
                        - calendarGrid.firstDay
                        + 1

                    property bool validDay:
                        dayNumber >= 1
                        && dayNumber <= calendarGrid.days

                    property bool selected:
                        validDay
                        && dayNumber === card.selectedDay

                    Rectangle {
                        anchors.centerIn: parent

                        width: 31
                        height: 31

                        radius: width / 2

                        visible:
                            parent.selected

                        color:
                            card.accentColor
                    }

                    Text {
                        anchors.centerIn: parent

                        visible:
                            parent.validDay

                        text:
                            parent.dayNumber

                        color:
                            parent.selected
                                ? Theme.accentText
                                : card.textColor

                        font {
                            family: card.family
                            pixelSize: 14
                            weight:
                                parent.selected
                                    ? Font.DemiBold
                                    : Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        enabled:
                            parent.validDay

                        cursorShape:
                            parent.validDay
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                        onClicked: {
                            card.selectedDay =
                                parent.dayNumber
                        }
                    }
                }
            }
        }
    }
}
