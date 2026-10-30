import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import "TaskVim.js" as Vim

Item {
    id: win

    implicitWidth: 360
    implicitHeight: 336
    width: 360
    height: 336

    Item {
        id: card
        objectName: "tasks-card"

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

        readonly property bool vimEnabled: backend.taskVimEnabled
        readonly property bool vimHasFocus: vimEnabled && (activeFocus || vimInput.activeFocus)
            && (!win.Window.window || win.Window.window.active)
        property string vimMode: "normal"
        property string vimCommand: ""
        property string selectedTaskId: ""
        property int vimRowIndex: 0
        property var replaceHistory: []
        property bool initialized: false
        readonly property int selectedTaskIndex: taskIndexIn(backend.tasks, selectedTaskId)

        Component.onCompleted: {
            initialized = true
            if (vimEnabled) syncVimSelection()
        }
        onVimEnabledChanged: {
            if (!initialized) return
            if (!vimEnabled) finishVimEdit()
            vimCommand = ""
            vimMode = "normal"
            if (vimEnabled) {
                finishTransientEdit()
                syncVimSelection()
                Qt.callLater(function() { card.forceActiveFocus() })
            }
        }

        Connections {
            target: backend
            function onTasksChanged() {
                if (card.vimEnabled) card.syncVimSelection()
            }
        }

        Connections {
            target: win.Window.window
            function onActiveChanged() {
                if (!win.Window.window.active) card.clearTaskFocus()
            }
        }

        Keys.onPressed: event => {
            if (vimEnabled && !adding && pendingDeleteTaskId === "")
                handleVimKey(event)
        }

        function focusVimEditor() {
            if (vimMode === "normal") forceActiveFocus()
            else vimInput.forceActiveFocus()
        }

        function revealVimSelection() {
            const top = Math.max(0, selectedTaskIndex) * taskPitch
            if (top < taskList.contentY) taskList.contentY = top
            else if (top + taskRowHeight > taskList.contentY + taskList.height)
                taskList.contentY = top + taskRowHeight - taskList.height
        }

        function syncVimSelection() {
            if (backend.tasks.length === 0) {
                selectedTaskId = ""
                vimInput.text = ""
                vimMode = "normal"
                vimCommand = ""
                return
            }
            if (selectedTaskIndex < 0) {
                vimRowIndex = Math.max(0, Math.min(vimRowIndex, backend.tasks.length - 1))
                selectedTaskId = backend.tasks[vimRowIndex]["id"]
            }
            vimRowIndex = selectedTaskIndex
            if (vimMode === "normal") {
                const cursor = vimInput.cursorPosition
                vimInput.text = backend.tasks[selectedTaskIndex]["text"]
                vimInput.cursorPosition = Vim.normalPosition(vimInput.text, cursor)
            }
            revealVimSelection()
        }

        function selectVimTask(index) {
            if (!vimEnabled || backend.tasks.length === 0) return
            finishVimEdit()
            const cursor = vimInput.cursorPosition
            vimRowIndex = Math.max(0, Math.min(index, backend.tasks.length - 1))
            selectedTaskId = backend.tasks[vimRowIndex]["id"]
            vimInput.text = backend.tasks[vimRowIndex]["text"]
            vimInput.cursorPosition = Vim.normalPosition(vimInput.text, cursor)
            vimCommand = ""
            revealVimSelection()
            focusVimEditor()
        }

        function beginVimEdit(mode) {
            if (selectedTaskIndex < 0) {
                startAdding()
                return
            }
            vimCommand = ""
            replaceHistory = []
            const cursor = vimInput.cursorPosition
            vimMode = mode || "insert"
            vimInput.forceActiveFocus()
            vimInput.cursorPosition = cursor
        }

        function saveVimText() {
            const text = vimInput.text.trim()
            if (selectedTaskId !== "" && text.length > 0)
                backend.renameTask(selectedTaskId, text)
        }

        function finishVimEdit() {
            if (vimMode === "normal") return
            const cursor = Vim.previousCharacter(vimInput.text, vimInput.cursorPosition)
            vimMode = "normal"
            vimCommand = ""
            replaceHistory = []
            saveVimText()
            syncVimSelection()
            vimInput.cursorPosition = Vim.normalPosition(vimInput.text, cursor)
        }

        function replaceVimCharacter(text, remember) {
            const cursor = vimInput.cursorPosition
            const end = Vim.nextCharacter(vimInput.text, cursor)
            if (remember) {
                const history = replaceHistory.slice()
                history.push({position: cursor, removed: vimInput.text.slice(cursor, end),
                    inserted: text})
                replaceHistory = history
            }
            vimInput.remove(cursor, end)
            vimInput.insert(cursor, text)
            vimInput.cursorPosition = cursor + text.length
        }

        function handleVimKey(event) {
            event.accepted = false
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
            if (event.key === Qt.Key_Escape) {
                finishVimEdit()
                vimCommand = ""
                focusVimEditor()
                event.accepted = true
                return
            }
            if (vimMode === "replace") {
                if (event.key === Qt.Key_Backspace && replaceHistory.length > 0) {
                    const history = replaceHistory.slice()
                    const edit = history.pop()
                    vimInput.remove(edit.position, edit.position + edit.inserted.length)
                    vimInput.insert(edit.position, edit.removed)
                    vimInput.cursorPosition = edit.position
                    replaceHistory = history
                    event.accepted = true
                } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                    replaceVimCharacter(event.text, true)
                    event.accepted = true
                } else replaceHistory = []
                return
            }
            if (vimMode !== "normal") return
            event.accepted = true
            const key = event.text
            const cursor = vimInput.cursorPosition
            const text = vimInput.text
            if (vimCommand === "r") {
                vimCommand = ""
                if (key.length > 0 && key.charCodeAt(0) >= 32 && text.length > 0) {
                    replaceVimCharacter(key, false)
                    vimInput.cursorPosition = cursor
                    saveVimText()
                }
                return
            }
            if (vimCommand !== "") {
                const command = vimCommand + key
                vimCommand = ""
                if (command === "dd" && selectedTaskId !== "") {
                    backend.deleteTask(selectedTaskId)
                } else if (command === "ci") {
                    vimCommand = "ci"
                } else if (command === "ciw" && selectedTaskIndex >= 0) {
                    const word = Vim.innerWord(text, cursor, backend.isWordCharacter)
                    beginVimEdit("insert")
                    vimInput.remove(word.start, word.end)
                    vimInput.cursorPosition = word.start
                }
                return
            }
            if (key === "j" || event.key === Qt.Key_Down) selectVimTask(selectedTaskIndex + 1)
            else if (key === "k" || event.key === Qt.Key_Up) selectVimTask(selectedTaskIndex - 1)
            else if (key === "h" || event.key === Qt.Key_Left)
                vimInput.cursorPosition = Vim.previousCharacter(text, cursor)
            else if (key === "l" || event.key === Qt.Key_Right)
                vimInput.cursorPosition = Vim.normalPosition(text, Vim.nextCharacter(text, cursor))
            else if (key === "0") vimInput.cursorPosition = 0
            else if (key === "$") vimInput.cursorPosition = Vim.normalPosition(text, text.length)
            else if (key === "w") vimInput.cursorPosition = Vim.wordForward(text, cursor, backend.isWordCharacter)
            else if (key === "b") vimInput.cursorPosition = Vim.wordBackward(text, cursor, backend.isWordCharacter)
            else if (key === "i") beginVimEdit("insert")
            else if (key === "a" || key === "A") {
                beginVimEdit("insert")
                if (selectedTaskIndex >= 0)
                    vimInput.cursorPosition = key === "A" ? text.length : Vim.nextCharacter(text, cursor)
            }
            else if (key === "R") beginVimEdit("replace")
            else if (key === "C" && selectedTaskIndex >= 0) {
                beginVimEdit("insert")
                vimInput.remove(cursor, vimInput.length)
                vimInput.cursorPosition = cursor
            } else if (key === "d" || key === "c" || key === "r") vimCommand = key
            else if ((event.key === Qt.Key_Space || event.key === Qt.Key_Return)
                && selectedTaskId !== "") backend.toggleTask(selectedTaskId)
        }

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
            if (vimEnabled) finishVimEdit()
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
            if (vimEnabled) selectVimTask(backend.tasks.length - 1)
        }

        function cancelNewTask() {
            newTaskInput.text = ""
            adding = false
            if (vimEnabled) focusVimEditor()
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
            if (vimEnabled) finishVimEdit()
            if (adding) {
                commitNewTask()
                return
            }
            forceActiveFocus()
        }

        function clearTaskFocus() {
            if (adding) commitNewTask()
            if (vimEnabled) finishVimEdit()
            vimCommand = ""
            win.forceActiveFocus()
        }

        function toggleTaskFromMouse(taskId) {
            clearTaskFocus()
            backend.toggleTask(taskId)
        }

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
        }

        MouseArea {
            anchors.fill: parent
            enabled: card.adding || card.editingTaskId !== ""
                || card.vimHasFocus
            onClicked: card.clearTaskFocus()
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

        Controls.Switch {
            id: vimToggle
            objectName: "task-vim-toggle"
            anchors.right: progressText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: addButton.verticalCenter
            width: 84
            height: 30
            padding: 0
            checked: card.vimEnabled
            Accessible.name: "Vim mode"
            onToggled: backend.setTaskVimEnabled(checked)

            contentItem: Text {
                text: "Vim"
                verticalAlignment: Text.AlignVCenter
                color: card.vimEnabled ? card.textColor : card.dimColor
                font.family: card.family
                font.pixelSize: 13
            }
            indicator: Rectangle {
                x: vimToggle.width - width
                y: (vimToggle.height - height) / 2
                width: 42
                height: 24
                radius: 12
                color: vimToggle.checked ? Theme.accent : Theme.track
                border.width: vimToggle.visualFocus ? 1 : 0
                border.color: Theme.accent
                Rectangle {
                    x: vimToggle.checked ? parent.width - width - 3 : 3
                    y: 3
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.cardSurface
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        Text {
            id: progressText
            objectName: "task-progress"
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
                objectName: "new-task-input"
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
                Keys.onEscapePressed: {
                    if (card.vimEnabled) card.commitNewTask()
                    else card.cancelNewTask()
                }
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
                        || card.vimHasFocus
                    z: 0
                    onClicked: card.clearTaskFocus()
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
                        objectName: "task-row-" + index
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

                TextInput {
                    id: vimInput
                    objectName: "task-vim-editor"
                    x: 42
                    y: Math.max(0, card.selectedTaskIndex) * card.taskPitch
                    width: Math.max(0, taskContent.width - x - 66)
                    height: card.taskRowHeight
                    z: 2
                    visible: card.vimHasFocus && card.selectedTaskIndex >= 0 && !card.adding
                    enabled: card.vimMode !== "normal"
                    readOnly: card.vimMode === "normal"
                    cursorVisible: visible && (card.activeFocus || activeFocus)
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: card.selectedTaskIndex >= 0
                        && backend.tasks[card.selectedTaskIndex]["done"]
                        ? card.checkedTextColor : card.textColor
                    selectionColor: Theme.selected
                    selectedTextColor: card.textColor
                    font.family: card.family
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    selectByMouse: true
                    Accessible.name: "Selected task"
                    Keys.onPressed: event => card.handleVimKey(event)
                    Keys.onReturnPressed: { card.finishVimEdit(); card.focusVimEditor() }
                    Keys.onEnterPressed: { card.finishVimEdit(); card.focusVimEditor() }
                    onActiveFocusChanged: {
                        if (!activeFocus && card.vimMode !== "normal") card.finishVimEdit()
                    }
                    cursorDelegate: Rectangle {
                        width: card.vimMode === "insert" ? 2 : Math.max(8, cursorMetrics.advanceWidth)
                        height: 18
                        color: card.vimMode === "insert" ? Theme.accent : Qt.alpha(Theme.accent, 0.35)
                    }
                }

                TextMetrics {
                    id: cursorMetrics
                    font: vimInput.font
                    text: vimInput.text.slice(vimInput.cursorPosition,
                        Vim.nextCharacter(vimInput.text, vimInput.cursorPosition)) || " "
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
            border.width: card.vimHasFocus && card.selectedTaskId === row.taskId ? 1 : 0
            border.color: Qt.alpha(Theme.accent, 0.35)
            color: card.vimHasFocus && card.selectedTaskId === row.taskId ? Theme.control
                : card.draggingTaskId === row.taskId
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
                    : rowHover.hovered || row.editing
                        || (card.vimHasFocus && card.selectedTaskId === row.taskId)
                    ? Theme.cardSurface : Theme.control
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
                onClicked: card.toggleTaskFromMouse(row.taskId)
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
                visible: !row.editing && !(card.vimHasFocus && card.selectedTaskId === row.taskId)
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
                    else if (!wasDragging && card.vimEnabled && card.vimMode === "normal")
                        card.selectVimTask(card.taskIndexIn(backend.tasks, taskId))
                }

                onCanceled: {
                    row.dragging = false
                    card.clearTaskDrag()
                }

                onDoubleClicked: {
                    if (!row.dragging) {
                        if (card.vimEnabled) {
                            card.selectVimTask(card.taskIndexIn(backend.tasks, row.taskId))
                            card.beginVimEdit("insert")
                        } else card.editingTaskId = row.taskId
                    }
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
                onClicked: {
                    if (card.vimEnabled) {
                        card.selectVimTask(card.taskIndexIn(backend.tasks, row.taskId))
                        card.beginVimEdit("insert")
                    } else card.editingTaskId = row.taskId
                }
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
