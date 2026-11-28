pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

ClockWeatherCard {
    id: card

    width: 352
    height: 172
    componentKey: "clock"
    property date now: new Date()
    property bool use24Hour: true
    readonly property bool borderVisible: {
        const mode = backend.clockBorderMode
        return mode === "show" || (mode !== "hide" && Theme.cardBorderWidth > 0)
    }
    border.width: borderVisible ? 1 : 0
    border.color: Theme.cardBorderWidth > 0 ? Theme.cardBorder : Theme.line

    onVisibleChanged: {
        if (!visible) borderMenu.close()
    }

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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            borderMenu.x = mouse.x
            borderMenu.y = mouse.y
            borderMenu.open()
        }
    }

    Connections {
        target: card.Window.window
        enabled: borderMenu.visible
        function onActiveChanged() {
            if (!card.Window.window.active) borderMenu.close()
        }
    }

    Controls.Popup {
        id: borderMenu
        objectName: "clock-border-menu"
        parent: card
        margins: 4
        padding: 0
        focus: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

        Component.onCompleted: {
            // A windowed popup lets the compositor dismiss it outside the clock window.
            if (typeof borderMenu.popupType !== "undefined")
                borderMenu.popupType = Controls.Popup.Window
        }

        background: Rectangle {
            radius: 8
            color: Theme.cardSurface
            border.width: 1
            border.color: card.border.color
        }

        contentItem: MouseArea {
            implicitWidth: borderLabels.implicitWidth + 28
            implicitHeight: 34
            onClicked: backend.setClockBorderMode(card.borderVisible ? "hide" : "show")

            Row {
                id: borderLabels
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: ["Border:", "show", "hide"]

                    Text {
                        required property string modelData
                        text: modelData
                        color: Theme.text
                        font.family: card.family
                        font.pixelSize: 14
                        opacity: modelData === "Border:" || card.borderVisible === (modelData === "show")
                            ? 1 : 0.45
                    }
                }
            }
        }
    }
}
