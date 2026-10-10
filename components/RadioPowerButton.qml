import QtQuick

Item {
    id: control
    objectName: "radioPowerButton"
    property bool checked: false
    property bool busy: false
    signal clicked()
    width: 56
    height: 56
    Accessible.role: Accessible.Button
    Accessible.name: busy ? "Changing radio power" : checked ? "Radio on. Turn off" : "Radio off. Turn on"
    Accessible.onPressAction: { if (enabled && !busy) clicked() }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: powerMouse.containsMouse && control.enabled
            ? Theme.heroControlHover : control.checked ? Theme.heroControl : "transparent"
        border.width: control.checked ? 0 : 2
        border.color: Theme.heroMutedText
    }

    FlatIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: 20
        height: 20
        visible: !control.busy
        name: "power"
        ink: control.checked ? Theme.heroText : Theme.heroMutedText
    }

    ActivitySpinner {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        running: control.busy
        ink: Theme.heroText
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34
        text: control.busy ? "Wait…" : control.checked ? "On" : "Off"
        color: control.checked || control.busy ? Theme.heroText : Theme.heroMutedText
        font.family: Qt.application.font.family
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: powerMouse
        anchors.fill: parent
        enabled: !control.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
}
