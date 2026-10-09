import QtQuick

Item {
    id: win

    width: 440
    height: 172
    focus: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_O) {
            bars.cycleOrientation()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Theme.componentSurfaceFor("audio-spectrum")
    }

    SpectrumBars {
        id: bars
        anchors.fill: parent
        anchors.leftMargin: 26
        anchors.rightMargin: 26
        anchors.topMargin: 24
        anchors.bottomMargin: 24

        barCount: 48
        levels: win.visible ? backend.spectrum : []
        orientation: SpectrumBars.Inward
        gap: 4
        minimumBarHeight: 4
        sensitivity: 1.35
        barColor: Theme.accent
        barOpacity: 0.9
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: win.forceActiveFocus()
    }
}
