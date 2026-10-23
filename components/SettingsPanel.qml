import QtQuick

Item {
    id: panel

    width: 660
    implicitHeight: Math.max(510, Math.ceil(76 + keyVisualizerColumn.height + 12))
    height: implicitHeight
    property string section: "themes"
    property string edgeHandleTarget: "screenshots"
    readonly property bool editingScreenshots: edgeHandleTarget === "screenshots"
    readonly property string edgeSettingsPrefix: editingScreenshots ? "screenshot-" : "show-desktop-"
    onSectionChanged: {
        if (section === "screenshots" || section === "show-desktop") {
            edgeHandleTarget = section
            section = "edge-handles"
        }
    }
    signal closeRequested()
    readonly property int contentRowHeight: 46
    readonly property int contentItemGap: 8
    readonly property int contentSectionGap: 16
    readonly property int contentX: 184
    readonly property int contentWidth: width - contentX - 18
    readonly property int dockPositionGap: 8
    readonly property int dockPositionWidth:
        Math.floor((contentWidth - dockPositionGap * 3) / 4)
    readonly property var sections: [
        {key: "date-time", label: "Date & Time"},
        {key: "dock", label: "Dock"},
        {key: "components", label: "Dock Layout"},
        {key: "edge-handles", label: "Edge Handles"},
        {key: "keys", label: "Keys"},
        {key: "opacity", label: "Opacity"},
        {key: "spectrum", label: "Spectrum"},
        {key: "themes", label: "Themes"},
        {key: "wallpaper", label: "Wallpaper"}
    ]

    function applySettingsSectionRequest() {
        const request = backend.settingsSectionRequest || ""
        const divider = request.indexOf(":")
        if (divider < 0) return
        const requested = request.slice(divider + 1)
        if (requested === "screenshots" || requested === "show-desktop"
            || sections.some(item => item.key === requested))
            section = requested
    }

    Component.onCompleted: applySettingsSectionRequest()

    Connections {
        target: backend
        ignoreUnknownSignals: true
        function onSettingsSectionRequestChanged() {
            panel.applySettingsSectionRequest()
        }
    }
    readonly property var dateFormats: [
        "yyyy-MM-dd", "dd-MM-yyyy", "yyyy/MM/dd", "dd/MM/yyyy",
        "yyyyMMdd", "ddMMyyyy", "d MMM yyyy", "ddd, d MMM yyyy"
    ]
    readonly property var themes: [
        {key: "current", label: "Purple", accent: "#875A82"},
        {key: "white", label: "White Mist", accent: "#467B9D"},
        {key: "white-sky", label: "White Sky", accent: "#1E73E7"},
        {key: "forest", label: "Forest Calm", accent: "#477F6D"},
        {key: "one-half-gray", label: "One Half Gray", accent: "#68717D"},
        {key: "red", label: "Red", accent: "#B83252"},
        {key: "mauve", label: "Sakura", accent: "#BE345F"},
        {key: "silver-dawn", label: "Silver Dawn", accent: "#6275A6"}
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
    property string draggedComponent: ""
    property bool draggingComponent: false
    property string componentDropZone: ""
    property string componentBeforeKey: ""
    property var componentPreviewZones: ({})
    property point componentDragPoint: Qt.point(0, 0)
    property string selectedDockItem: ""
    property real dragStartX: 0
    property real dragStartY: 0
    property string draggedEdgeHandle: ""
    property bool draggingEdgeHandle: false
    property string edgeHandleDragSide: ""
    property string edgeHandleDropAlignment: ""
    property string edgeHandleBeforeKey: ""
    readonly property var edgeHandleSlots: ["1", "2", "3", "4", "5"]
    property var edgeHandlePreviews: [[], [], [], [], []]
    property real edgeHandleDragStartX: 0
    property real edgeHandleDragStartY: 0
    property string draggedOpacityComponent: ""
    property bool draggingOpacityComponent: false
    property string opacityDropZone: ""
    property string opacityBeforeKey: ""
    property var opacityPreviewEnabled: []
    property var opacityPreviewDefault: []
    property real opacityDragStartX: 0
    property real opacityDragStartY: 0

    function openableComponents() {
        return backend.dockVisibleComponents
            .concat(backend.dockHiddenComponents)
            .concat(backend.dockQuickComponents)
            .filter(key => key !== "settings"
                && key !== "workspaces"
                && key !== "apps" && key !== "running"
                && key !== "input-source"
                && key !== "power"
                && key !== "components"
                && key !== "date-display"
                && key !== "time-display"
                && key !== "key-count")
    }

    function dockItemLabel(key) {
        const labels = {apps: "Pinned apps", running: "Running apps", workspaces: "Workspaces",
            "date-display": "Date", "time-display": "Time", "key-count": "Key count",
            settings: "Settings", bluetooth: "Bluetooth", wifi: "Wi-Fi",
            "clock-weather": "Clock/weather", "system-status": "System status",
            "audio-spectrum": "Spectrum", music: "Music", sound: "Sound",
            brightness: "Brightness", battery: "Battery", todo: "Tasks", calendar: "Calendar",
            "input-source": "Language", power: "Power", components: "Quick menu",
            "key-visualizer": "Keys"}
        return labels[key] || key
    }

    function regionLabel(index) {
        const vertical = backend.dockPosition === "left" || backend.dockPosition === "right"
        return "Region " + (index + 1) + " · " + (index === 1 ? "Center"
            : index === 0 ? (vertical ? "Top" : "Left") : (vertical ? "Bottom" : "Right"))
    }

    function dockZoneItems() {
        const layout = backend.dockLayout
        return {"region-1": layout.regions[0].slice(), "region-2": layout.regions[1].slice(),
            "region-3": layout.regions[2].slice(), hidden: layout.hidden.slice(), quick: layout.quick.slice()}
    }

    function canPlaceDockItem(key, destination) {
        if (key === "settings" && (destination === "hidden" || destination === "quick")) return false
        return destination !== "quick" || !["apps", "running", "components", "workspaces",
            "date-display", "time-display", "key-count"].includes(key)
    }

    function dockItemZone(key) {
        for (let i = 0; i < 3; i++)
            if (backend.dockLayout.regions[i].includes(key)) return "region-" + (i + 1)
        return backend.dockLayout.hidden.includes(key) ? "hidden" : "quick"
    }

    function componentZones() {
        return [region1Zone, region2Zone, region3Zone, hiddenZone, quickZone]
    }

    function beginComponentDrag(key, point) {
        draggedComponent = key
        dragStartX = point.x
        dragStartY = point.y
        componentDragPoint = point
        componentPreviewZones = dockZoneItems()
    }

    function updateComponentDrag(point) {
        if (!draggedComponent) return
        componentDragPoint = point
        if (!draggingComponent) {
            const dx = point.x - dragStartX
            const dy = point.y - dragStartY
            if (dx * dx + dy * dy < 36) return
            draggingComponent = true
        }
        floatingComponent.x = point.x - floatingComponent.width / 2
        floatingComponent.y = point.y - floatingComponent.height / 2
        let destination = null
        let localPoint = null
        for (const zone of componentZones()) {
            const local = zone.mapFromItem(panel, point.x, point.y)
            if (local.x >= 0 && local.x < zone.width && local.y >= 0 && local.y < zone.height
                && canPlaceDockItem(draggedComponent, zone.zoneKey)) {
                destination = zone
                localPoint = local
            }
        }
        for (const zone of componentZones()) zone.dropHovered = zone === destination
        componentDropZone = destination ? destination.zoneKey : ""
        componentBeforeKey = ""
        const preview = dockZoneItems()
        if (destination) {
            for (const zone of Object.keys(preview)) preview[zone] = preview[zone].filter(key => key !== draggedComponent)
            const target = preview[destination.zoneKey]
            const row = Math.max(0, Math.floor((localPoint.y - 44 + 17) / 40))
            const column = Math.max(0, Math.min(2, Math.floor((localPoint.x - 12) / (destination.tileWidth + 6))))
            const position = Math.max(0, Math.min(target.length, row * 3 + column))
            componentBeforeKey = target[position] || ""
            target.splice(position, 0, draggedComponent)
        }
        componentPreviewZones = preview
    }

    function finishComponentDrag(commit) {
        const key = draggedComponent
        const destination = componentDropZone
        const before = componentBeforeKey
        const wasDragging = draggingComponent
        draggedComponent = ""
        draggingComponent = false
        componentDropZone = ""
        componentBeforeKey = ""
        componentPreviewZones = ({})
        for (const zone of componentZones()) zone.dropHovered = false
        if (commit && wasDragging && destination) backend.moveDockLayoutItem(key, destination, before)
        else if (commit && !wasDragging) selectedDockItem = key
    }

    Timer {
        interval: 40
        repeat: true
        running: panel.draggingComponent
        onTriggered: {
            const point = dockComponentsScroll.mapFromItem(panel, panel.componentDragPoint.x, panel.componentDragPoint.y)
            if (point.x < 0 || point.x > dockComponentsScroll.width) return
            const step = point.y < 30 ? -12 : point.y > dockComponentsScroll.height - 30 ? 12 : 0
            if (!step) return
            const next = Math.max(0, Math.min(dockComponentsScroll.contentHeight - dockComponentsScroll.height,
                dockComponentsScroll.contentY + step))
            if (next !== dockComponentsScroll.contentY) {
                dockComponentsScroll.contentY = next
                panel.updateComponentDrag(panel.componentDragPoint)
            }
        }
    }

    function edgeHandleLayout(side) {
        const layout = {"1": [], "2": [], "3": [], "4": [], "5": []}
        const order = backend.showDesktopEdgeSettings.order === "show-desktop-first"
            ? ["show-desktop", "screenshots"] : ["screenshots", "show-desktop"]
        for (const key of order) {
            if (key === "screenshots" && screenshots.edgeSide === side) {
                const alignment = screenshots.edgeAlignment || "3"
                layout[alignment].push(key)
            } else if (key === "show-desktop"
                && backend.showDesktopEdgeSettings.position === side) {
                const alignment = backend.showDesktopEdgeSettings.alignment || "3"
                layout[alignment].push(key)
            }
        }
        return layout
    }

    function edgeHandleItems(side, alignment) {
        if (draggedEdgeHandle && edgeHandleDragSide === side) {
            return edgeHandlePreviews[Number(alignment) - 1]
        }
        return edgeHandleLayout(side)[alignment]
    }

    function edgeHandleLabel(key) {
        return key === "screenshots" ? "Screenshots" : "Show Desktop"
    }

    function activeEdgeHandleEditor() {
        return edgeHandleEditor
    }

    function beginEdgeHandleDrag(key, side, point) {
        draggedEdgeHandle = key
        edgeHandleDragSide = side
        edgeHandleDragStartX = point.x
        edgeHandleDragStartY = point.y
        const layout = edgeHandleLayout(side)
        edgeHandlePreviews = edgeHandleSlots.map(slot => layout[slot].slice())
    }

    function updateEdgeHandleDrag(point) {
        if (!draggedEdgeHandle)
            return
        if (!draggingEdgeHandle) {
            const dx = point.x - edgeHandleDragStartX
            const dy = point.y - edgeHandleDragStartY
            if (dx * dx + dy * dy < 36)
                return
            draggingEdgeHandle = true
        }

        floatingEdgeHandle.x = point.x - floatingEdgeHandle.width / 2
        floatingEdgeHandle.y = point.y - floatingEdgeHandle.height / 2
        const editor = activeEdgeHandleEditor()
        const destination = editor.zoneAt(point)
        editor.setDropAlignment(destination ? destination.slotKey : "")
        edgeHandleDropAlignment = destination ? destination.slotKey : ""
        edgeHandleBeforeKey = ""

        const layout = edgeHandleLayout(edgeHandleDragSide)
        for (const alignment of edgeHandleSlots)
            layout[alignment] = layout[alignment].filter(key => key !== draggedEdgeHandle)
        if (destination) {
            const target = layout[destination.slotKey]
            const local = destination.mapFromItem(panel, point.x, point.y)
            const position = local.x < destination.width / 2 ? 0 : target.length
            edgeHandleBeforeKey = target[position] || ""
            target.splice(position, 0, draggedEdgeHandle)
        }
        edgeHandlePreviews = edgeHandleSlots.map(slot => layout[slot].slice())
    }

    function finishEdgeHandleDrag() {
        const key = draggedEdgeHandle
        const alignment = edgeHandleDropAlignment
        const beforeKey = edgeHandleBeforeKey
        const commit = draggingEdgeHandle && alignment !== ""
        const editor = activeEdgeHandleEditor()
        draggedEdgeHandle = ""
        draggingEdgeHandle = false
        edgeHandleDragSide = ""
        edgeHandleDropAlignment = ""
        edgeHandleBeforeKey = ""
        edgeHandlePreviews = [[], [], [], [], []]
        editor.setDropAlignment("")
        if (commit) {
            backend.moveEdgeHandle(key, alignment, beforeKey)
            if (key === "screenshots")
                screenshots.refresh()
        }
    }

    function beginOpacityDrag(key, point) {
        draggedOpacityComponent = key
        opacityDragStartX = point.x
        opacityDragStartY = point.y
        opacityPreviewEnabled = backend.opacityEnabledComponents.slice()
        opacityPreviewDefault = backend.opacityDisabledComponents.slice()
    }

    function updateOpacityDrag(point) {
        if (!draggedOpacityComponent)
            return
        if (!draggingOpacityComponent) {
            const dx = point.x - opacityDragStartX
            const dy = point.y - opacityDragStartY
            if (dx * dx + dy * dy < 36)
                return
            draggingOpacityComponent = true
        }

        floatingOpacityComponent.x = point.x - floatingOpacityComponent.width / 2
        floatingOpacityComponent.y = point.y - floatingOpacityComponent.height / 2
        let destination = null
        let localPoint = null
        for (const zone of [opacityEnabledZone, opacityDefaultZone]) {
            const local = zone.mapFromItem(panel, point.x, point.y)
            if (local.x >= 0 && local.x < zone.width
                && local.y >= 0 && local.y < zone.height) {
                destination = zone
                localPoint = local
                break
            }
        }
        opacityEnabledZone.dropHovered = destination === opacityEnabledZone
        opacityDefaultZone.dropHovered = destination === opacityDefaultZone
        opacityDropZone = destination ? destination.zoneKey : ""
        opacityBeforeKey = ""

        const enabled = backend.opacityEnabledComponents.slice()
            .filter(key => key !== draggedOpacityComponent)
        const defaults = backend.opacityDisabledComponents.slice()
            .filter(key => key !== draggedOpacityComponent)
        if (destination) {
            const target = destination.zoneKey === "opacity" ? enabled : defaults
            const row = Math.max(0, Math.floor((localPoint.y - 45 + 18.5) / 37))
            const column = Math.max(0, Math.floor((localPoint.x - 12 + 18.5) / 37))
            const position = Math.max(0, Math.min(target.length, row * 9 + column))
            opacityBeforeKey = target[position] || ""
            target.splice(position, 0, draggedOpacityComponent)
        } else if (backend.opacityEnabledComponents.includes(draggedOpacityComponent)) {
            enabled.splice(backend.opacityEnabledComponents.indexOf(draggedOpacityComponent),
                0, draggedOpacityComponent)
        } else {
            defaults.splice(backend.opacityDisabledComponents.indexOf(draggedOpacityComponent),
                0, draggedOpacityComponent)
        }
        if (enabled.join(',') !== opacityPreviewEnabled.join(','))
            opacityPreviewEnabled = enabled
        if (defaults.join(',') !== opacityPreviewDefault.join(','))
            opacityPreviewDefault = defaults
    }

    function finishOpacityDrag() {
        const key = draggedOpacityComponent
        const destination = opacityDropZone
        const beforeKey = opacityBeforeKey
        const commit = draggingOpacityComponent && destination !== ""
        draggedOpacityComponent = ""
        draggingOpacityComponent = false
        opacityDropZone = ""
        opacityBeforeKey = ""
        opacityPreviewEnabled = []
        opacityPreviewDefault = []
        opacityEnabledZone.dropHovered = false
        opacityDefaultZone.dropHovered = false
        if (commit)
            backend.moveOpacityComponent(key, destination, beforeKey)
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
        objectName: "settings-surface"
        anchors.fill: parent
        radius: 22
        color: Theme.componentSurfaceFor("settings")
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
            spacing: 2

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
        text: panel.section === "edge-handles" ? "Edge Handles"
            : panel.section === "themes" ? "Themes"
            : panel.section === "opacity" ? "Opacity"
            : (panel.section === "dock" ? "Dock"
            : (panel.section === "components" ? "Dock layout"
            : (panel.section === "spectrum" ? "Edge spectrum"
            : (panel.section === "keys" ? "Key visualizer"
            : (panel.section === "date-time" ? "Date & Time" : "Wallpaper")))))
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

    Grid {
        id: themeGrid
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        columns: 2
        spacing: panel.contentItemGap
        visible: panel.section === "themes"

        Repeater {
            model: panel.themes

            delegate: Rectangle {
                required property var modelData
                width: (themeGrid.width - themeGrid.spacing) / themeGrid.columns
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
                    width: parent.width - x - 36
                    elide: Text.ElideRight
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

    Flickable {
        objectName: "edge-handles-settings-scroll"
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        height: panel.height - y - 12
        contentWidth: width
        contentHeight: edgeSettingsColumn.height
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickableDirection: Flickable.VerticalFlick
        visible: panel.section === "edge-handles"

        Column {
            id: edgeSettingsColumn
            width: parent.width
            spacing: 17

            EdgeSettingGroup {
                title: "Handle"
                objectPrefix: "edge-handle-target-"
                options: [{key: "screenshots", label: "Screenshots"},
                    {key: "show-desktop", label: "Show Desktop"}]
                selectedKey: panel.edgeHandleTarget
                onOptionClicked: function(key) {
                    panel.edgeHandleTarget = key
                }
            }

            EdgeSettingGroup {
                title: "Screen edge"
                objectPrefix: panel.edgeSettingsPrefix + "position-"
                options: panel.positions
                selectedKey: panel.editingScreenshots ? screenshots.edgeSide
                    : backend.showDesktopEdgeSettings.position
                onOptionClicked: function(key) {
                    if (panel.editingScreenshots)
                        screenshots.setPosition(key, screenshots.edgeAlignment)
                    else
                        backend.setShowDesktopEdgeSetting("position", key)
                }
            }

            EdgeSettingGroup {
                title: "Width"
                objectPrefix: panel.edgeSettingsPrefix + "width-"
                options: [{key: "sm", label: "sm"}, {key: "md", label: "md"},
                    {key: "lg", label: "lg"}]
                selectedKey: panel.editingScreenshots ? screenshots.edgeWidth
                    : backend.showDesktopEdgeSettings.width
                onOptionClicked: function(key) {
                    if (panel.editingScreenshots)
                        screenshots.setEdgeSize("width", key)
                    else
                        backend.setShowDesktopEdgeSetting("width", key)
                }
            }

            EdgeSettingGroup {
                title: "Height"
                objectPrefix: panel.edgeSettingsPrefix + "height-"
                options: [{key: "sm", label: "sm"}, {key: "md", label: "md"},
                    {key: "lg", label: "lg"}]
                selectedKey: panel.editingScreenshots ? screenshots.edgeHeight
                    : backend.showDesktopEdgeSettings.height
                onOptionClicked: function(key) {
                    if (panel.editingScreenshots)
                        screenshots.setEdgeSize("height", key)
                    else
                        backend.setShowDesktopEdgeSetting("height", key)
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "Position and order"
                    color: Theme.mutedText
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                }

                EdgeHandleLayoutEditor {
                    id: edgeHandleEditor
                    editorKey: panel.edgeHandleTarget
                    editorSide: panel.editingScreenshots ? screenshots.edgeSide
                        : backend.showDesktopEdgeSettings.position
                }
            }
        }
    }

    component EdgeSettingGroup: Column {
        id: edgeGroup
        required property string title
        required property string objectPrefix
        required property var options
        required property string selectedKey
        signal optionClicked(string key)
        width: panel.contentWidth
        spacing: 6

        Text {
            text: edgeGroup.title
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Row {
            width: parent.width
            spacing: 8

            Repeater {
                model: edgeGroup.options

                delegate: Rectangle {
                    id: edgeOption
                    required property var modelData
                    readonly property bool chosen:
                        edgeGroup.selectedKey === modelData.key
                    objectName: edgeGroup.objectPrefix + modelData.key
                    width: (panel.contentWidth
                        - 8 * (edgeGroup.options.length - 1)) / edgeGroup.options.length
                    height: 42
                    radius: 8
                    color: chosen ? Theme.selected
                        : (edgeOptionMouse.containsMouse
                            ? Theme.controlHover : Theme.control)

                    Text {
                        anchors.centerIn: parent
                        text: edgeOption.modelData.label
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: edgeOption.chosen
                            ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        visible: edgeOption.chosen
                        text: "✓"
                        color: Theme.accent
                        font.family: Qt.application.font.family
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: edgeOptionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: edgeGroup.optionClicked(edgeOption.modelData.key)
                    }
                }
            }
        }
    }

    component EdgeHandleLayoutEditor: Column {
        id: edgeEditor
        required property string editorKey
        required property string editorSide
        width: panel.contentWidth
        spacing: 8

        function zoneAt(point) {
            for (let index = 0; index < edgeZoneRepeater.count; ++index) {
                const zone = edgeZoneRepeater.itemAt(index)
                const local = zone.mapFromItem(panel, point.x, point.y)
                if (local.x >= 0 && local.x < zone.width
                    && local.y >= 0 && local.y < zone.height)
                    return zone
            }
            return null
        }

        function setDropAlignment(alignment) {
            for (let index = 0; index < edgeZoneRepeater.count; ++index) {
                const zone = edgeZoneRepeater.itemAt(index)
                zone.dropHovered = zone.slotKey === alignment
            }
        }

        Repeater {
            id: edgeZoneRepeater
            model: panel.edgeHandleSlots

            delegate: EdgeHandleZone {
                required property string modelData
                editorKey: edgeEditor.editorKey
                editorSide: edgeEditor.editorSide
                slotKey: modelData
                label: modelData
                items: panel.edgeHandleLayout(edgeEditor.editorSide)[modelData]
            }
        }
    }

    component EdgeHandleZone: Rectangle {
        id: edgeZone
        required property string editorKey
        required property string editorSide
        required property string slotKey
        required property string label
        required property var items
        property bool dropHovered: false
        readonly property var displayOrder:
            panel.edgeHandleItems(editorSide, slotKey)
        readonly property real cardWidth: (width - 32) / 2
        objectName: "edge-handle-zone-" + editorKey + "-" + editorSide + "-" + slotKey

        width: panel.contentWidth
        height: 72
        radius: 12
        color: dropHovered ? Theme.selected : Theme.control
        border.width: dropHovered ? 2 : 0
        border.color: Theme.accent

        Text {
            x: 12
            y: 7
            text: edgeZone.label
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 7
            text: edgeZone.items.length
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 11
        }

        Rectangle {
            x: 12 + Math.max(0, edgeZone.displayOrder.indexOf(
                panel.draggedEdgeHandle)) * (edgeZone.cardWidth + 8)
            y: 30
            width: edgeZone.cardWidth
            height: 32
            radius: 9
            visible: panel.draggingEdgeHandle
                && edgeZone.displayOrder.includes(panel.draggedEdgeHandle)
            color: Theme.selected
            border.width: 2
            border.color: Theme.accent
        }

        Repeater {
            model: edgeZone.items

            delegate: Rectangle {
                id: edgeHandleCard
                required property string modelData
                required property int index
                readonly property string handleKey: modelData
                readonly property int previewIndex:
                    edgeZone.displayOrder.indexOf(handleKey)
                objectName: "edge-handle-card-" + edgeZone.editorKey + "-"
                    + edgeZone.editorSide + "-" + edgeZone.slotKey + "-" + handleKey
                x: 12 + (previewIndex < 0 ? index : previewIndex)
                    * (edgeZone.cardWidth + 8)
                y: 30
                width: edgeZone.cardWidth
                height: 32
                radius: 9
                color: edgeCardMouse.containsMouse ? Theme.controlHover : Theme.accent
                opacity: panel.draggingEdgeHandle
                    && panel.draggedEdgeHandle === handleKey ? 0 : 1

                Behavior on x {
                    enabled: panel.draggingEdgeHandle
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    text: panel.edgeHandleLabel(edgeHandleCard.handleKey)
                    color: edgeCardMouse.containsMouse
                        ? Theme.text : Theme.accentText
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⋮⋮"
                    color: edgeCardMouse.containsMouse
                        ? Theme.text : Theme.accentText
                    font.family: Qt.application.font.family
                    font.pixelSize: 12
                }

                MouseArea {
                    id: edgeCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: panel.draggingEdgeHandle
                        ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: function(mouse) {
                        panel.beginEdgeHandleDrag(edgeHandleCard.handleKey,
                            edgeZone.editorSide,
                            edgeCardMouse.mapToItem(panel, mouse.x, mouse.y))
                    }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            panel.updateEdgeHandleDrag(
                                edgeCardMouse.mapToItem(panel, mouse.x, mouse.y))
                    }
                    onReleased: panel.finishEdgeHandleDrag()
                    onCanceled: panel.finishEdgeHandleDrag()
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
            objectName: "open-dock-layout"
            width: panel.contentWidth
            height: panel.contentRowHeight
            radius: 11
            color: layoutLinkMouse.containsMouse ? Theme.controlHover : Theme.control
            Text {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: "Arrange dock items   →"
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 14
            }
            MouseArea {
                id: layoutLinkMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.section = "components"
            }
        }
        DateTimeToggle {
            objectName: "dock-ungroup-windows"
            title: "Ungroup windows"
            active: backend.dockUngroupWindows
            onToggled: backend.setDockUngroupWindows(!active)
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
                text: "Dock Background Opacity"
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

    component ComponentOpacityBox: Rectangle {
        id: componentOpacityBox
        objectName: "component-opacity-box"
        width: panel.contentWidth
        height: 72
        radius: 12
        color: Qt.alpha(Theme.control, Theme.componentOpacity)

        Text {
            x: 14
            y: 10
            text: "Component Background Opacity"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 11
            text: backend.componentOpacity + "%"
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 13
        }

        Rectangle {
            id: componentOpacityTrack
            objectName: "component-opacity-track"
            x: 22
            y: 48
            width: parent.width - 44
            height: 6
            radius: 3
            color: Theme.track

            Rectangle {
                width: parent.width * backend.componentOpacity / 100
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        Rectangle {
            objectName: "component-opacity-handle"
            x: componentOpacityTrack.x - 8
                + componentOpacityTrack.width * backend.componentOpacity / 100
            y: componentOpacityTrack.y - 5
            width: 16
            height: 16
            radius: 8
            color: Theme.accent
        }

        MouseArea {
            id: componentOpacityMouse
            objectName: "component-opacity-range"
            x: 14
            y: 36
            width: parent.width - 28
            height: 34
            cursorShape: Qt.PointingHandCursor

            function setFromPointer(pointerX) {
                const fraction = (pointerX
                    - (componentOpacityTrack.x - componentOpacityMouse.x))
                    / componentOpacityTrack.width
                backend.setComponentOpacity(Math.round(
                    Math.max(0, Math.min(1, fraction)) * 100))
            }

            onPressed: function(mouse) { setFromPointer(mouse.x) }
            onPositionChanged: function(mouse) {
                if (pressed) setFromPointer(mouse.x)
            }
        }
    }

    component OpacitySupportZone: Rectangle {
        id: supportZone
        required property string label
        required property var items
        required property bool supportsOpacity
        required property string zoneKey
        property bool dropHovered: false
        readonly property int rowCount: Math.max(1, Math.ceil(items.length / 9))
        readonly property var displayOrder: panel.draggingOpacityComponent
            ? (supportsOpacity ? panel.opacityPreviewEnabled
                : panel.opacityPreviewDefault) : items
        objectName: supportsOpacity ? "opacity-supported-zone" : "opacity-opaque-zone"

        width: panel.contentWidth
        height: Math.max(136, 55 + rowCount * 37)
        radius: 12
        color: dropHovered ? Theme.selected : supportsOpacity
            ? Qt.alpha(Theme.control, Theme.componentOpacity) : Theme.control
        border.width: dropHovered ? 2 : 0
        border.color: Theme.accent

        Text {
            x: 13
            y: 12
            text: supportZone.label
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 13
            text: supportZone.items.length
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Item {
            id: opacityComponentRow
            x: 12
            y: 45
            width: parent.width - 24
            height: parent.height - y

            Rectangle {
                width: 34
                height: 34
                radius: 9
                x: (supportZone.displayOrder.indexOf(panel.draggedOpacityComponent) % 9) * 37
                y: Math.floor(supportZone.displayOrder.indexOf(
                    panel.draggedOpacityComponent) / 9) * 37
                visible: panel.draggingOpacityComponent
                    && supportZone.displayOrder.includes(panel.draggedOpacityComponent)
                color: Theme.selected
                border.width: 2
                border.color: Theme.accent
            }

            Repeater {
                objectName: supportZone.supportsOpacity
                    ? "opacity-supported-repeater" : "opacity-opaque-repeater"
                model: supportZone.items

                delegate: Rectangle {
                    id: opacityTile
                    required property string modelData
                    required property int index
                    readonly property string componentKey: modelData
                    objectName: "opacity-" + (supportZone.supportsOpacity
                        ? "supported-" : "opaque-") + componentKey
                    x: {
                        const position = supportZone.displayOrder.indexOf(componentKey)
                        return ((position < 0 ? index : position) % 9) * 37
                    }
                    y: {
                        const position = supportZone.displayOrder.indexOf(componentKey)
                        return Math.floor((position < 0 ? index : position) / 9) * 37
                    }
                    width: 34
                    height: 34
                    radius: 9
                    color: supportZone.supportsOpacity ? Theme.accent : Theme.mutedText
                    opacity: panel.draggingOpacityComponent
                        && panel.draggedOpacityComponent === componentKey ? 0 : 1

                    Behavior on x {
                        enabled: panel.draggingOpacityComponent
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: panel.draggingOpacityComponent
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: Qt.resolvedUrl("../gnome-extension/icons/"
                            + opacityTile.componentKey + ".svg")
                        asynchronous: true
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: opacityDragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: panel.draggingOpacityComponent
                            ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: function(mouse) {
                            panel.beginOpacityDrag(opacityTile.componentKey,
                                opacityDragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                panel.updateOpacityDrag(
                                    opacityDragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onReleased: panel.finishOpacityDrag()
                        onCanceled: panel.finishOpacityDrag()
                    }
                }
            }
        }
    }

    component DockComponentZone: Rectangle {
        id: zone
        required property string zoneKey
        required property string label
        required property var items
        property bool dropHovered: false
        readonly property var displayOrder: panel.draggingComponent
            ? (panel.componentPreviewZones[zoneKey] || []) : items
        readonly property int columns: 3
        readonly property real tileWidth: (width - 24 - 12) / columns
        readonly property int rowCount: Math.max(1, Math.ceil(displayOrder.length / columns))
        objectName: "dock-zone-" + zoneKey
        width: panel.contentWidth
        height: 50 + rowCount * 40
        radius: 12
        color: dropHovered ? Theme.selected : Theme.control
        border.width: dropHovered ? 2 : 0
        border.color: Theme.accent

        Text {
            x: 12; y: 12
            text: zone.label
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 13
            text: zone.items.length
            color: Theme.mutedText
            font.pixelSize: 12
        }
        Text {
            x: 12; y: 52
            visible: zone.displayOrder.length === 0
            text: zone.zoneKey === "quick" ? "Quick menu items" : "Drop items here"
            color: Theme.mutedText
            font.pixelSize: 11
        }
        Item {
            x: 12; y: 44
            width: parent.width - 24
            height: zone.rowCount * 40
            Rectangle {
                width: zone.tileWidth; height: 34; radius: 7
                x: (zone.displayOrder.indexOf(panel.draggedComponent) % zone.columns) * (zone.tileWidth + 6)
                y: Math.floor(zone.displayOrder.indexOf(panel.draggedComponent) / zone.columns) * 40
                visible: panel.draggingComponent && zone.displayOrder.includes(panel.draggedComponent)
                color: Theme.selected
                border.width: 1; border.color: Theme.accent
            }
            Repeater {
                model: zone.items
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property string componentKey: modelData
                    readonly property int previewIndex: Math.max(0, zone.displayOrder.indexOf(componentKey))
                    objectName: "dock-component-" + zone.zoneKey + "-" + componentKey
                    x: (previewIndex % zone.columns) * (zone.tileWidth + 6)
                    y: Math.floor(previewIndex / zone.columns) * 40
                    width: zone.tileWidth; height: 34; radius: 7
                    color: dragArea.containsMouse ? Theme.controlHover : Theme.cardSurface
                    border.width: 1
                    border.color: dragArea.containsMouse ? Theme.accent : "transparent"
                    opacity: panel.draggingComponent && panel.draggedComponent === componentKey ? 0 : 1
                    Behavior on x { enabled: panel.draggingComponent; NumberAnimation { duration: 120 } }
                    Behavior on y { enabled: panel.draggingComponent; NumberAnimation { duration: 120 } }
                    Rectangle {
                        x: 5; anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 5; color: Theme.accent
                        Image {
                            anchors.centerIn: parent
                            width: 17; height: 17
                            source: Qt.resolvedUrl("../gnome-extension/icons/" + tile.componentKey + ".svg")
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                    Text {
                        x: 35; width: parent.width - 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.dockItemLabel(tile.componentKey)
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: panel.draggingComponent ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: function(mouse) {
                            panel.beginComponentDrag(tile.componentKey, dragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) panel.updateComponentDrag(dragArea.mapToItem(panel, mouse.x, mouse.y))
                        }
                        onReleased: panel.finishComponentDrag(true)
                        onCanceled: panel.finishComponentDrag(false)
                    }
                }
            }
        }
    }

    component DockComponentLauncherBox: Rectangle {
        id: launcherBox
        required property var items
        readonly property int rowCount: Math.max(1, Math.ceil(items.length / 9))
        objectName: "dock-component-launcher-box"

        width: panel.contentWidth
        height: Math.max(136, 55 + rowCount * 37)
        radius: 12
        color: Theme.control

        Text {
            x: 13
            y: 12
            text: "Click for open"
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
            height: parent.height - y

            Repeater {
                objectName: "dock-component-launcher-repeater"
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
                        asynchronous: true
                        sourceSize: Qt.size(width, height)
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
        id: dockComponentsScroll
        objectName: "dock-components-scroll"
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        height: panel.height - y - 12
        contentWidth: width
        contentHeight: componentColumn.height
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickableDirection: Flickable.VerticalFlick
        visible: panel.section === "components"

        Rectangle {
            parent: dockComponentsScroll
            anchors.right: parent.right
            width: 3
            height: Math.max(28, parent.height * parent.height / Math.max(1, dockComponentsScroll.contentHeight))
            y: Math.max(0, Math.min(parent.height - height,
                dockComponentsScroll.contentY / Math.max(1, dockComponentsScroll.contentHeight - parent.height)
                    * (parent.height - height)))
            visible: dockComponentsScroll.contentHeight > dockComponentsScroll.height
            z: 2
            radius: 2
            color: Theme.track
        }

        rebound: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: componentColumn
            width: parent.width
            spacing: panel.contentSectionGap
            // Cache the full column, including cards below the viewport,
            // so the first rebound can move an already prepared texture.
            layer.enabled: true
            layer.smooth: true

            DockComponentZone {
                id: region1Zone; zoneKey: "region-1"; label: panel.regionLabel(0)
                items: backend.dockLayout.regions[0]
            }
            DockComponentZone {
                id: region2Zone; zoneKey: "region-2"; label: panel.regionLabel(1)
                items: backend.dockLayout.regions[1]
            }
            DockComponentZone {
                id: region3Zone; zoneKey: "region-3"; label: panel.regionLabel(2)
                items: backend.dockLayout.regions[2]
            }
            DockComponentZone {
                id: hiddenZone; zoneKey: "hidden"; label: "Hidden"
                items: backend.dockLayout.hidden
            }
            DockComponentZone {
                id: quickZone; zoneKey: "quick"; label: "Quick menu"
                items: backend.dockLayout.quick
            }

            DockComponentLauncherBox {
                items: panel.openableComponents()
            }
        }
    }

    Column {
        objectName: "opacity-settings"
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        spacing: panel.contentSectionGap
        visible: panel.section === "opacity"

        ComponentOpacityBox { }

        OpacitySupportZone {
            id: opacityEnabledZone
            label: "Opacity"
            items: backend.opacityEnabledComponents
            supportsOpacity: true
            zoneKey: "opacity"
        }

        OpacitySupportZone {
            id: opacityDefaultZone
            label: "Default"
            items: backend.opacityDisabledComponents
            supportsOpacity: false
            zoneKey: "default"
        }
    }

    Item {
        id: moveDockItemPopup
        objectName: "move-dock-item-popup"
        anchors.fill: parent
        z: 120
        visible: panel.selectedDockItem !== ""
        focus: visible
        onVisibleChanged: if (visible) forceActiveFocus()
        Keys.onEscapePressed: panel.selectedDockItem = ""
        Rectangle { anchors.fill: parent; color: "#33000000" }
        MouseArea { anchors.fill: parent; onClicked: panel.selectedDockItem = "" }
        Rectangle {
            x: panel.contentX
            y: 76
            width: panel.contentWidth
            height: moveDockChoices.height + 28
            radius: 12
            color: Theme.cardSurface
            border.width: 1
            border.color: Theme.track
            Column {
                id: moveDockChoices
                x: 14; y: 14
                width: parent.width - 28
                spacing: 8
                Text {
                    width: parent.width
                    height: 32
                    text: "Move " + panel.dockItemLabel(panel.selectedDockItem) + " to"
                    color: Theme.text
                    font.family: Qt.application.font.family
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: ["region-1", "region-2", "region-3", "hidden", "quick"]
                        .filter(zone => panel.canPlaceDockItem(panel.selectedDockItem, zone))
                    delegate: Rectangle {
                        id: moveChoice
                        required property string modelData
                        readonly property bool current: panel.selectedDockItem !== ""
                            && panel.dockItemZone(panel.selectedDockItem) === modelData
                        objectName: "move-dock-item-" + modelData
                        width: moveDockChoices.width
                        height: 40
                        radius: 8
                        color: current ? Theme.selected
                            : moveChoiceMouse.containsMouse ? Theme.controlHover : Theme.control
                        Text {
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            text: (moveChoice.modelData.startsWith("region-")
                                ? panel.regionLabel(Number(moveChoice.modelData.slice(7)) - 1)
                                : moveChoice.modelData === "hidden" ? "Hidden" : "Quick menu")
                                + (moveChoice.current ? "   ✓" : "")
                            color: Theme.text
                            font.family: Qt.application.font.family
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: moveChoiceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!moveChoice.current)
                                    backend.moveDockLayoutItem(panel.selectedDockItem, moveChoice.modelData, "")
                                panel.selectedDockItem = ""
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: floatingComponent
        objectName: "dock-component-drag-overlay"
        z: 100
        width: (panel.contentWidth - 36) / 3
        height: 34
        radius: 9
        visible: panel.draggingComponent
        color: Theme.accent

        Image {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            source: panel.draggedComponent
                ? Qt.resolvedUrl("../gnome-extension/icons/"
                    + panel.draggedComponent + ".svg") : ""
            fillMode: Image.PreserveAspectFit
        }
        Text {
            x: 34
            width: parent.width - 39
            anchors.verticalCenter: parent.verticalCenter
            text: panel.dockItemLabel(panel.draggedComponent)
            color: Theme.accentText
            font.family: Qt.application.font.family
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: floatingEdgeHandle
        objectName: "edge-handle-drag-overlay"
        z: 100
        width: (panel.contentWidth - 32) / 2
        height: 32
        radius: 9
        visible: panel.draggingEdgeHandle
        color: Theme.accent

        Text {
            anchors.centerIn: parent
            text: panel.edgeHandleLabel(panel.draggedEdgeHandle)
            color: Theme.accentText
            font.family: Qt.application.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "⋮⋮"
            color: Theme.accentText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: floatingOpacityComponent
        objectName: "opacity-component-drag-overlay"
        z: 100
        width: 34
        height: 34
        radius: 9
        visible: panel.draggingOpacityComponent
        color: Theme.accent

        Image {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: panel.draggedOpacityComponent
                ? Qt.resolvedUrl("../gnome-extension/icons/"
                    + panel.draggedOpacityComponent + ".svg") : ""
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
            spacing: 6

            Text {
                text: "Bar length"
                color: Theme.mutedText
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: ["sm", "md", "lg"]

                    delegate: Rectangle {
                        id: spectrumSizeChoice
                        required property string modelData
                        width: (panel.contentWidth - 16) / 3
                        height: 42
                        radius: 8
                        color: backend.edgeSpectrumSize === spectrumSizeChoice.modelData
                            ? Theme.selected : (spectrumSizeMouse.containsMouse
                                ? Theme.controlHover : Theme.control)

                        Text {
                            anchors.centerIn: parent
                            text: spectrumSizeChoice.modelData
                            color: Theme.text
                            font.family: Qt.application.font.family
                            font.pixelSize: 14
                        }

                        Text {
                            objectName: "spectrum-size-check-" + spectrumSizeChoice.modelData
                            anchors.right: parent.right
                            anchors.rightMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            visible: backend.edgeSpectrumSize === spectrumSizeChoice.modelData
                            text: "✓"
                            color: Theme.accent
                            font.family: Qt.application.font.family
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: spectrumSizeMouse
                            objectName: "spectrum-size-" + spectrumSizeChoice.modelData
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.setEdgeSpectrumSize(spectrumSizeChoice.modelData)
                        }
                    }
                }
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

    component KeyChoice: Column {
        required property string title
        required property string settingKey
        required property var options
        width: panel.contentWidth
        spacing: 6

        Text {
            text: title
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Row {
            width: parent.width
            spacing: 8

            Repeater {
                model: options

                delegate: Rectangle {
                    required property var modelData
                    width: (panel.contentWidth - 8 * (options.length - 1)) / options.length
                    height: 42
                    radius: 8
                    color: backend.keyVisualizerSettings[settingKey] === modelData.key
                        ? Theme.selected : (optionMouse.containsMouse
                            ? Theme.controlHover : Theme.control)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: backend.keyVisualizerSettings[settingKey]
                            === modelData.key ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        objectName: "key-choice-check-" + settingKey + "-" + modelData.key
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        visible: backend.keyVisualizerSettings[settingKey] === modelData.key
                        text: "✓"
                        color: Theme.accent
                        font.family: Qt.application.font.family
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setKeyVisualizerSetting(settingKey, modelData.key)
                    }
                }
            }
        }
    }

    component DateTimeToggle: Rectangle {
        id: dateTimeToggle
        required property string title
        required property bool active
        signal toggled()
        width: panel.contentWidth
        height: panel.contentRowHeight
        radius: 11
        color: active ? Theme.selected : Theme.control

        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: dateTimeToggle.title
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 14
            font.weight: dateTimeToggle.active ? Font.DemiBold : Font.Normal
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 26
            radius: 13
            color: dateTimeToggle.active ? Theme.accent : Theme.track

            Rectangle {
                x: dateTimeToggle.active ? 21 : 3
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
            onClicked: dateTimeToggle.toggled()
        }
    }

    component WidthStepper: Rectangle {
        id: stepper
        required property string label
        required property string settingKey
        width: (panel.contentWidth - 8) / 2
        height: 52
        radius: 8
        color: Theme.control

        Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: stepper.label
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 13
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: [-20, 20]

                delegate: Rectangle {
                    required property int modelData
                    width: 26
                    height: 26
                    radius: 6
                    color: stepMouse.containsMouse ? Theme.controlHover : Theme.selected

                    Text {
                        anchors.centerIn: parent
                        text: modelData < 0 ? "−" : "+"
                        color: Theme.text
                        font.pixelSize: 17
                    }

                    MouseArea {
                        id: stepMouse
                        objectName: "key-width-" + stepper.settingKey
                            + (modelData < 0 ? "-decrease" : "-increase")
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property int heldMs: 0

                        function step() {
                            const settings = backend.keyVisualizerSettings
                            const value = settings[stepper.settingKey] + modelData
                            const limit = stepper.settingKey === "minWidth"
                                ? Math.min(settings.maxWidth, Math.max(120, value))
                                : Math.max(settings.minWidth, Math.min(1000, value))
                            backend.setKeyVisualizerSetting(stepper.settingKey, limit)
                        }

                        onPressed: {
                            step()
                            heldMs = 0
                            repeatTimer.interval = 400
                            repeatTimer.restart()
                        }
                        onReleased: repeatTimer.stop()
                        onCanceled: repeatTimer.stop()
                        onExited: repeatTimer.stop()
                        onVisibleChanged: if (!visible) repeatTimer.stop()
                        onEnabledChanged: if (!enabled) repeatTimer.stop()

                        Timer {
                            id: repeatTimer
                            repeat: true
                            onTriggered: {
                                if (!stepMouse.pressed || !stepMouse.containsMouse
                                        || !stepMouse.visible || !stepMouse.enabled) {
                                    stop()
                                    return
                                }
                                stepMouse.heldMs += interval
                                stepMouse.step()
                                // Accelerate from ~8 to 25 steps/s as the hold continues.
                                interval = Math.max(40,
                                    140 - Math.floor(stepMouse.heldMs / 400) * 20)
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 73
            anchors.verticalCenter: parent.verticalCenter
            text: backend.keyVisualizerSettings[stepper.settingKey]
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 13
        }
    }

    Flickable {
        objectName: "key-visualizer-scroll"
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        height: panel.height - y - 12
        contentWidth: width
        contentHeight: keyVisualizerColumn.height
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickableDirection: Flickable.VerticalFlick
        visible: panel.section === "keys"

        Column {
            id: keyVisualizerColumn
            width: parent.width
            spacing: 17

            KeyChoice {
                title: "Font size"
                settingKey: "fontSize"
                options: [{key: "sm", label: "sm"}, {key: "md", label: "md"},
                    {key: "lg", label: "lg"}]
            }

            KeyChoice {
                title: "Padding X"
                settingKey: "paddingX"
                options: [{key: "sm", label: "sm"}, {key: "md", label: "md"},
                    {key: "lg", label: "lg"}]
            }

            KeyChoice {
                title: "Padding Y"
                settingKey: "paddingY"
                options: [{key: "sm", label: "sm"}, {key: "md", label: "md"},
                    {key: "lg", label: "lg"}]
            }

            KeyChoice {
                title: "Width"
                settingKey: "widthMode"
                options: [{key: "fit", label: "Fit content"},
                    {key: "fixed", label: "Fixed max"}]
            }

            Row {
                spacing: 8
                WidthStepper { label: "Min"; settingKey: "minWidth" }
                WidthStepper { label: "Max"; settingKey: "maxWidth" }
            }

            KeyChoice {
                title: "Text alignment"
                settingKey: "alignment"
                options: [{key: "left", label: "Left"},
                    {key: "center", label: "Center"},
                    {key: "right", label: "Right"}]
            }

            Rectangle {
                objectName: "open-key-visualizer"
                width: parent.width
                height: 42
                radius: 8
                color: openKeysMouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("../gnome-extension/icons/key-visualizer.svg")
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open Key visualizer"
                        color: Theme.accentText
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: openKeysMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.openDockComponent("key-visualizer")
                }
            }
        }
    }

    component DateTimeChoice: Row {
        id: choiceRow
        required property string title
        required property string selectedKey
        required property var options
        signal chosen(string key)
        width: panel.contentWidth
        height: 36
        spacing: 8

        Text {
            width: 76
            height: parent.height
            text: title
            verticalAlignment: Text.AlignVCenter
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 12
        }

        Row {
            width: choiceRow.width - 84
            height: parent.height
            spacing: 6

            Repeater {
                model: choiceRow.options

                delegate: Rectangle {
                    required property var modelData
                    width: (choiceRow.width - 84 - 6 * (choiceRow.options.length - 1))
                        / choiceRow.options.length
                    height: choiceRow.height
                    radius: 8
                    color: choiceRow.selectedKey === modelData.key
                        ? Theme.selected : (choiceMouse.containsMouse
                            ? Theme.controlHover : Theme.control)

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        text: modelData.label
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 12
                        font.weight: choiceRow.selectedKey
                            === modelData.key ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        objectName: "date-time-choice-check-"
                            + choiceRow.title.toLowerCase() + "-" + modelData.key
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: choiceRow.selectedKey === modelData.key
                        text: "✓"
                        color: Theme.accent
                        font.family: Qt.application.font.family
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: choiceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choiceRow.chosen(modelData.key)
                    }
                }
            }
        }
    }

    component DateTimeHeading: Row {
        required property string title
        required property string preview
        width: panel.contentWidth
        height: 24

        Text {
            text: title
            color: Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width - x
            text: preview
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            color: Theme.mutedText
            font.family: Qt.application.font.family
            font.pixelSize: 13
        }
    }

    Flickable {
        objectName: "date-time-scroll"
        x: panel.contentX
        y: 76
        width: panel.contentWidth
        height: panel.height - y - 12
        contentWidth: width
        contentHeight: dateTimeColumn.height
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds
        flickableDirection: Flickable.VerticalFlick
        visible: panel.section === "date-time"

        Column {
            id: dateTimeColumn
            width: parent.width
            spacing: 7

            DateTimeChoice {
                title: "Language"
                selectedKey: backend.dateTimeSettings.dateLocale
                    === backend.dateTimeSettings.timeLocale
                    ? backend.dateTimeSettings.dateLocale : ""
                options: [{key: "global", label: "Global"},
                    {key: "thai", label: "ไทย (พ.ศ.)"}]
                onChosen: key => {
                    backend.setDateTimeSetting("dateLocale", key)
                    backend.setDateTimeSetting("timeLocale", key)
                }
            }

            Text {
                visible: backend.dateTimeSettings.dateLocale
                    !== backend.dateTimeSettings.timeLocale
                text: "Date and time use different languages; choose one to sync them."
                color: Theme.mutedText
                font.family: Qt.application.font.family
                font.pixelSize: 11
            }

            DateTimeHeading {
                title: "Date"
                preview: backend.previewDate(backend.dateTimeSettings.dateFormat,
                    backend.dateTimeSettings.dateLocale)
            }

            Grid {
                width: parent.width
                columns: 2
                spacing: 4

                Repeater {
                    model: panel.dateFormats

                    delegate: Rectangle {
                        required property string modelData
                        width: (panel.contentWidth - 4) / 2
                        height: 40
                        radius: 8
                        color: backend.dateTimeSettings.dateFormat === modelData
                            ? Theme.selected : (dateFormatMouse.containsMouse
                                ? Theme.controlHover : Theme.control)

                        Column {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20
                            spacing: 1

                            Text {
                                width: parent.width
                                text: modelData
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Qt.application.font.family
                                font.pixelSize: 12
                                font.weight: backend.dateTimeSettings.dateFormat
                                    === modelData ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                width: parent.width
                                text: backend.previewDate(modelData,
                                    backend.dateTimeSettings.dateLocale)
                                elide: Text.ElideRight
                                color: Theme.mutedText
                                font.family: Qt.application.font.family
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            objectName: "date-time-date-format-check-" + modelData
                            anchors.right: parent.right
                            anchors.rightMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            visible: backend.dateTimeSettings.dateFormat === modelData
                            text: "✓"
                            color: Theme.accent
                            font.family: Qt.application.font.family
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: dateFormatMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.setDateTimeSetting("dateFormat", modelData)
                        }
                    }
                }
            }

            DateTimeHeading {
                title: "Time"
                preview: backend.previewTime(backend.dateTimeSettings.timeFormat,
                    backend.dateTimeSettings.timeLocale,
                    backend.dateTimeSettings.showSeconds)
            }

            DateTimeChoice {
                title: "Format"
                selectedKey: backend.dateTimeSettings.timeFormat
                options: [{key: "24-colon", label: "24h :"},
                    {key: "12-colon", label: "12h :"},
                    {key: "24-dot", label: "24h ."},
                    {key: "12-dot", label: "12h ."}]
                onChosen: key => backend.setDateTimeSetting("timeFormat", key)
            }

            DateTimeToggle {
                title: "Show seconds"
                height: 40
                active: backend.dateTimeSettings.showSeconds
                onToggled: backend.setDateTimeSetting("showSeconds", !active)
            }

            Row {
                spacing: 8

                Repeater {
                    model: [{key: "date-display", label: "Date on dock"},
                        {key: "time-display", label: "Time on dock"}]

                    delegate: DateTimeToggle {
                        required property var modelData
                        width: (panel.contentWidth - 8) / 2
                        height: 40
                        title: modelData.label
                        active: backend.dockVisibleComponents.includes(modelData.key)
                        onToggled: backend.moveDockComponent(modelData.key,
                            active ? "hidden" : "visible",
                            active ? "" : (backend.dockVisibleComponents[0] || ""))
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
