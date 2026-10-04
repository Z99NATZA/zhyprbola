import QtQuick

Item {
    id: panel

    width: 560
    height: 470
    property string section: "themes"
    signal closeRequested()
    readonly property int contentRowHeight: 46
    readonly property int contentItemGap: 8
    readonly property int contentSectionGap: 16

    readonly property var sections: [
        {key: "themes", label: "Themes"},
        {key: "dock", label: "Dock"},
        {key: "components", label: "Components"},
        {key: "spectrum", label: "Spectrum"},
        {key: "wallpaper", label: "Wallpaper"}
    ]
    readonly property var themes: [
        {key: "current", label: "Purple", accent: "#875A82"},
        {key: "white", label: "White Mist", accent: "#467B9D"},
        {key: "white-sky", label: "White Sky", accent: "#1E73E7"},
        {key: "forest", label: "Forest Calm", accent: "#477F6D"},
        {key: "one-half-gray", label: "One Half Gray", accent: "#68717D"},
        {key: "red", label: "Red", accent: "#B83252"}
    ]
    readonly property var positions: [
        {key: "left", label: "Left"},
        {key: "right", label: "Right"},
        {key: "top", label: "Top"},
        {key: "bottom", label: "Bottom"}
    ]
    readonly property var groupLabels: ({
        apps: "Apps", zhyprbola: "Zhyprbola", running: "Running"
    })
    readonly property var groupPlaces: backend.dockPosition === "left"
        || backend.dockPosition === "right"
        ? ["Top", "Center", "Bottom"] : ["Left", "Center", "Right"]
    property string draggedGroup: ""
    property bool draggingGroup: false
    property int groupDropIndex: -1
    property var groupPreviewOrder: []
    property real groupDragStartX: 0
    property real groupDragStartY: 0
    property real groupDragOffsetX: 0
    property real groupDragOffsetY: 0
    property string draggedComponent: ""
    property bool draggingComponent: false
    property string componentDropZone: ""
    property string componentBeforeKey: ""
    property var componentPreviewShow: []
    property var componentPreviewHidden: []
    property real dragStartX: 0
    property real dragStartY: 0

    function beginGroupDrag(name, point, offsetX, offsetY) {
        draggedGroup = name
        groupDragStartX = point.x
        groupDragStartY = point.y
        groupDragOffsetX = offsetX
        groupDragOffsetY = offsetY
        groupPreviewOrder = backend.dockGroupOrder.slice()
        groupDropIndex = -1
    }

    function updateGroupDrag(point) {
        if (!draggedGroup)
            return
        if (!draggingGroup) {
            const dx = point.x - groupDragStartX
            const dy = point.y - groupDragStartY
            if (dx * dx + dy * dy < 36)
                return
            draggingGroup = true
        }

        floatingGroup.x = point.x - groupDragOffsetX
        floatingGroup.y = point.y - groupDragOffsetY
        const local = groupSlots.mapFromItem(panel, point.x, point.y)
        const inside = local.x >= 0 && local.x < groupSlots.width
            && local.y >= 0 && local.y < groupSlots.height
        const order = backend.dockGroupOrder.slice()
        if (inside) {
            groupDropIndex = Math.max(0, Math.min(order.length - 1,
                Math.floor((local.x + 4) / 122)))
            const preview = order.filter(name => name !== draggedGroup)
            preview.splice(groupDropIndex, 0, draggedGroup)
            if (preview.join(',') !== groupPreviewOrder.join(','))
                groupPreviewOrder = preview
        } else {
            groupDropIndex = -1
            if (order.join(',') !== groupPreviewOrder.join(','))
                groupPreviewOrder = order
        }
    }

    function finishGroupDrag(commit) {
        const name = draggedGroup
        const index = groupDropIndex
        const shouldCommit = commit && draggingGroup && index >= 0
        draggedGroup = ""
        draggingGroup = false
        groupDropIndex = -1
        groupPreviewOrder = []
        if (shouldCommit)
            backend.moveDockGroup(name, index)
    }

    function beginComponentDrag(key, point) {
        draggedComponent = key
        dragStartX = point.x
        dragStartY = point.y
        componentPreviewShow = backend.dockVisibleComponents.slice()
        componentPreviewHidden = backend.dockHiddenComponents.slice()
    }

    function updateComponentDrag(point) {
        if (!draggedComponent)
            return
        if (!draggingComponent) {
            const dx = point.x - dragStartX
            const dy = point.y - dragStartY
            if (dx * dx + dy * dy < 36)
                return
            draggingComponent = true
        }

        floatingComponent.x = point.x - floatingComponent.width / 2
        floatingComponent.y = point.y - floatingComponent.height / 2
        let destination = null
        let localPoint = null
        for (const zone of [showZone, hiddenZone]) {
            const local = zone.mapFromItem(panel, point.x, point.y)
            if (local.x >= 0 && local.x < zone.width
                && local.y >= 0 && local.y < zone.height) {
                destination = zone
                localPoint = local
                break
            }
        }
        showZone.dropHovered = destination === showZone
        hiddenZone.dropHovered = destination === hiddenZone
        componentDropZone = destination ? destination.zoneKey : ""
        componentBeforeKey = ""

        const show = backend.dockVisibleComponents.slice()
            .filter(key => key !== draggedComponent)
        const hidden = backend.dockHiddenComponents.slice()
            .filter(key => key !== draggedComponent)
        if (destination) {
            const target = destination.zoneKey === "visible" ? show : hidden
            const row = Math.max(0, Math.floor((localPoint.y - 45 + 18.5) / 37))
            const column = Math.max(0, Math.floor((localPoint.x - 12 + 18.5) / 37))
            const position = Math.max(0, Math.min(target.length, row * 9 + column))
            componentBeforeKey = target[position] || ""
            target.splice(position, 0, draggedComponent)
        } else if (backend.dockVisibleComponents.includes(draggedComponent)) {
            show.splice(backend.dockVisibleComponents.indexOf(draggedComponent),
                0, draggedComponent)
        } else {
            hidden.splice(backend.dockHiddenComponents.indexOf(draggedComponent),
                0, draggedComponent)
        }
        if (show.join(',') !== componentPreviewShow.join(','))
            componentPreviewShow = show
        if (hidden.join(',') !== componentPreviewHidden.join(','))
            componentPreviewHidden = hidden
    }

    function finishComponentDrag() {
        const key = draggedComponent
        const destination = componentDropZone
        const beforeKey = componentBeforeKey
        const commit = draggingComponent && destination !== ""
        draggedComponent = ""
        draggingComponent = false
        componentDropZone = ""
        componentBeforeKey = ""
        componentPreviewShow = []
        componentPreviewHidden = []
        showZone.dropHovered = false
        hiddenZone.dropHovered = false
        if (commit)
            backend.moveDockComponent(key, destination, beforeKey)
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.panelSurface
    }

    Rectangle {
        x: 12
        y: 12
        width: 150
        height: parent.height - 24
        radius: 15
        color: Theme.control

        Text {
            x: 15
            y: 17
            text: "Settings"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 19
            font.weight: Font.DemiBold
        }

        Column {
            x: 8
            y: 60
            width: parent.width - 16
            spacing: 5

            Repeater {
                model: panel.sections

                delegate: Rectangle {
                    required property var modelData
                    width: 134
                    height: 40
                    radius: 10
                    color: panel.section === modelData.key
                        ? Theme.accent
                        : (navMouse.containsMouse ? Theme.controlHover : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: panel.section === modelData.key
                            ? Theme.accentText : Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: panel.section === modelData.key
                            ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.section = modelData.key
                    }
                }
            }
        }
    }

    Text {
        x: 184
        y: 29
        text: panel.section === "themes" ? "Themes"
            : (panel.section === "dock" ? "Dock"
            : (panel.section === "components" ? "Components"
            : (panel.section === "spectrum" ? "Edge spectrum" : "Wallpaper")))
        color: Theme.text
        font.family: Qt.application.font.family
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    Rectangle {
        x: parent.width - 45
        y: 20
        width: 29
        height: 29
        radius: 9
        color: closeMouse.containsMouse ? Theme.controlHover : Theme.control

        Text {
            anchors.centerIn: parent
            text: "×"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 20
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.closeRequested()
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: panel.contentItemGap
        visible: panel.section === "themes"

        Repeater {
            model: panel.themes

            delegate: Rectangle {
                required property var modelData
                width: 358
                height: panel.contentRowHeight
                radius: 11
                color: backend.themeName === modelData.key
                    ? Theme.selected
                    : (themeMouse.containsMouse ? Theme.controlHover : Theme.control)

                Rectangle {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 7
                    color: modelData.accent
                }

                Text {
                    x: 47
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.text
                    font.family: Qt.application.font.family
                    font.pixelSize: 14
                    font.weight: backend.themeName === modelData.key
                        ? Font.DemiBold : Font.Normal
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: backend.themeName === modelData.key
                    text: "✓"
                    color: Theme.accent
                    font.family: Qt.application.font.family
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: themeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.setThemeName(modelData.key)
                }
            }
        }
    }

    Column {
        objectName: "dock-settings-content"
        x: 184
        y: 76
        width: 358
        spacing: panel.contentSectionGap
        visible: panel.section === "dock"

        Row {
            width: 358
            height: panel.contentRowHeight
            spacing: 6

            Repeater {
                model: panel.positions

                delegate: Rectangle {
                    required property var modelData
                    objectName: "dock-position-" + modelData.key
                    width: 85
                    height: panel.contentRowHeight
                    radius: 11
                    color: backend.dockPosition === modelData.key
                        ? Theme.selected
                        : (positionMouse.containsMouse ? Theme.controlHover : Theme.control)

                    Text {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 13
                        font.weight: backend.dockPosition === modelData.key
                            ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: backend.dockPosition === modelData.key
                        text: "✓"
                        color: Theme.accent
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: positionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setDockPosition(modelData.key)
                    }
                }
            }
        }

        Item {
            id: groupSlots
            width: 358
            height: 90

            Rectangle {
                width: 114
                height: 90
                radius: 11
                x: panel.groupPreviewOrder.indexOf(panel.draggedGroup) * 122
                visible: panel.draggingGroup && panel.groupDropIndex >= 0
                color: Theme.selected
                border.width: 2
                border.color: Theme.accent
            }

            Repeater {
                model: backend.dockGroupOrder

                delegate: Rectangle {
                    id: groupCard
                    required property string modelData
                    required property int index
                    readonly property string groupName: modelData
                    objectName: "dock-group-" + groupName
                    x: {
                        const position = panel.groupPreviewOrder.indexOf(groupName)
                        return (position < 0 ? index : position) * 122
                    }
                    width: 114
                    height: 90
                    radius: 11
                    color: Theme.control
                    opacity: panel.draggingGroup && panel.draggedGroup === groupName
                        ? 0 : 1

                    Behavior on x {
                        enabled: panel.draggingGroup
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Text {
                        x: 10
                        y: 9
                        text: {
                            const position = panel.groupPreviewOrder.indexOf(groupCard.groupName)
                            return panel.groupPlaces[position < 0 ? groupCard.index : position]
                        }
                        color: Theme.secondary
                        font.family: Qt.application.font.family
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 35
                        text: panel.groupLabels[groupCard.groupName]
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        y: 7
                        text: "⋮⋮"
                        color: Theme.secondary
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: panel.draggingGroup
                            ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: function(mouse) {
                            panel.beginGroupDrag(groupCard.groupName,
                                dragArea.mapToItem(panel, mouse.x, mouse.y),
                                mouse.x, mouse.y)
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                panel.updateGroupDrag(
                                    dragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onReleased: panel.finishGroupDrag(true)
                        onCanceled: panel.finishGroupDrag(false)
                    }
                }
            }
        }

        Column {
            width: 358
            spacing: panel.contentItemGap

            Repeater {
                model: ["zhyprbola", "apps", "running"]

                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool active: backend.dockGroups.includes(modelData)
                    objectName: "dock-group-toggle-" + modelData

                    width: 358
                    height: panel.contentRowHeight
                    radius: 11
                    color: active ? Theme.selected : Theme.control

                    Text {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.groupLabels[modelData]
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: active ? Font.DemiBold : Font.Normal
                    }

                    Rectangle {
                        x: 299
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 26
                        radius: 13
                        color: active ? Theme.accent : Theme.track

                        Rectangle {
                            x: active ? 21 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData !== "zhyprbola"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.setDockGroupEnabled(modelData, !active)
                        }
                    }
                }
            }
        }
    }

    component DockComponentZone: Rectangle {
        id: zone
        required property string zoneKey
        required property var items
        property bool dropHovered: false
        readonly property var displayOrder: panel.draggingComponent
            ? (zoneKey === "visible" ? panel.componentPreviewShow
                : panel.componentPreviewHidden) : items
        objectName: "dock-zone-" + zoneKey

        width: 358
        height: 136
        radius: 12
        color: dropHovered ? Theme.selected : Theme.control
        border.width: dropHovered ? 2 : 0
        border.color: Theme.accent

        Text {
            x: 13
            y: 12
            text: zone.zoneKey === "visible" ? "Show" : "Hidden"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 13
            text: zone.items.length
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Item {
            id: componentRow
            x: 12
            y: 45
            width: 334
            height: 72

            Rectangle {
                width: 34
                height: 34
                radius: 9
                x: (zone.displayOrder.indexOf(panel.draggedComponent) % 9) * 37
                y: Math.floor(zone.displayOrder.indexOf(panel.draggedComponent) / 9) * 37
                visible: panel.draggingComponent
                    && zone.displayOrder.includes(panel.draggedComponent)
                color: Theme.selected
                border.width: 2
                border.color: Theme.accent
            }

            Repeater {
                model: zone.items

                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property string componentKey: modelData
                    objectName: "dock-component-" + zone.zoneKey + "-" + componentKey
                    x: {
                        const position = zone.displayOrder.indexOf(componentKey)
                        return ((position < 0 ? index : position) % 9) * 37
                    }
                    y: {
                        const position = zone.displayOrder.indexOf(componentKey)
                        return Math.floor((position < 0 ? index : position) / 9) * 37
                    }
                    width: 34
                    height: 34
                    radius: 9
                    color: zone.zoneKey === "visible" ? Theme.accent : Theme.mutedText
                    opacity: panel.draggingComponent && panel.draggedComponent === componentKey
                        ? 0 : 1

                    Behavior on x {
                        enabled: panel.draggingComponent
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: panel.draggingComponent
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: Qt.resolvedUrl("../gnome-extension/icons/"
                            + tile.componentKey + ".svg")
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: panel.draggingComponent
                            ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: function(mouse) {
                            panel.beginComponentDrag(tile.componentKey,
                                dragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                panel.updateComponentDrag(
                                    dragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onReleased: panel.finishComponentDrag()
                        onCanceled: panel.finishComponentDrag()
                    }
                }
            }
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: panel.contentSectionGap
        visible: panel.section === "components"

        DockComponentZone {
            id: showZone
            zoneKey: "visible"
            items: backend.dockVisibleComponents
        }

        DockComponentZone {
            id: hiddenZone
            zoneKey: "hidden"
            items: backend.dockHiddenComponents
        }
    }

    Rectangle {
        id: floatingGroup
        objectName: "dock-group-drag-overlay"
        z: 100
        width: 114
        height: 90
        radius: 11
        visible: panel.draggingGroup
        color: Theme.control
        border.width: 2
        border.color: Theme.accent

        Text {
            x: 10
            y: 9
            text: panel.draggedGroup
                ? panel.groupPlaces[panel.groupDropIndex >= 0
                    ? panel.groupDropIndex : backend.dockGroupOrder.indexOf(panel.draggedGroup)]
                : ""
            color: Theme.secondary
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Text {
            anchors.centerIn: parent
            text: panel.groupLabels[panel.draggedGroup] || ""
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 9
            y: 7
            text: "⋮⋮"
            color: Theme.secondary
            font.pixelSize: 13
        }
    }

    Rectangle {
        id: floatingComponent
        objectName: "dock-component-drag-overlay"
        z: 100
        width: 34
        height: 34
        radius: 9
        visible: panel.draggingComponent
        color: Theme.accent

        Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: panel.draggedComponent
                ? Qt.resolvedUrl("../gnome-extension/icons/"
                    + panel.draggedComponent + ".svg") : ""
            fillMode: Image.PreserveAspectFit
        }
    }

    Column {
        x: 184
        y: 76
        width: 358
        spacing: panel.contentSectionGap
        visible: panel.section === "spectrum"

        Rectangle {
            width: 358
            height: panel.contentRowHeight
            radius: 11
            color: Theme.control

            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Show edge spectrum"
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 14
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 26
                radius: 13
                color: backend.edgeSpectrumEnabled ? Theme.accent : Theme.track

                Rectangle {
                    x: backend.edgeSpectrumEnabled ? 21 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.setEdgeSpectrumEnabled(!backend.edgeSpectrumEnabled)
            }
        }

        Column {
            width: 358
            spacing: panel.contentItemGap

            Repeater {
                model: panel.positions

                delegate: Rectangle {
                    required property var modelData
                    width: 358
                    height: panel.contentRowHeight
                    radius: 11
                    color: backend.edgeSpectrumPosition === modelData.key
                        ? Theme.selected
                        : (edgePositionMouse.containsMouse ? Theme.controlHover : Theme.control)

                    Text {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: backend.edgeSpectrumPosition === modelData.key
                            ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: backend.edgeSpectrumPosition === modelData.key
                        text: "✓"
                        color: Theme.accent
                        font.family: Qt.application.font.family
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: edgePositionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setEdgeSpectrumPosition(modelData.key)
                    }
                }
            }
        }
    }

    Rectangle {
        x: 184
        y: 76
        width: 358
        height: panel.contentRowHeight
        radius: 11
        color: Theme.control
        visible: panel.section === "wallpaper"

        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Use theme wallpaper"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 26
            radius: 13
            color: backend.useWallpaper ? Theme.accent : Theme.track

            Rectangle {
                x: backend.useWallpaper ? 21 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: "#ffffff"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setUseWallpaper(!backend.useWallpaper)
        }
    }
}
