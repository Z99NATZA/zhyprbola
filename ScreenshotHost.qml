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
            property int hoveredIndex: -1
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top
                leftMargin: 12; rightMargin: 12; topMargin: 54; bottomMargin: 10 }
            clip: true
            spacing: 6
            boundsBehavior: Flickable.DragAndOvershootBounds
            flickableDirection: Flickable.VerticalFlick
            model: screenshots
            header: Item { width: images.width; height: 12 }
            footer: Item { width: images.width; height: 20 }
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
            delegate: Item {
                id: row
                required property int index
                required property string fileName
                required property string filePath
                required property url imageUrl
                required property string modified
                readonly property bool selected: screenshots.selectedPaths.indexOf(filePath) >= 0
                readonly property Item selectionCard: card
                width: images.width - 12
                height: 88
                Rectangle {
                    id: card
                    x: 24
                    width: parent.width - 24
                    height: parent.height
                    radius: 9
                    color: row.selected ? Components.Theme.selected
                        : images.hoveredIndex === row.index
                            ? Components.Theme.controlHover : Components.Theme.control
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
                }
            }
            Text {
                anchors.centerIn: parent
                visible: images.count === 0
                text: "No screenshots"
                color: Components.Theme.mutedText
            }
        }
        MouseArea {
            id: selectionArea
            objectName: "screenshotSelectionArea"
            anchors.fill: images
            anchors.rightMargin: 12
            clip: true
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton
            property real startX: 0
            property real startY: 0
            property real endX: 0
            property real endY: 0
            property bool dragging: false
            property bool skipClick: false

            function indexAtCard(x, y) {
                const index = images.indexAt(x, y + images.contentY)
                if (index < 0) return -1
                const item = images.itemAtIndex(index)
                if (!item) return -1
                const card = item.selectionCard
                const point = card.mapToItem(selectionArea, 0, 0)
                return x >= point.x && x < point.x + card.width
                    && y >= point.y && y < point.y + card.height ? index : -1
            }

            function updateSelection() {
                const left = Math.min(startX, endX)
                const right = Math.max(startX, endX) + 1
                const top = Math.min(startY, endY)
                const bottom = Math.max(startY, endY) + 1
                const indices = []
                for (let i = 0; i < images.count; ++i) {
                    const item = images.itemAtIndex(i)
                    if (!item) continue
                    const card = item.selectionCard
                    const point = card.mapToItem(selectionArea, 0, 0)
                    if (point.x < right && point.x + card.width > left
                        && point.y < bottom && point.y + card.height > top)
                        indices.push(i)
                }
                screenshots.selectIndices(indices)
            }

            onPressed: function(mouse) {
                startX = endX = mouse.x
                startY = endY = mouse.y
                dragging = false
                skipClick = false
            }
            onPositionChanged: function(mouse) {
                if (!pressed) {
                    images.hoveredIndex = indexAtCard(mouse.x, mouse.y)
                    return
                }
                endX = mouse.x
                endY = mouse.y
                if (!dragging && Math.hypot(endX - startX, endY - startY) >= 6) {
                    dragging = true
                    skipClick = true
                    images.hoveredIndex = -1
                }
                if (dragging) updateSelection()
            }
            onReleased: function(mouse) {
                if (dragging) {
                    endX = mouse.x
                    endY = mouse.y
                    updateSelection()
                }
                dragging = false
            }
            onCanceled: dragging = false
            onClicked: function(mouse) {
                if (skipClick) return
                const index = indexAtCard(mouse.x, mouse.y)
                if (index >= 0)
                    screenshots.select(index, !!(mouse.modifiers & Qt.ControlModifier),
                        !!(mouse.modifiers & Qt.ShiftModifier))
                else if (!(mouse.modifiers & Qt.ControlModifier))
                    screenshots.selectIndices([])
            }
            onExited: images.hoveredIndex = -1
            onWheel: function(wheel) {
                wheel.accepted = false
            }

            Rectangle {
                x: Math.min(selectionArea.startX, selectionArea.endX)
                y: Math.min(selectionArea.startY, selectionArea.endY)
                width: Math.abs(selectionArea.endX - selectionArea.startX)
                height: Math.abs(selectionArea.endY - selectionArea.startY)
                visible: selectionArea.dragging
                color: Qt.rgba(Components.Theme.accent.r, Components.Theme.accent.g,
                    Components.Theme.accent.b, 0.16)
                border.color: Components.Theme.accent
                border.width: 1
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
                    id: selectAllButton
                    objectName: "screenshotSelectAllButton"
                    readonly property bool allSelected: images.count > 0
                        && screenshots.selectedPaths.length === images.count
                    anchors.right: deleteButton.left
                    anchors.rightMargin: 8
                    width: 104
                    height: parent.height
                    text: allSelected ? "Deselect all" : "Select all"
                    enabled: images.count > 0
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        if (allSelected) screenshots.selectIndices([])
                        else screenshots.selectAll()
                    }
                    background: Rectangle {
                        radius: 8
                        color: selectAllButton.hovered ? Components.Theme.controlHover
                            : selectAllButton.allSelected ? Components.Theme.selected
                                : Components.Theme.control
                    }
                    contentItem: Text {
                        text: selectAllButton.text
                        color: Components.Theme.text
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
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
