import QtQuick
import QtQuick.Controls as Controls

// Menu row "Opacity: [bar]" for one card's own background opacity.
// Dragging previews in this process only; the value is saved once on release,
// so other processes reload the setting a single time.
// With namePrefix "x", objectNames are "x-opacity" and "x-opacity-slider".
Rectangle {
    id: root

    property string namePrefix: ""
    required property string componentKey
    readonly property int percent: Math.round(Theme.componentOpacityPercentFor(componentKey))

    objectName: namePrefix === "" ? "" : namePrefix + "-opacity"
    implicitWidth: 24 + title.implicitWidth + slider.implicitWidth + labels.spacing
    implicitHeight: 34
    radius: 7
    color: hover.hovered ? Theme.controlHover : "transparent"

    HoverHandler {
        id: hover
    }

    component Label: Text {
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

        Label {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            text: "Opacity:"
        }

        Controls.Slider {
            id: slider
            objectName: root.namePrefix === "" ? "" : root.namePrefix + "-opacity-slider"
            anchors.verticalCenter: parent.verticalCenter
            // Fills the row; the row's own width never depends on this.
            width: Math.max(implicitWidth, root.width - 24 - title.implicitWidth
                - labels.spacing)
            implicitWidth: 120
            height: 14
            padding: 0
            from: 0
            to: 100
            stepSize: 1
            snapMode: Controls.Slider.SnapAlways
            value: root.percent
            focusPolicy: Qt.NoFocus
            // Only a press that moved the value saves it, so a plain click
            // does not pin the card to the Settings value.
            property bool moved: false
            onMoved: {
                moved = true
                Theme.previewCardOpacity(root.componentKey, Math.round(value))
            }
            onPressedChanged: {
                if (pressed || !moved) return
                moved = false
                backend.setCardOpacity(root.componentKey, Math.round(value))
                Theme.previewCardOpacity(root.componentKey, undefined)
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            // Same look as the Settings opacity bar: a rounded track whose accent
            // fill ends in a straight moving edge.
            background: Rectangle {
                id: track
                y: (slider.height - height) / 2
                width: slider.width
                height: slider.height
                radius: height / 2
                color: Theme.track

                Item {
                    width: parent.width * slider.position
                    height: parent.height
                    clip: true
                    opacity: slider.pressed ? 0.88 : 1
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Rectangle {
                        width: track.width
                        height: track.height
                        radius: track.radius
                        color: Theme.accent
                    }
                }
            }

            handle: Item {
                x: slider.visualPosition * (slider.availableWidth - width)
                width: slider.height
                height: slider.height
            }
        }
    }
}
