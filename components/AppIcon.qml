import QtQuick

Item {
    property string name: ""

    width: 52
    height: 52

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.accent
    }

    FlatIcon {
        anchors.centerIn: parent
        width: 29
        height: 29
        name: parent.name.toLowerCase()
        ink: Theme.accentText
    }
}
