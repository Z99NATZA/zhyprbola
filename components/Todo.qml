import QtQuick

Item {
    id: win

    width: 360
    height: 280


    // ==================================================
    // Background
    // ==================================================



    // ==================================================
    // Todo Card
    // ==================================================

    Item {
        id: card

        anchors.centerIn: parent

        width: 360
        height: 280

        property color textColor: "#FFFFFF"
        property color dimColor: Qt.alpha(textColor, 0.72)

        property color glassColor:
            Qt.rgba(0.22, 0.17, 0.25, 0.84)

        property color borderColor:
            Qt.rgba(1, 1, 1, 0.24)

        property color accentColor:
            "#F3A5CD"

        property color checkedTextColor:
            "#F0B4D1"

        property real cornerRadius: 26
        property real rimStrength: 0.20
        property int rimSize: 4

        readonly property string family:
            Qt.application.font.family

        property int completedCount: 2
        property int totalCount: 5

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
                        position: 0
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.01)
                    }

                    GradientStop {
                        position: 1
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
            id: title

            anchors {
                left: parent.left
                top: parent.top

                leftMargin: 24
                topMargin: 20
            }

            text: "Today"

            color: card.textColor

            font {
                family: card.family
                pixelSize: 19
                weight: Font.DemiBold
            }
        }

        Text {
            id: progressText

            anchors {
                right: addButton.left
                rightMargin: 14

                verticalCenter:
                    addButton.verticalCenter
            }

            text:
                card.completedCount
                    + "/"
                    + card.totalCount

            color: card.dimColor

            font {
                family: card.family
                pixelSize: 15
                weight: Font.Medium
            }
        }

        // ==================================================
        // Add button
        // ==================================================

        Item {
            id: addButton

            anchors {
                right: parent.right
                top: parent.top

                rightMargin: 21
                topMargin: 16
            }

            width: 30
            height: 30

            scale:
                addHover.hovered
                    ? 1.08
                    : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                }
            }

            Rectangle {
                anchors.fill: parent

                radius: width / 2

                color:
                    Qt.rgba(
                        1,
                        0.74,
                        0.88,
                        0.88
                    )
            }

            Text {
                anchors.centerIn: parent

                text: "+"

                color: "#674b68"

                font {
                    family: card.family
                    pixelSize: 20
                    weight: Font.Medium
                }
            }

            HoverHandler {
                id: addHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            }
        }

        // ==================================================
        // Todo List
        // ==================================================

        Column {
            id: todoList

            anchors {
                left: parent.left
                right: parent.right

                top: title.bottom
                topMargin: 14

                leftMargin: 24
                rightMargin: 24
            }

            spacing: 0

            TodoRow {
                taskText: "Finish RAG chunking"
                checked: true
            }

            TodoRow {
                taskText: "Update wfchat UI"
                checked: true
            }

            TodoRow {
                taskText: "Read Rust book"
                checked: false
            }

            TodoRow {
                taskText: "Game prototype (web)"
                checked: false
            }

            TodoRow {
                taskText: "Plan tomorrow"
                checked: false
                showDivider: false
            }
        }
    }

    // ==================================================
    // Todo Row Component
    // ==================================================

    component TodoRow: Item {
        id: row

        property string taskText: ""
        property bool checked: false
        property bool showDivider: true

        width:
            parent
                ? parent.width
                : 300

        height: 42

        // --------------------------------------------------
        // Checkbox
        // --------------------------------------------------

        Item {
            id: checkbox

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

            width: 22
            height: 22

            Rectangle {
                anchors.centerIn: parent

                width: 19
                height: 19

                radius: 6

                color:
                    row.checked
                        ? card.accentColor
                        : "transparent"

                border.width: 1.5

                border.color:
                    row.checked
                        ? card.accentColor
                        : Qt.rgba(
                            1,
                            1,
                            1,
                            0.30
                        )
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1

                visible: row.checked

                text: "✓"

                color: "#684a67"

                font {
                    family: card.family
                    pixelSize: 13
                    weight: Font.Bold
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {
                    row.checked =
                        !row.checked
                }
            }
        }

        // --------------------------------------------------
        // Task Text
        // --------------------------------------------------

        Text {
            anchors {
                left: checkbox.right
                leftMargin: 10

                verticalCenter:
                    parent.verticalCenter
            }

            text: row.taskText

            color:
                row.checked
                    ? card.checkedTextColor
                    : card.textColor

            font {
                family: card.family
                pixelSize: 14
                weight: Font.Medium
            }

            opacity:
                row.checked
                    ? 1.0
                    : 0.90
        }

        // --------------------------------------------------
        // Divider
        // --------------------------------------------------

        Rectangle {
            visible: row.showDivider

            anchors {
                left: checkbox.right
                leftMargin: 10

                right: parent.right
                bottom: parent.bottom
            }

            height: 1

            color:
                Qt.rgba(
                    1,
                    1,
                    1,
                    0.07
                )
        }
    }
}
