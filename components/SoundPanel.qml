pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Rectangle {
    id: panel
    width: 384
    height: sound.error.length > 0 ? 214 : 184
    radius: 18
    color: Theme.componentSurfaceFor("sound")
    border.color: Theme.secondary
    signal closeRequested()

    Timer {
        interval: 1000
        repeat: true
        running: panel.visible && (!panel.Window.window
            || (panel.Window.window.visible && panel.Window.window.visibility !== Window.Minimized))
        onRunningChanged: { if (running) sound.refresh() }
        onTriggered: sound.refresh()
    }

    Text {
        x: 22
        y: 20
        text: "Sound"
        color: Theme.text
        font.pixelSize: 22
        font.weight: Font.DemiBold
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        width: 32
        height: 32
        radius: 9
        color: closeMouse.containsMouse ? Theme.controlHover : Theme.control
        FlatIcon { anchors.centerIn: parent; width: 16; height: 16; name: "close" }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: panel.closeRequested()
        }
    }

    Column {
        x: 22
        y: 66
        width: parent.width - 44
        spacing: 16
        AudioRow { channel: "microphone"; endpoint: sound.microphone }
        AudioRow { channel: "speaker"; endpoint: sound.speaker }
    }

    Text {
        x: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: parent.width - 44
        visible: sound.error.length > 0
        text: sound.error
        color: Theme.mutedText
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    component AudioRow: Item {
        id: row
        required property string channel
        required property var endpoint
        width: panel.width - 44
        height: 40

        Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 12
            opacity: row.endpoint.available ? 1 : 0.45
            color: row.endpoint.muted ? Theme.accent
                : muteMouse.containsMouse ? Theme.controlHover : Theme.control
            FlatIcon {
                anchors.centerIn: parent
                name: row.channel + (row.endpoint.muted ? "-off" : "")
                ink: row.endpoint.muted ? Theme.accentText : Theme.accent
            }
            MouseArea {
                id: muteMouse
                anchors.fill: parent
                enabled: row.endpoint.available
                hoverEnabled: true
                onClicked: sound.setMuted(row.channel, !row.endpoint.muted)
            }
        }

        Slider {
            id: volumeSlider
            x: 56
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - x
            height: 30
            from: 0
            to: 100
            stepSize: 1
            enabled: row.endpoint.available
            Accessible.name: row.channel === "microphone" ? "Microphone volume" : "Speaker volume"
            onMoved: {
                commitVolume.percent = Math.round(value)
                if (pressed)
                    commitVolume.restart()
                else
                    sound.setVolume(row.channel, commitVolume.percent)
            }
            onPressedChanged: {
                if (!pressed && commitVolume.running) {
                    commitVolume.stop()
                    sound.setVolume(row.channel, commitVolume.percent)
                }
            }
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: volumeSlider.availableWidth
                height: 6
                radius: 3
                color: Theme.track
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: row.endpoint.muted ? Theme.mutedText : Theme.accent
                }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition
                    * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: Theme.accent
                border.color: Theme.panelSurface
                border.width: 2
            }
        }
        Binding {
            target: volumeSlider
            property: "value"
            value: row.endpoint.volume
            when: !volumeSlider.pressed
            restoreMode: Binding.RestoreNone
        }
        Timer {
            id: commitVolume
            property int percent: 0
            interval: 70
            onTriggered: sound.setVolume(row.channel, percent)
        }
    }
}
