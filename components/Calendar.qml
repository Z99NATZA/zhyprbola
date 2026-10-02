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

        property color glassColor: Theme.cardSurface

        property color borderColor: Theme.cardBorder

        property color accentColor: Theme.accent

        property real cornerRadius: 26
        property real rimStrength: 0.20
        property int rimSize: 4

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
        // Glass
        // ==================================================

        Rectangle {
            anchors.fill: parent

            radius: card.cornerRadius
            color: card.glassColor

            border.width: 1
            border.color: card.borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1

                radius: parent.radius - 1

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.01)
                    }

                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(1, 1, 1, 0.03)
                    }
                }
            }

            Repeater {
                model: card.rimSize

                delegate: Rectangle {
                    required property int index

                    anchors.fill: parent
                    anchors.margins: 1 + index

                    radius:
                        Math.max(
                            0,
                            card.cornerRadius - 1 - index
                        )

                    color: "transparent"

                    border.width: 1

                    border.color:
                        Qt.rgba(
                            1,
                            1,
                            1,
                            card.rimStrength
                                * Math.pow(
                                    1 - index / card.rimSize,
                                    2
                                )
                        )
                }
            }

            Rectangle {
                id: sheen

                property real p: 0

                anchors.fill: parent
                anchors.margins: 1

                radius: parent.radius - 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position:
                            Math.max(
                                0.01,
                                Math.min(0.99, sheen.p)
                            )

                        color:
                            Qt.rgba(
                                1,
                                1,
                                1,
                                0.12
                                    * Math.sin(
                                        Math.PI * sheen.p
                                    )
                            )
                    }

                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }

                SequentialAnimation on p {
                    loops: Animation.Infinite

                    PauseAnimation {
                        duration: 5000
                    }

                    NumberAnimation {
                        from: 0
                        to: 1
                        duration: 1800
                        easing.type: Easing.InOutSine
                    }
                }
            }
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
                                ? (Theme.light ? Theme.accentText : "#5B4059")
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
