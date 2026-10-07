import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "components" as Components

Window {
    id: host
    visible: screenshots.opened
    width: 600
    height: 564
    minimumWidth: 360
    minimumHeight: 300
    flags: Qt.FramelessWindowHint | Qt.Tool
    modality: Qt.NonModal
    color: "transparent"
    title: "Zhyprbola Screenshots"

    Shortcut { sequence: "Ctrl+C"; onActivated: screenshots.copyPaths() }
    Shortcut { sequence: "Ctrl+A"; onActivated: screenshots.selectAll() }
    Shortcut { sequence: "Delete"; onActivated: screenshots.deleteSelected() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: screenshots.undo() }
    Shortcut { sequence: "Escape"; onActivated: screenshots.dismiss() }
    onActiveChanged: { if (active) screenshots.refresh() }
    onClosing: function(close) {
        close.accepted = false
        screenshots.dismiss()
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        topLeftRadius: screenshots.edgeSide === "left" ? 0 : 18
        bottomLeftRadius: screenshots.edgeSide === "left" ? 0 : 18
        topRightRadius: screenshots.edgeSide === "right" ? 0 : 18
        bottomRightRadius: screenshots.edgeSide === "right" ? 0 : 18
        color: Components.Theme.panelSurface

        Text {
            x: 18; y: 16
            text: "Screenshots"
            color: Components.Theme.text
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 20
            text: screenshots.selectedPaths.length + " selected"
            color: Components.Theme.mutedText
            font.pixelSize: 12
        }
        ListView {
            id: images
            objectName: "screenshotList"
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top
                leftMargin: 12; rightMargin: 12; topMargin: 54; bottomMargin: 10 }
            clip: true
            spacing: 6
            model: screenshots
            ScrollBar.vertical: ScrollBar {
                id: scrollBar
                objectName: "screenshotScrollBar"
                policy: ScrollBar.AsNeeded
                visible: images.contentHeight > images.height
                contentItem: Rectangle {
                    implicitWidth: 4
                    implicitHeight: 30
                    radius: 2
                    color: Components.Theme.accent
                    opacity: scrollBar.active ? 0.8 : 0.4
                }
                background: Item { }
            }
            delegate: Rectangle {
                id: row
                required property int index
                required property string fileName
                required property string filePath
                required property url imageUrl
                required property string modified
                readonly property bool selected: screenshots.selectedPaths.indexOf(filePath) >= 0
                width: images.width - 12
                height: 88
                radius: 9
                color: selected ? Components.Theme.selected
                    : rowMouse.containsMouse ? Components.Theme.controlHover : Components.Theme.control
                Image {
                    x: 8; y: 8
                    width: 104; height: 72
                    source: row.imageUrl
                    asynchronous: true
                    sourceSize: Qt.size(208, 144)
                    fillMode: Image.PreserveAspectFit
                }
                Column {
                    x: 124; y: 18
                    width: parent.width - x - 12
                    spacing: 8
                    Text {
                        width: parent.width
                        text: row.fileName
                        color: Components.Theme.text
                        elide: Text.ElideMiddle
                        font.pixelSize: 13
                    }
                    Text { text: row.modified; color: Components.Theme.mutedText; font.pixelSize: 11 }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: function(mouse) {
                        screenshots.select(row.index, !!(mouse.modifiers & Qt.ControlModifier),
                            !!(mouse.modifiers & Qt.ShiftModifier))
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: images.count === 0
                text: "No screenshots"
                color: Components.Theme.mutedText
            }
        }
        Column {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
            spacing: 6
            Text {
                width: parent.width
                text: screenshots.error
                visible: text.length > 0
                color: Components.Theme.accent
                wrapMode: Text.Wrap
                font.pixelSize: 12
            }
            Item {
                width: parent.width
                height: 34
                Button {
                    id: deleteButton
                    objectName: "screenshotDeleteButton"
                    anchors.right: parent.right
                    width: 88
                    height: parent.height
                    text: "Delete"
                    enabled: screenshots.selectedPaths.length > 0
                    opacity: enabled ? 1 : 0.4
                    onClicked: screenshots.deleteSelected()
                    background: Rectangle {
                        radius: 8
                        color: deleteButton.down ? Qt.darker(Components.Theme.accent, 1.15)
                            : deleteButton.hovered ? Qt.lighter(Components.Theme.accent, 1.1)
                            : Components.Theme.accent
                    }
                    contentItem: Text {
                        text: deleteButton.text
                        color: Components.Theme.accentText
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
