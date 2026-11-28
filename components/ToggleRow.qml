import QtQuick

// Menu row "Label: on off" as plain text: the active choice is solid, the other
// faded. Clicking anywhere on the row emits toggled().
// With namePrefix "x", objectNames are "x-toggle", "x-<onText>", "x-<offText>".
Rectangle {
    id: root

    property string namePrefix: ""
    property string label: ""
    property string onText: "on"
    property string offText: "off"
    property bool active: false

    signal toggled()

    objectName: namePrefix === "" ? "" : namePrefix + "-toggle"
    implicitWidth: labels.implicitWidth + 24
    implicitHeight: 34
    radius: 7
    color: mouse.containsMouse ? Theme.controlHover : "transparent"

    component Choice: Text {
        color: Theme.text
        font.family: Qt.application.font.family
        font.pixelSize: 14
    }

    Row {
        id: labels
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Choice {
            text: root.label + ":"
        }
        Choice {
            objectName: root.namePrefix === "" ? "" : root.namePrefix + "-" + root.onText
            readonly property bool active: root.active
            text: root.onText
            opacity: active ? 1 : 0.35
        }
        Choice {
            objectName: root.namePrefix === "" ? "" : root.namePrefix + "-" + root.offText
            readonly property bool active: !root.active
            text: root.offText
            opacity: active ? 1 : 0.35
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggled()
    }
}
