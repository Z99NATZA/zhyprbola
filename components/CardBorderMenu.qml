pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

// Right-click overlay for a card: "Border: show | hide", stored per card key.
// Place it as the last child of the card so it sits above the card content.
Item {
    id: root

    property string componentKey: ""
    readonly property string mode: backend.cardBorderModes[componentKey] || ""
    readonly property bool borderVisible:
        mode === "show" || (mode !== "hide" && Theme.cardBorderWidth > 0)
    readonly property color borderColor:
        Theme.cardBorderWidth > 0 ? Theme.cardBorder : Theme.line

    anchors.fill: parent

    onVisibleChanged: {
        if (!visible) borderMenu.close()
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
        target: root.Window.window
        enabled: borderMenu.visible
        function onActiveChanged() {
            if (!root.Window.window.active) borderMenu.close()
        }
    }

    Controls.Popup {
        id: borderMenu
        objectName: root.componentKey + "-border-menu"
        parent: root.parent
        margins: 4
        padding: 0
        focus: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

        Component.onCompleted: {
            // A windowed popup lets the compositor dismiss it outside the card window.
            if (typeof borderMenu.popupType !== "undefined")
                borderMenu.popupType = Controls.Popup.Window
        }

        background: Rectangle {
            radius: 8
            color: Theme.cardSurface
            border.width: 1
            border.color: root.borderColor
        }

        contentItem: MouseArea {
            implicitWidth: borderLabels.implicitWidth + 28
            implicitHeight: 34
            onClicked: backend.setCardBorderMode(root.componentKey,
                root.borderVisible ? "hide" : "show")

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
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        opacity: modelData === "Border:" || root.borderVisible === (modelData === "show")
                            ? 1 : 0.45
                    }
                }
            }
        }
    }
}
