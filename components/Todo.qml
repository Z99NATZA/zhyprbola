import QtQuick

Item {
    id: win

    implicitWidth: 360
    implicitHeight: 336
    width: 360
    height: 336

    Item {
        id: card

        anchors.fill: parent
        focus: true

        property color textColor: Theme.text
        property color dimColor: Qt.alpha(textColor, 0.72)
        property color surfaceColor: Theme.componentSurfaceFor("todo")
        property color accentColor: Theme.accent
        property color checkedTextColor: Theme.checkedText
        property real cornerRadius: 26
        readonly property string family: Qt.application.font.family
        readonly property int totalCount: backend.tasks.length
        readonly property int completedCount: {
            let count = 0
            for (const task of backend.tasks) {
                if (task["done"])
                    count += 1
            }
            return count
        }
        property bool adding: false
        property string editingTaskId: ""
        property string pendingDeleteTaskId: ""
        property string pendingDeleteTaskText: ""
        property string draggingTaskId: ""
        property var taskPreviewOrder: []
        property real draggingTaskY: 0
        readonly property int taskRowHeight: 40
        readonly property int taskRowGap: 8
        readonly property int taskPitch: taskRowHeight + taskRowGap
        readonly property int taskContentHeight: backend.tasks.length === 0 ? 0
            : backend.tasks.length * taskPitch - taskRowGap

        function copyTasks() {
            const tasks = []
            for (const task of backend.tasks)
                tasks.push(task)
            return tasks
        }

        function taskIndexIn(items, id) {
            for (let index = 0; index < items.length; index += 1) {
                if ((items[index]["id"] || "") === id)
                    return index
            }
            return -1
        }

        function visualTaskIndex(id) {
            if (draggingTaskId === "" || taskPreviewOrder.length === 0)
                return -1
            const index = taskIndexIn(taskPreviewOrder, id)
            return index < 0 ? 0 : index
        }

        function updateTaskPreview(id, rowY) {
            const tasks = taskPreviewOrder.slice()
            const from = taskIndexIn(tasks, id)
            if (from < 0)
                return
            const center = rowY + taskRowHeight / 2
            let insertAt = 0
            for (let index = 0; index < tasks.length; index += 1) {
                if ((tasks[index]["id"] || "") === id)
                    continue
                const otherCenter = index * taskPitch + taskRowHeight / 2
                if (center > otherCenter || (center === otherCenter && index > from))
                    insertAt += 1
            }
            if (from === insertAt)
                return
            const task = tasks.splice(from, 1)[0]
            tasks.splice(insertAt, 0, task)
            taskPreviewOrder = tasks
        }

        function clearTaskDrag() {
            draggingTaskId = ""
            taskPreviewOrder = []
            draggingTaskY = 0
        }

        function maybeScrollTasks(source, x, y) {
            const point = source.mapToItem(taskList, x, y)
            if (point.y < 24)
                taskList.contentY = Math.max(0, taskList.contentY - 10)
            else if (point.y > taskList.height - 24)
                taskList.contentY = Math.min(Math.max(0, taskList.contentHeight
                    - taskList.height), taskList.contentY + 10)
        }

        function startAdding() {
            editingTaskId = ""
            adding = true
            newTaskInput.text = ""
            Qt.callLater(function() { newTaskInput.forceActiveFocus() })
        }

        function commitNewTask() {
            const text = newTaskInput.text.trim()
            if (text.length === 0) {
                cancelNewTask()
                return
            }
            backend.addTask(text)
            newTaskInput.text = ""
            adding = false
            clearTaskDrag()
        }

        function cancelNewTask() {
            newTaskInput.text = ""
            adding = false
        }

        function requestDeleteTask(id, text) {
            pendingDeleteTaskId = id
            pendingDeleteTaskText = text
            Qt.callLater(function() { deleteConfirmOverlay.forceActiveFocus() })
        }

        function cancelDeleteTask() {
            pendingDeleteTaskId = ""
            pendingDeleteTaskText = ""
            forceActiveFocus()
        }

        function confirmDeleteTask() {
            const taskId = pendingDeleteTaskId
            cancelDeleteTask()
            if (taskId.length > 0)
                backend.deleteTask(taskId)
        }

        function finishTransientEdit() {
            if (adding) {
                commitNewTask()
                return
            }
            forceActiveFocus()
        }

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
        }

        MouseArea {
            anchors.fill: parent
            enabled: card.adding || card.editingTaskId !== ""
            onClicked: card.finishTransientEdit()
        }

        Text {
            id: title
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 24
            anchors.topMargin: 20
            text: "Tasks"
            color: card.textColor
            font.family: card.family
            font.pixelSize: 19
            font.weight: Font.DemiBold
        }

        Text {
            id: progressText
            anchors.right: addButton.left
            anchors.rightMargin: 14
            anchors.verticalCenter: addButton.verticalCenter
            text: card.completedCount + "/" + card.totalCount
            color: card.dimColor
            font.family: card.family
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        Item {
            id: addButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 21
            anchors.topMargin: 16
            width: 30
            height: 30
            scale: addHover.hovered ? 1.08 : 1.0

            Behavior on scale { NumberAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.accent
            }

            FlatIcon {
                anchors.centerIn: parent
                width: 18
                height: 18
                name: "add"
                ink: Theme.accentText
            }

            HoverHandler { id: addHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.startAdding()
            }
        }

        Rectangle {
            id: addEditor
            x: 24
            y: 60
            width: parent.width - 48
            height: 40
            radius: 8
            visible: card.adding
            color: Theme.control
            border.width: 1
            border.color: Theme.accent

            TextInput {
                id: newTaskInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: card.textColor
                selectionColor: Theme.selected
                selectedTextColor: card.textColor
                font.family: card.family
                font.pixelSize: 14
                Keys.onReturnPressed: card.commitNewTask()
                Keys.onEnterPressed: card.commitNewTask()
                Keys.onEscapePressed: card.cancelNewTask()
            }

            Text {
                anchors.left: newTaskInput.left
                anchors.verticalCenter: parent.verticalCenter
                visible: newTaskInput.text.length === 0 && !newTaskInput.activeFocus
                text: "New task"
                color: card.dimColor
                font.family: card.family
                font.pixelSize: 14
            }
        }

        Text {
            anchors.centerIn: taskList
            visible: backend.tasks.length === 0 && !card.adding
            text: "No tasks"
            color: card.dimColor
            font.family: card.family
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Flickable {
            id: taskList
            x: 24
            y: card.adding ? 112 : 62
            width: parent.width - 48
            height: parent.height - y - 18
            clip: true
            interactive: card.draggingTaskId === "" && contentHeight > height
            boundsBehavior: Flickable.DragAndOvershootBounds
            contentWidth: width
            contentHeight: Math.max(height, card.taskContentHeight)

            Item {
                id: taskContent
                width: taskList.width
                height: Math.max(taskList.height, card.taskContentHeight)

                MouseArea {
                    anchors.fill: parent
                    enabled: card.adding || card.editingTaskId !== ""
                    z: 0
                    onClicked: card.finishTransientEdit()
                }

                Rectangle {
                    width: taskContent.width
                    height: card.taskRowHeight
                    y: card.visualTaskIndex(card.draggingTaskId) * card.taskPitch
                    radius: 8
                    visible: card.draggingTaskId !== ""
                    color: Qt.alpha(card.accentColor, 0.10)
                    border.width: 1
                    border.color: Qt.alpha(card.accentColor, 0.55)
                }

                Repeater {
                    model: backend.tasks

                    delegate: TaskRow {
                        required property int index
                        required property var modelData
                        width: taskContent.width
                        height: card.taskRowHeight
                        y: card.draggingTaskId === taskId ? card.draggingTaskY
                            : (card.visualTaskIndex(taskId) >= 0
                                ? card.visualTaskIndex(taskId) : index) * card.taskPitch
                        z: card.draggingTaskId === taskId ? 4 : 1
                        taskId: modelData["id"] || ""
                        taskText: modelData["text"] || ""
                        checked: Boolean(modelData["done"])
                        editing: card.editingTaskId === taskId

                        Behavior on y {
                            enabled: card.draggingTaskId !== taskId
                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

            }
        }

        Item {
            id: deleteConfirmOverlay

            anchors.fill: parent
            z: 20
            visible: card.pendingDeleteTaskId !== ""
            enabled: visible
            focus: visible
            Keys.onEscapePressed: card.cancelDeleteTask()

            Rectangle {
                anchors.fill: parent
                radius: card.cornerRadius
                color: Qt.rgba(63 / 255, 43 / 255, 65 / 255, 0.16)
            }

            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                id: deleteConfirmDialog

                anchors.centerIn: parent
                width: Math.min(parent.width - 44, 280)
                height: 128
                radius: 14
                color: Theme.cardSurface
                border.width: 1
                border.color: Qt.alpha(card.accentColor, 0.18)

                Text {
                    id: deleteMessage

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 20
                    text: card.pendingDeleteTaskText
                    color: card.dimColor
                    font.family: card.family
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                Item {
                    id: deleteActions

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.bottomMargin: 16
                    height: 34

                    Rectangle {
                        id: cancelDeleteButton

                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: Math.floor((parent.width - 10) / 2)
                        height: parent.height
                        radius: 9
                        color: cancelDeleteMouse.containsMouse ? Theme.controlHover : Theme.control

                        Text {
                            anchors.centerIn: parent
                            text: "ยกเลิก"
                            color: card.textColor
                            font.family: card.family
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: cancelDeleteMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.cancelDeleteTask()
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: Math.floor((parent.width - 10) / 2)
                        height: parent.height
                        radius: 9
                        color: confirmDeleteMouse.containsMouse
                            ? Qt.darker(Theme.accent, 1.08)
                            : Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "ลบ"
                            color: Theme.accentText
                            font.family: card.family
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: confirmDeleteMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.confirmDeleteTask()
                        }
                    }
                }
            }
        }
    }

    component TaskRow: Item {
        id: row

        property string taskId: ""
        property string taskText: ""
        property bool checked: false
        property bool editing: false
        property real dragStartX: 0
        property real dragStartY: 0
        property real dragOffsetY: 0
        property bool dragging: false

        width: parent ? parent.width : 300

        function commitEdit() {
            const text = editInput.text.trim()
            const taskId = row.taskId
            card.editingTaskId = ""
            if (text.length > 0)
                backend.renameTask(taskId, text)
        }

        function cancelEdit() {
            editInput.text = row.taskText
            card.editingTaskId = ""
        }

        onEditingChanged: {
            if (editing) {
                editInput.text = taskText
                Qt.callLater(function() {
                    editInput.forceActiveFocus()
                    editInput.cursorPosition = editInput.length
                })
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: card.draggingTaskId === row.taskId
                ? Qt.alpha(Theme.accent, 0.12)
                : rowHover.hovered || row.editing
                ? Theme.control
                : "transparent"
        }

        scale: card.draggingTaskId === row.taskId ? 1.015 : 1
        opacity: card.draggingTaskId !== "" && card.draggingTaskId !== row.taskId
            ? 0.94 : 1
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity { NumberAnimation { duration: 100 } }

        Item {
            id: checkbox
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            Rectangle {
                anchors.centerIn: parent
                width: 19
                height: 19
                radius: 6
                color: row.checked ? card.accentColor
                    : rowHover.hovered || row.editing ? Theme.cardSurface : Theme.control
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                visible: row.checked
                text: "✓"
                color: Theme.accentText
                font.family: card.family
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.toggleTask(row.taskId)
            }
        }

        Item {
            id: dragSurface
            anchors.left: checkbox.right
            anchors.leftMargin: 10
            anchors.right: editButton.left
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Text {
                id: label
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.editing
                text: row.taskText
                color: row.checked ? card.checkedTextColor : card.textColor
                elide: Text.ElideRight
                font.family: card.family
                font.pixelSize: 14
                font.weight: Font.Medium
                opacity: row.checked ? 1.0 : 0.90
            }

            MouseArea {
                id: dragMouse
                anchors.fill: parent
                enabled: !row.editing
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: row.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: function(mouse) {
                    row.dragStartX = mouse.x
                    row.dragStartY = mouse.y
                    row.dragOffsetY = mouse.y
                    row.dragging = false
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return
                    const dx = mouse.x - row.dragStartX
                    const dy = mouse.y - row.dragStartY
                    if (!row.dragging && dx * dx + dy * dy < 36)
                        return
                    if (!row.dragging) {
                        row.dragging = true
                        card.draggingTaskId = row.taskId
                        card.taskPreviewOrder = card.copyTasks()
                    }
                    card.draggingTaskId = row.taskId
                    const dragPoint = dragMouse.mapToItem(taskContent, mouse.x, mouse.y)
                    card.draggingTaskY = Math.max(0, Math.min(
                        Math.max(0, taskContent.height - row.height),
                        dragPoint.y - row.dragOffsetY))
                    card.updateTaskPreview(row.taskId, card.draggingTaskY)
                    card.maybeScrollTasks(dragMouse, mouse.x, mouse.y)
                }

                onReleased: {
                    const taskId = row.taskId
                    const wasDragging = row.dragging
                    const from = wasDragging
                        ? card.taskIndexIn(card.copyTasks(), taskId) : -1
                    const to = wasDragging ? card.visualTaskIndex(taskId) : -1
                    row.dragging = false
                    card.clearTaskDrag()
                    if (from >= 0 && to >= 0 && from !== to)
                        backend.moveTask(taskId, to > from ? to + 1 : to)
                }

                onCanceled: {
                    row.dragging = false
                    card.clearTaskDrag()
                }

                onDoubleClicked: {
                    if (!row.dragging)
                        card.editingTaskId = row.taskId
                }
            }
        }

        Item {
            id: editSurface
            anchors.left: checkbox.right
            anchors.leftMargin: 10
            anchors.right: editButton.left
            anchors.rightMargin: 6
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: row.editing

            TextInput {
                id: editInput
                anchors.fill: parent
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: card.textColor
                selectionColor: Theme.selected
                selectedTextColor: card.textColor
                font.family: card.family
                font.pixelSize: 14
                font.weight: Font.Medium
                onAccepted: row.commitEdit()
                Keys.onReturnPressed: row.commitEdit()
                Keys.onEnterPressed: row.commitEdit()
                Keys.onEscapePressed: row.cancelEdit()
                onActiveFocusChanged: {
                    if (!activeFocus && row.editing)
                        row.commitEdit()
                }
            }
        }

        Item {
            id: editButton
            anchors.right: deleteButton.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            opacity: rowHover.hovered || row.editing ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 100 } }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: editMouse.containsMouse ? Theme.controlHover : "transparent"
            }

            FlatIcon {
                anchors.centerIn: parent
                width: 15
                height: 15
                name: "edit"
                ink: card.dimColor
            }

            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.editingTaskId = row.taskId
            }
        }

        Item {
            id: deleteButton
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            opacity: rowHover.hovered || row.editing ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 100 } }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: deleteMouse.containsMouse ? Theme.controlHover : "transparent"
            }

            FlatIcon {
                anchors.centerIn: parent
                width: 15
                height: 15
                name: "trash"
                ink: card.dimColor
            }

            MouseArea {
                id: deleteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.requestDeleteTask(row.taskId, row.taskText)
            }
        }

        HoverHandler { id: rowHover }
    }
}
