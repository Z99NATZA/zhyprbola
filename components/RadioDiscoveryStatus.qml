import QtQuick

Column {
    id: status
    property bool searching: false
    property string message: ""
    spacing: 12

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 54
        height: 54
        visible: status.searching

        Rectangle {
            anchors.centerIn: parent
            width: 44
            height: 44
            radius: 22
            color: Theme.control
        }
        ActivitySpinner {
            anchors.fill: parent
            running: status.searching && status.visible
            ink: Theme.accent
        }
        FlatIcon {
            anchors.centerIn: parent
            width: 24
            height: 24
            name: "search"
            ink: Theme.accent
            SequentialAnimation on rotation {
                running: status.searching && status.visible
                loops: Animation.Infinite
                NumberAnimation { from: -8; to: 8; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { from: 8; to: -8; duration: 700; easing.type: Easing.InOutSine }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: status.message
        color: Theme.mutedText
        font.family: Qt.application.font.family
        font.pixelSize: 13
    }
}
