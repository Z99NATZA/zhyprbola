import QtQuick

Item {
    id: panelRoot

    property bool opened: false
    property bool standalone: false
    readonly property string family: Qt.application.font.family
    readonly property color surfaceColor: Theme.panelSurface
    readonly property color textColor: Theme.text
    readonly property color secondaryColor: Theme.secondary

    signal closeRequested()

    anchors.fill: parent
    visible: opened || opacity > 0
    opacity: opened ? 1 : 0
    z: 112

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: panelRoot.surfaceColor
    }

    Column {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 18

        Row {
            width: parent.width
            height: 34
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - closeButton.width - parent.spacing
                text: "Clock & Weather"
                color: panelRoot.textColor
                elide: Text.ElideRight
                font {
                    family: panelRoot.family
                    pixelSize: 22
                    weight: Font.DemiBold
                }
            }

            Rectangle {
                id: closeButton

                width: 30
                height: 30
                radius: 9
                color: closeMouse.containsMouse ? Theme.controlHover : Theme.control

                Text {
                    anchors.centerIn: parent
                    text: "x"
                    color: panelRoot.textColor
                    font {
                        family: panelRoot.family
                        pixelSize: 18
                        weight: Font.Medium
                    }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panelRoot.closeRequested()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 210
            radius: 14
            color: Theme.control

            ClockWeather {
                anchors.centerIn: parent
            }
        }
    }
}
