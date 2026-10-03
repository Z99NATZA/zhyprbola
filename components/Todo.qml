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

        property color textColor: Theme.text
        property color dimColor: Qt.alpha(textColor, 0.72)

        property color surfaceColor: Theme.cardSurface


        property color accentColor: Theme.accent

        property color checkedTextColor: Theme.checkedText

        property real cornerRadius: 26

        readonly property string family:
            Qt.application.font.family

        property int completedCount: 2
        property int totalCount: 5

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

                color: Theme.accent
            }

            FlatIcon {
                anchors.centerIn: parent
                width: 18
                height: 18
                name: "add"
                ink: Theme.accentText
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
                        : Theme.control
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1

                visible: row.checked

                text: "✓"

                color: Theme.accentText

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
