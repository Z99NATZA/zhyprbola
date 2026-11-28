pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

// Right-click overlay for a card: "Border: show | hide", stored per card key.
// Place it as the last child of the card so it sits above the card content.
Item {
    id: root

    property string componentKey: ""
    readonly property bool borderVisible: Theme.cardBorderVisible(componentKey)
    readonly property color borderColor: Theme.cardOutline

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

        // Drawn inside the card window so it shows at once; no open/close animation.
        enter: null
        exit: null

        background: Rectangle {
            radius: 8
            color: Theme.cardSurface
            border.width: 1
            border.color: root.borderColor
        }

        contentItem: ToggleRow {
            namePrefix: root.componentKey + "-border"
            label: "Border"
            onText: "show"
            offText: "hide"
            active: root.borderVisible
            onToggled: Theme.toggleCardBorder(root.componentKey)
        }
    }
}
