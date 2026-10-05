import QtQuick

Item {
    id: panel

    width: 660
    height: 510
    property string section: "themes"
    signal closeRequested()
    readonly property int contentRowHeight: 46
    readonly property int contentItemGap: 8
    readonly property int contentSectionGap: 16
    readonly property int contentX: 184
    readonly property int contentWidth: width - contentX - 18
    readonly property int dockPositionGap: 8
    readonly property int dockPositionWidth:
        Math.floor((contentWidth - dockPositionGap * 3) / 4)
    readonly property int dockGroupCardGap: 8
    readonly property int dockGroupFramePadding: 1
    readonly property int dockGroupContentWidth: contentWidth - dockGroupFramePadding * 2
    readonly property int dockGroupCardWidth:
        Math.floor((dockGroupContentWidth - dockGroupCardGap * 2) / 3)
    readonly property int dockGroupStep: dockGroupCardWidth + dockGroupCardGap
    readonly property int dockToggleWidth:
        Math.floor((contentWidth - contentItemGap) / 2)

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
        apps: "Apps", running: "Running", zhyprbola: "Zhyprbola"
    })
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
    property var componentPreviewQuick: []
    property real dragStartX: 0
    property real dragStartY: 0

    function dockRegionLabel(groupName) {
        const order = groupPreviewOrder.length > 0
            ? groupPreviewOrder : backend.dockGroupOrder
        const index = order.indexOf(groupName)
        return "Region " + (index < 0 ? 1 : index + 1)
    }

    function openableComponents() {
        return backend.dockVisibleComponents
            .concat(backend.dockHiddenComponents)
            .concat(backend.dockQuickComponents)
            .filter(key => key !== "settings"
                && key !== "input-source"
                && key !== "power"
                && key !== "components")
    }

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
        const local = groupSlotContent.mapFromItem(panel, point.x, point.y)
        const inside = local.x >= 0 && local.x < groupSlotContent.width
            && local.y >= 0 && local.y < groupSlotContent.height
        const order = backend.dockGroupOrder.slice()
        if (inside) {
            groupDropIndex = Math.max(0, Math.min(order.length - 1,
                Math.floor(local.x / panel.dockGroupStep)))
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
        componentPreviewQuick = backend.dockQuickComponents.slice()
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
        for (const zone of [showZone, hiddenZone, quickZone]) {
            const local = zone.mapFromItem(panel, point.x, point.y)
            if (local.x >= 0 && local.x < zone.width
                && local.y >= 0 && local.y < zone.height
                && (zone.zoneKey !== "quick" || draggedComponent !== "components")) {
                destination = zone
                localPoint = local
                break
            }
        }
        showZone.dropHovered = destination === showZone
        hiddenZone.dropHovered = destination === hiddenZone
        quickZone.dropHovered = destination === quickZone
        componentDropZone = destination ? destination.zoneKey : ""
        componentBeforeKey = ""

        const show = backend.dockVisibleComponents.slice()
            .filter(key => key !== draggedComponent)
        const hidden = backend.dockHiddenComponents.slice()
            .filter(key => key !== draggedComponent)
        const quick = backend.dockQuickComponents.slice()
            .filter(key => key !== draggedComponent)
        if (destination) {
            const target = destination.zoneKey === "visible" ? show
                : destination.zoneKey === "hidden" ? hidden : quick
            const row = Math.max(0, Math.floor((localPoint.y - 45 + 18.5) / 37))
            const column = Math.max(0, Math.floor((localPoint.x - 12 + 18.5) / 37))
            const position = Math.max(0, Math.min(target.length, row * 9 + column))
            componentBeforeKey = target[position] || ""
            target.splice(position, 0, draggedComponent)
        } else if (backend.dockVisibleComponents.includes(draggedComponent)) {
            show.splice(backend.dockVisibleComponents.indexOf(draggedComponent),
                0, draggedComponent)
        } else {
            const original = backend.dockHiddenComponents.includes(draggedComponent)
                ? hidden : quick
            const index = backend.dockHiddenComponents.includes(draggedComponent)
                ? backend.dockHiddenComponents.indexOf(draggedComponent)
                : backend.dockQuickComponents.indexOf(draggedComponent)
            original.splice(index, 0, draggedComponent)
        }
        if (show.join(',') !== componentPreviewShow.join(','))
            componentPreviewShow = show
        if (hidden.join(',') !== componentPreviewHidden.join(','))
            componentPreviewHidden = hidden
        if (quick.join(',') !== componentPreviewQuick.join(','))
            componentPreviewQuick = quick
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
        componentPreviewQuick = []
        showZone.dropHovered = false
        hiddenZone.dropHovered = false
        quickZone.dropHovered = false
        if (commit)
            backend.moveDockComponent(key, destination, beforeKey)
    }

    component DashedBorder: Item {
        id: border
        property color lineColor: "#CFD7DC"
        property int lineWidth: 1
        property int dash: 6
        property int gap: 5
        property int cornerRadius: 11
        opacity: 0.55

        Repeater {
            model: Math.max(0, Math.floor((border.width - border.cornerRadius * 2)
                / (border.dash + border.gap)))
            Rectangle {
                width: border.dash
                height: border.lineWidth
                radius: border.lineWidth / 2
                x: border.cornerRadius + index * (border.dash + border.gap)
                y: 0
                color: border.lineColor === undefined ? "#CFD7DC" : border.lineColor
            }
        }

        Repeater {
            model: Math.max(0, Math.floor((border.width - border.cornerRadius * 2)
                / (border.dash + border.gap)))
            Rectangle {
                width: border.dash
                height: border.lineWidth
                radius: border.lineWidth / 2
                x: border.cornerRadius + index * (border.dash + border.gap)
                y: border.height - border.lineWidth
                color: border.lineColor === undefined ? "#CFD7DC" : border.lineColor
            }
        }

        Repeater {
            model: Math.max(0, Math.floor((border.height - border.cornerRadius * 2)
                / (border.dash + border.gap)))
            Rectangle {
                width: border.lineWidth
                height: border.dash
                radius: border.lineWidth / 2
                x: 0
                y: border.cornerRadius + index * (border.dash + border.gap)
                color: border.lineColor === undefined ? "#CFD7DC" : border.lineColor
            }
        }

        Repeater {
            model: Math.max(0, Math.floor((border.height - border.cornerRadius * 2)
                / (border.dash + border.gap)))
            Rectangle {
                width: border.lineWidth
                height: border.dash
                radius: border.lineWidth / 2
                x: border.width - border.lineWidth
                y: border.cornerRadius + index * (border.dash + border.gap)
                color: border.lineColor === undefined ? "#CFD7DC" : border.lineColor
            }
        }
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
        x: panel.contentX
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
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        spacing: panel.contentItemGap
        visible: panel.section === "themes"

        Repeater {
            model: panel.themes

            delegate: Rectangle {
                required property var modelData
                width: panel.contentWidth
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
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        spacing: panel.contentSectionGap
        visible: panel.section === "dock"

        Row {
            width: panel.contentWidth
            height: panel.contentRowHeight
            spacing: panel.dockPositionGap

            Repeater {
                model: panel.positions

                delegate: Rectangle {
                    required property var modelData
                    objectName: "dock-position-" + modelData.key
                    width: panel.dockPositionWidth
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

        Rectangle {
            id: groupSlots
            width: panel.contentWidth
            height: 92
            radius: 11
            color: "transparent"

            DashedBorder {
                anchors.fill: parent
                lineColor: Theme.track
                lineWidth: 1
                dash: 7
                gap: 5
                opacity: 0.9
            }

            Item {
                id: groupSlotContent
                x: panel.dockGroupFramePadding
                y: panel.dockGroupFramePadding
                width: parent.width - panel.dockGroupFramePadding * 2
                height: parent.height - panel.dockGroupFramePadding * 2

                Rectangle {
                    width: panel.dockGroupCardWidth
                    height: 90
                    radius: 10
                    x: panel.groupPreviewOrder.indexOf(panel.draggedGroup)
                        * panel.dockGroupStep
                    visible: panel.draggingGroup && panel.groupDropIndex >= 0
                    color: Theme.selected
                }

                Repeater {
                    model: backend.dockGroupOrder

                    delegate: Rectangle {
                        id: groupCard
                        required property string modelData
                        required property int index
                        readonly property string groupName: modelData
                        readonly property bool groupActive:
                            backend.dockGroups.includes(groupName)
                        objectName: "dock-group-" + groupName
                        x: {
                            const position = panel.groupPreviewOrder.indexOf(groupName)
                            return (position < 0 ? index : position) * panel.dockGroupStep
                        }
                        width: panel.dockGroupCardWidth
                        height: 90
                        radius: 10
                        color: dragArea.containsMouse ? Theme.controlHover : Theme.control
                        opacity: panel.draggingGroup && panel.draggedGroup === groupName
                            ? 0 : 1

                        Behavior on x {
                            enabled: panel.draggingGroup
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }

                        Text {
                            x: 10
                            y: 9
                            text: panel.dockRegionLabel(groupCard.groupName)
                            color: groupCard.groupActive ? Theme.secondary : Theme.track
                            font.family: Qt.application.font.family
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 35
                            text: panel.groupLabels[groupCard.groupName]
                            color: groupCard.groupActive ? Theme.text : Theme.mutedText
                            font.family: Qt.application.font.family
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            y: 7
                            text: "⋮⋮"
                            color: groupCard.groupActive ? Theme.secondary : Theme.track
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
        }

        Grid {
            width: panel.contentWidth
            columns: 2
            columnSpacing: panel.contentItemGap
            rowSpacing: panel.contentItemGap

            Repeater {
                model: [
                    {key: "apps", label: panel.groupLabels.apps,
                        active: backend.dockGroups.includes("apps"), locked: false},
                    {key: "zhyprbola", label: panel.groupLabels.zhyprbola,
                        active: backend.dockGroups.includes("zhyprbola"), locked: true},
                    {key: "running", label: panel.groupLabels.running,
                        active: backend.dockGroups.includes("running"), locked: false},
                    {key: "ungroup-windows", label: "Ungroup Windows",
                        active: backend.dockUngroupWindows, locked: false}
                ]

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property string itemKey: modelData.key
                    readonly property bool active: modelData.active
                    objectName: itemKey === "ungroup-windows"
                        ? "dock-ungroup-windows" : "dock-group-toggle-" + itemKey

                    width: panel.dockToggleWidth
                    height: panel.contentRowHeight
                    radius: 11
                    color: active ? Theme.selected : Theme.control

                    Text {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: active ? Font.DemiBold : Font.Normal
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
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
                            enabled: !modelData.locked
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (itemKey === "ungroup-windows")
                                    backend.setDockUngroupWindows(!active)
                                else
                                    backend.setDockGroupEnabled(itemKey, !active)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            objectName: "dock-bg-opacity"
            width: panel.contentWidth
            height: 64
            radius: 11
            color: Theme.control

            Text {
                x: 16
                y: 10
                text: "BG Opacity"
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 14
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                y: 10
                text: backend.dockBgOpacity + "%"
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 13
            }

            Rectangle {
                id: opacityTrack
                x: 24
                y: 42
                width: parent.width - 48
                height: 6
                radius: 3
                color: Theme.track

                Rectangle {
                    width: parent.width * backend.dockBgOpacity / 100
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            Rectangle {
                x: opacityTrack.x - 8 + opacityTrack.width * backend.dockBgOpacity / 100
                y: opacityTrack.y - 5
                width: 16
                height: 16
                radius: 8
                color: Theme.accent
            }

            MouseArea {
                id: opacityMouse
                x: 16
                y: 32
                width: parent.width - 32
                height: 30
                cursorShape: Qt.PointingHandCursor

                function setFromPointer(pointerX) {
                    const fraction = (pointerX - (opacityTrack.x - opacityMouse.x))
                        / opacityTrack.width
                    backend.setDockBgOpacity(Math.round(
                        Math.max(0, Math.min(1, fraction)) * 100))
                }

                onPressed: function(mouse) { setFromPointer(mouse.x) }
                onPositionChanged: function(mouse) {
                    if (pressed) setFromPointer(mouse.x)
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
                : zoneKey === "hidden" ? panel.componentPreviewHidden
                : panel.componentPreviewQuick) : items
        objectName: "dock-zone-" + zoneKey

        width: panel.contentWidth
        height: 136
        radius: 12
        color: dropHovered ? Theme.selected : Theme.control
        border.width: dropHovered ? 2 : 0
        border.color: Theme.accent

        Text {
            x: 13
            y: 12
            text: zone.zoneKey === "visible" ? "Show"
                : zone.zoneKey === "hidden" ? "Hidden" : "Quick"
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
            width: parent.width - 24
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
                    color: zone.zoneKey === "visible" ? Theme.accent
                        : zone.zoneKey === "quick" ? Theme.accent : Theme.mutedText
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

    component DockComponentLauncherBox: Rectangle {
        id: launcherBox
        required property var items

        width: panel.contentWidth
        height: 116
        radius: 12
        color: Theme.control

        Text {
            x: 13
            y: 12
            text: "Open"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 13
            text: launcherBox.items.length
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Item {
            x: 12
            y: 45
            width: parent.width - 24
            height: 72

            Repeater {
                model: launcherBox.items

                delegate: Rectangle {
                    id: launcherTile
                    required property string modelData
                    required property int index
                    readonly property string componentKey: modelData
                    objectName: "dock-component-launcher-" + componentKey
                    x: (index % 9) * 37
                    y: Math.floor(index / 9) * 37
                    width: 34
                    height: 34
                    radius: 9
                    color: launcherMouse.containsMouse ? Theme.accent : Theme.mutedText

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: Qt.resolvedUrl("../gnome-extension/icons/"
                            + launcherTile.componentKey + ".svg")
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.openDockComponent(launcherTile.componentKey)
                    }
                }
            }
        }
    }

    Flickable {
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        height: panel.height - y - 12
        contentWidth: width
        contentHeight: componentColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: panel.section === "components"

        Column {
            id: componentColumn
            width: parent.width
            spacing: panel.contentSectionGap

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

            DockComponentZone {
                id: quickZone
                zoneKey: "quick"
                items: backend.dockQuickComponents
            }

            DockComponentLauncherBox {
                items: panel.openableComponents()
            }
        }
    }

    Rectangle {
        id: floatingGroup
        objectName: "dock-group-drag-overlay"
        z: 100
        width: panel.dockGroupCardWidth
        height: 90
        radius: 11
        visible: panel.draggingGroup
        color: "transparent"

        DashedBorder {
            anchors.fill: parent
            lineColor: Theme.accent
            lineWidth: 2
            dash: 8
            gap: 5
            opacity: 0.85
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 8
            color: Theme.control
        }

        Text {
            x: 10
            y: 9
            text: panel.draggedGroup ? panel.dockRegionLabel(panel.draggedGroup) : ""
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
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        spacing: panel.contentSectionGap
        visible: panel.section === "spectrum"

        Rectangle {
            width: panel.contentWidth
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
            width: panel.contentWidth
            spacing: panel.contentItemGap

            Repeater {
                model: panel.positions

                delegate: Rectangle {
                    required property var modelData
                    width: panel.contentWidth
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
        x: panel.contentX
        y: 76
        width: panel.contentWidth
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
