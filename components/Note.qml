import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import "NoteVim.js" as Vim

Item {
    id: win

    signal closeRequested()

    implicitWidth: 560
    implicitHeight: 460
    width: 560
    height: 460

    Item {
        id: card
        objectName: "note-card"
        anchors.fill: parent

        property color textColor: Theme.text
        property color dimColor: Qt.alpha(textColor, 0.72)
        property color surfaceColor: Theme.componentSurfaceFor("note")
        property real cornerRadius: 14
        readonly property string family: Qt.application.font.family

        // Document state.
        property string filePath: ""
        property string savedText: ""
        property bool dirty: false
        readonly property string fileName: filePath === "" ? "Untitled"
            : filePath.slice(filePath.lastIndexOf("/") + 1)
        readonly property bool isMarkdown: /\.(md|markdown)$/i.test(filePath)
        property bool preview: false
        property string message: ""
        property bool messageError: false
        // Action waiting on the unsaved-changes prompt: "close-tab" or "quit".
        property string pendingAction: ""

        // Tabs: the current tab lives in the editor and the properties above;
        // the others are snapshots in `tabs`.
        property var tabs: []
        property int currentTab: 0

        // Vim state.
        readonly property bool vimEnabled: backend.noteVimEnabled
        property string vimMode: "normal"
        property string vimPending: ""
        property string vimCount: ""
        property int goalColumn: 0
        property var vimRegister: ({text: "", linewise: false})
        property var undoStack: []
        property var redoStack: []
        property var replaceHistory: []
        property string lastSearch: ""
        property bool lastSearchForward: true
        property bool lastSearchWhole: false
        // "." repeat: every change calls pushUndo, which bumps changeTick, so a
        // finished key sequence that moved the tick is the last change. Inserts
        // also keep the text typed before Escape.
        property int changeTick: 0
        property var lastChange: null
        property var recordKeys: []
        property string recordCount: ""
        property int recordTick: 0
        property var pendingChange: null
        property string insertBase: ""
        property int insertStart: 0
        property bool replaying: false
        // Visual mode: the anchor and the moving end, both inclusive. The
        // TextEdit selection draws the highlight; visualSync marks our own
        // selection updates so they are not mistaken for mouse selections.
        property int visualAnchor: 0
        property int visualCursor: 0
        property bool visualLine: false
        property bool visualSync: false
        property var lastVisual: null
        readonly property bool normalMode: vimEnabled && vimMode !== "insert" && vimMode !== "replace"

        readonly property int cursorLine: Vim.lineIndex(editor.text, editor.cursorPosition) + 1
        readonly property int cursorColumn: Vim.column(editor.text, editor.cursorPosition) + 1

        // TextEdit moves its cursor to the end whenever readOnly flips, so
        // switch it here and keep the Vim cursor where it was.
        onNormalModeChanged: syncReadOnly()
        function syncReadOnly() {
            const position = editor.cursorPosition
            editor.readOnly = normalMode
            editor.cursorPosition = position
        }

        Component.onCompleted: {
            syncReadOnly()
            restoreTabs()
            Qt.callLater(focusEditor)
        }

        onVimEnabledChanged: {
            visualSync = true
            editor.deselect()
            visualSync = false
            vimMode = "normal"
            vimPending = ""
            vimCount = ""
            if (vimEnabled) editor.cursorPosition = Vim.normalPosition(editor.text, editor.cursorPosition)
            focusEditor()
        }

        function focusEditor() {
            if (vimMode === "command") commandInput.forceActiveFocus()
            else editor.forceActiveFocus()
        }

        function showMessage(text, error) {
            message = text
            messageError = Boolean(error)
            messageTimer.restart()
        }

        function setDocument(text, path) {
            editor.text = text
            savedText = text
            dirty = false
            filePath = path
            undoStack = []
            redoStack = []
            vimMode = "normal"
            vimPending = ""
            vimCount = ""
            preview = false
            editor.cursorPosition = 0
            flick.contentY = 0
            backend.setNoteLastFile(path)
            persistTabs()
        }

        // ---- Tabs ----------------------------------------------------------

        function emptyTab() {
            return {filePath: "", text: "", savedText: "", cursor: 0, undo: [], redo: [],
                scroll: 0, preview: false, dirty: false}
        }

        function storeCurrentTab() {
            const list = tabs.slice()
            list[currentTab] = {filePath: filePath, text: editor.text, savedText: savedText,
                cursor: editor.cursorPosition, undo: undoStack, redo: redoStack,
                scroll: flick.contentY, preview: preview, dirty: dirty}
            tabs = list
        }

        function loadTab(index) {
            const tab = tabs[index]
            currentTab = index
            editor.text = tab.text
            savedText = tab.savedText
            dirty = tab.text !== tab.savedText
            filePath = tab.filePath
            undoStack = tab.undo
            redoStack = tab.redo
            preview = tab.preview
            vimMode = "normal"
            vimPending = ""
            vimCount = ""
            editor.cursorPosition = Math.min(tab.cursor, editor.text.length)
            flick.contentY = tab.scroll
            backend.setNoteLastFile(filePath)
            focusEditor()
        }

        function switchTab(index) {
            if (index < 0 || index >= tabs.length || index === currentTab) return
            storeCurrentTab()
            loadTab(index)
        }

        function nextTab(step) {
            if (tabs.length > 1) switchTab((currentTab + step + tabs.length) % tabs.length)
        }

        function newTab() {
            storeCurrentTab()
            const list = tabs.slice()
            list.splice(currentTab + 1, 0, emptyTab())
            tabs = list
            loadTab(currentTab + 1)
        }

        function tabPath(index) { return index === currentTab ? filePath : tabs[index].filePath }
        function tabDirty(index) { return index === currentTab ? dirty : tabs[index].dirty }
        function tabTitle(index) {
            const path = tabPath(index)
            return path === "" ? "Untitled" : path.slice(path.lastIndexOf("/") + 1)
        }

        function persistTabs() {
            const paths = []
            for (let index = 0; index < tabs.length; ++index) {
                if (tabPath(index) !== "") paths.push(tabPath(index))
            }
            backend.setNoteOpenFiles(paths)
        }

        function restoreTabs() {
            const last = backend.noteLastFile
            let paths = backend.noteOpenFiles.slice()
            if (paths.length === 0 && last !== "") paths = [last]
            const list = []
            let active = 0
            for (const path of paths) {
                const result = backend.readTextFile(path)
                if (!result.ok) continue
                if (result.path === last) active = list.length
                list.push(Object.assign(emptyTab(), {filePath: result.path, text: result.text,
                    savedText: result.text}))
            }
            tabs = list.length > 0 ? list : [emptyTab()]
            loadTab(Math.min(active, tabs.length - 1))
            persistTabs()
        }

        // Opens in a new tab, reusing an empty Untitled tab or the file's own tab.
        function openInTab(path, quiet) {
            const result = backend.readTextFile(path)
            if (!result.ok) {
                if (!quiet) showMessage("Cannot open: " + result.error, true)
                return false
            }
            for (let index = 0; index < tabs.length; ++index) {
                if (tabPath(index) === result.path) {
                    switchTab(index)
                    return true
                }
            }
            if (filePath !== "" || editor.text !== "") newTab()
            setDocument(result.text, result.path)
            if (!quiet) showMessage("Opened " + fileName)
            return true
        }

        // Closing the last tab clears it; on an empty Untitled tab it closes
        // the panel, like the last tab of a terminal.
        function closeTab(index) {
            if (index === undefined) index = currentTab
            switchTab(index)
            if (tabs.length === 1 && filePath === "" && editor.text === "") {
                win.closeRequested()
                return
            }
            requestAction("close-tab")
        }

        function removeCurrentTab() {
            if (tabs.length === 1) {
                setDocument("", "")
                return
            }
            const list = tabs.slice()
            list.splice(currentTab, 1)
            tabs = list
            loadTab(Math.min(currentTab, list.length - 1))
            persistTabs()
        }

        // :q semantics: close the tab, or the panel when it is the last one.
        function quitTab() {
            if (tabs.length > 1) removeCurrentTab()
            else win.closeRequested()
        }

        // ---- File actions -------------------------------------------------

        function requestAction(action) {
            if (dirty) {
                pendingAction = action
                return
            }
            runAction(action)
        }

        function runAction(action) {
            pendingAction = ""
            if (action === "close-tab") removeCurrentTab()
            else if (action === "quit") quitTab()
            else if (action === "close-window") {
                removeCurrentTab()
                closeWindow()
                return
            }
            focusEditor()
        }

        // Window ×: walk the unsaved tabs one at a time, focusing each and asking.
        // Save or Discard closes that tab and moves to the next unsaved one;
        // Cancel stops. With nothing unsaved left, the panel closes.
        function closeWindow() {
            const index = nextDirtyTab()
            if (index < 0) {
                win.closeRequested()
                return
            }
            switchTab(index)
            pendingAction = "close-window"
        }

        function nextDirtyTab() {
            for (let step = 0; step < tabs.length; ++step) {
                const index = (currentTab + step) % tabs.length
                if (tabDirty(index)) return index
            }
            return -1
        }

        // Replaces the current tab's document (used by :e).
        function openPath(path, quiet) {
            const result = backend.readTextFile(path)
            if (!result.ok) {
                if (!quiet) showMessage("Cannot open: " + result.error, true)
                return false
            }
            setDocument(result.text, result.path)
            if (!quiet) showMessage("Opened " + fileName)
            return true
        }

        function save() {
            if (filePath === "") {
                chooseFile("save")
                return false
            }
            return writeTo(filePath)
        }

        function writeTo(path) {
            const local = backend.localFilePath(path)
            const error = backend.writeTextFile(local, editor.text)
            if (error !== "") {
                showMessage("Cannot save: " + error, true)
                return false
            }
            savedText = editor.text
            dirty = false
            if (local !== filePath) {
                filePath = local
                backend.setNoteLastFile(local)
                persistTabs()
            }
            showMessage("Saved " + fileName)
            return true
        }

        // GNOME's own chooser via xdg-desktop-portal; Qt's dialog is only a fallback.
        property bool choosingFile: false
        function chooseFile(mode) {
            if (choosingFile) return
            choosingFile = true
            backend.chooseNoteFile(mode, filePath)
        }

        Connections {
            target: backend
            function onNoteFileChosen(mode, path, error) {
                card.choosingFile = false
                if (error !== "") {
                    if (mode === "save") saveDialog.open()
                    else openDialog.open()
                    return
                }
                if (path === "") {
                    if (mode === "save") card.pendingAction = ""
                } else if (mode === "save") {
                    if (card.writeTo(path)) card.afterSave()
                } else {
                    card.openInTab(path, false)
                }
                card.focusEditor()
            }
        }

        function cancelPrompt() {
            pendingAction = ""
            focusEditor()
        }

        function afterSave() {
            if (pendingAction !== "") runAction(pendingAction)
        }

        function folderOf(path) {
            return path === "" ? StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
                : "file://" + path.slice(0, path.lastIndexOf("/"))
        }

        // ---- Vim editing ---------------------------------------------------

        function pushUndo() {
            const stack = undoStack.slice()
            stack.push({text: editor.text, cursor: editor.cursorPosition})
            if (stack.length > 200) stack.shift()
            undoStack = stack
            redoStack = []
            changeTick += 1
        }

        function restore(from, to) {
            if (from.length === 0) return false
            const source = from.slice()
            const target = to.slice()
            const state = source.pop()
            target.push({text: editor.text, cursor: editor.cursorPosition})
            editor.text = state.text
            editor.cursorPosition = Vim.normalPosition(editor.text, state.cursor)
            return {source: source, target: target}
        }

        function undo() {
            const result = restore(undoStack, redoStack)
            if (!result) { showMessage("Already at oldest change"); return }
            undoStack = result.source
            redoStack = result.target
        }

        function redo() {
            const result = restore(redoStack, undoStack)
            if (!result) { showMessage("Already at newest change"); return }
            redoStack = result.source
            undoStack = result.target
        }

        function setCursor(position, keepGoal) {
            editor.cursorPosition = Vim.normalPosition(editor.text, position)
            if (!keepGoal) goalColumn = Vim.column(editor.text, editor.cursorPosition)
        }

        function beginInsert(position, recorded) {
            if (!recorded) pushUndo()
            vimMode = "insert"
            vimPending = ""
            vimCount = ""
            editor.cursorPosition = position
            trackInsert(position)
        }

        function trackInsert(position) {
            insertBase = replaying ? "" : editor.text
            insertStart = position
        }

        function leaveInsert() {
            if (!replaying && pendingChange !== null) {
                const change = pendingChange
                change.insert = Vim.insertEdit(insertBase, editor.text, insertStart)
                change.insert.replace = vimMode === "replace"
                lastChange = change
            }
            pendingChange = null
            insertBase = ""
            const text = editor.text
            let position = editor.cursorPosition
            if (position > Vim.lineStart(text, position))
                position = Vim.previousCharacter(text, position)
            vimMode = "normal"
            replaceHistory = []
            setCursor(position)
        }

        function applyOperator(op, start, end) {
            if (end <= start) return
            vimRegister = {text: editor.text.slice(start, end), linewise: false}
            if (op === "y") { setCursor(start); return }
            pushUndo()
            editor.remove(start, end)
            if (op === "c") beginInsert(start, true)
            else setCursor(start)
        }

        function applyLineOperator(op, count) {
            const text = editor.text
            const range = Vim.lineRange(text, editor.cursorPosition, count)
            vimRegister = {text: range.text, linewise: true}
            if (op === "y") { showMessage(count + (count === 1 ? " line" : " lines") + " yanked"); return }
            pushUndo()
            if (op === "c") {
                const indentEnd = Vim.firstNonBlankRaw(text, range.start)
                editor.remove(indentEnd, range.end)
                beginInsert(indentEnd, true)
                return
            }
            editor.remove(range.removeStart, range.removeEnd)
            setCursor(Vim.firstNonBlank(editor.text, Math.min(range.removeStart, editor.text.length)))
        }

        function paste(after, count) {
            const reg = vimRegister
            if (reg.text === "") return
            pushUndo()
            const text = editor.text
            const cursor = editor.cursorPosition
            const repeated = reg.text.repeat(count)
            if (reg.linewise) {
                if (!after) {
                    const start = Vim.lineStart(text, cursor)
                    editor.insert(start, repeated)
                    setCursor(Vim.firstNonBlank(editor.text, start))
                } else {
                    const end = Vim.lineEnd(text, cursor)
                    if (end < text.length) {
                        editor.insert(end + 1, repeated)
                    } else {
                        editor.insert(end, "\n" + repeated.slice(0, -1))
                    }
                    setCursor(Vim.firstNonBlank(editor.text, end + 1))
                }
                return
            }
            const lineEmpty = Vim.lineStart(text, cursor) === Vim.lineEnd(text, cursor)
            const at = after && !lineEmpty ? Vim.nextCharacter(text, cursor) : cursor
            editor.insert(at, repeated)
            setCursor(at + repeated.length - 1)
        }

        function deleteCharacters(count, before) {
            const text = editor.text
            const cursor = editor.cursorPosition
            const start = Vim.lineStart(text, cursor)
            const end = Vim.lineEnd(text, cursor)
            let from = cursor
            let to = cursor
            if (before) {
                for (let i = 0; i < count && from > start; ++i) from = Vim.previousCharacter(text, from)
            } else {
                for (let i = 0; i < count && to < end; ++i) to = Vim.nextCharacter(text, to)
            }
            if (to <= from) return
            pushUndo()
            vimRegister = {text: text.slice(from, to), linewise: false}
            editor.remove(from, to)
            setCursor(from)
        }

        function joinLines(count) {
            pushUndo()
            for (let i = 0; i < Math.max(1, count - 1); ++i) {
                const text = editor.text
                const end = Vim.lineEnd(text, editor.cursorPosition)
                if (end >= text.length) break
                let next = end + 1
                while (next < text.length && (text[next] === " " || text[next] === "\t")) next += 1
                const trailing = end > Vim.lineStart(text, end) && /\s/.test(text[end - 1])
                const joiner = next < text.length && text[next] !== "\n" && end > Vim.lineStart(text, end)
                    && !trailing ? " " : ""
                editor.remove(end, next)
                editor.insert(end, joiner)
                editor.cursorPosition = end
            }
            setCursor(editor.cursorPosition)
        }

        function toggleCase(count) {
            const text = editor.text
            const cursor = editor.cursorPosition
            const end = Vim.lineEnd(text, cursor)
            let to = cursor
            for (let i = 0; i < count && to < end; ++i) to = Vim.nextCharacter(text, to)
            if (to <= cursor) return
            pushUndo()
            let swapped = ""
            for (const ch of text.slice(cursor, to))
                swapped += ch === ch.toUpperCase() ? ch.toLowerCase() : ch.toUpperCase()
            editor.remove(cursor, to)
            editor.insert(cursor, swapped)
            setCursor(to < end ? to : Vim.previousCharacter(editor.text, to))
        }

        function replaceCharacters(character, count) {
            const text = editor.text
            const cursor = editor.cursorPosition
            const end = Vim.lineEnd(text, cursor)
            let to = cursor
            for (let i = 0; i < count && to < end; ++i) to = Vim.nextCharacter(text, to)
            if (to <= cursor) return
            pushUndo()
            editor.remove(cursor, to)
            editor.insert(cursor, character.repeat(count))
            setCursor(cursor + character.length * (count - 1))
        }

        function replaceTyped(character) {
            const text = editor.text
            const cursor = editor.cursorPosition
            const end = Vim.lineEnd(text, cursor)
            const next = cursor < end ? Vim.nextCharacter(text, cursor) : cursor
            const history = replaceHistory.slice()
            history.push({position: cursor, removed: text.slice(cursor, next), inserted: character})
            replaceHistory = history
            editor.remove(cursor, next)
            editor.insert(cursor, character)
            editor.cursorPosition = cursor + character.length
        }

        function replaceWithLineBreak(count) {
            const text = editor.text
            const cursor = editor.cursorPosition
            const end = Vim.lineEnd(text, cursor)
            let to = cursor
            for (let i = 0; i < count && to < end; ++i) to = Vim.nextCharacter(text, to)
            if (to <= cursor) return
            pushUndo()
            editor.remove(cursor, to)
            editor.insert(cursor, "\n")
            setCursor(cursor + 1)
        }

        function shiftLines(direction, count) {
            const text = editor.text
            const range = Vim.lineRange(text, editor.cursorPosition, count)
            const block = text.slice(range.start, range.end)
            const shifted = block.split("\n").map(line => Vim.shiftLine(line, direction)).join("\n")
            if (shifted === block) return
            pushUndo()
            editor.remove(range.start, range.end)
            editor.insert(range.start, shifted)
            setCursor(Vim.firstNonBlank(editor.text, range.start))
        }

        function moveLines(delta) {
            const move = Vim.moveLine(editor.text, editor.cursorPosition, delta)
            if (!move) return
            pushUndo()
            editor.remove(move.start, move.end)
            editor.insert(move.start, move.text)
            setCursor(move.cursor, true)
        }

        function search(forward, count) {
            if (lastSearch === "") { showMessage("No previous search", true); return false }
            const text = editor.text
            let index = editor.cursorPosition
            for (let i = 0; i < Math.max(1, count || 1); ++i) {
                index = lastSearchWhole
                    ? Vim.findWord(text, lastSearch, index, forward, backend.isWordCharacter)
                    : forward ? Vim.findForward(text, lastSearch, index) : Vim.findBackward(text, lastSearch, index)
                if (index < 0) { showMessage("Pattern not found: " + lastSearch, true); return false }
            }
            setCursor(index)
            return true
        }

        // "*" and "#": search for the whole keyword under or after the cursor.
        function searchWord(forward, count) {
            const text = editor.text
            const word = Vim.keywordAt(text, editor.cursorPosition, backend.isWordCharacter)
            if (!word) { showMessage("No string under cursor", true); return }
            lastSearch = text.slice(word.start, word.end)
            lastSearchWhole = true
            lastSearchForward = forward
            editor.cursorPosition = word.start
            if (search(forward, count)) showMessage((forward ? "/" : "?") + lastSearch)
        }

        function repeatLastChange(count) {
            const change = lastChange
            if (!change) return
            const total = count > 0 ? String(count) : change.count
            replaying = true
            for (const digit of total) runNormalKey({text: digit, key: 0})
            for (const entry of change.keys) runNormalKey(entry)
            if (change.insert && (vimMode === "insert" || vimMode === "replace")) {
                const text = editor.text
                const cursor = editor.cursorPosition
                const limit = change.insert.replace ? Vim.lineEnd(text, cursor) : text.length
                const from = Math.max(0, cursor - change.insert.back)
                const to = Math.min(limit, cursor + change.insert.forward)
                editor.remove(from, Math.max(from, to))
                editor.insert(from, change.insert.text)
                editor.cursorPosition = from + change.insert.text.length
                leaveInsert()
            }
            replaying = false
        }

        function openCommandLine(prefix) {
            vimMode = "command"
            commandPrefix.text = prefix
            commandInput.text = ""
            commandInput.forceActiveFocus()
        }

        function closeCommandLine() {
            vimMode = "normal"
            editor.forceActiveFocus()
        }

        function runCommandLine() {
            const prefix = commandPrefix.text
            const input = commandInput.text.trim()
            closeCommandLine()
            if (prefix === "/" || prefix === "?") {
                if (input !== "") {
                    lastSearch = input
                    lastSearchWhole = false
                }
                lastSearchForward = prefix === "/"
                search(lastSearchForward)
                return
            }
            runExCommand(input)
        }

        function runExCommand(input) {
            if (input === "") return
            if (/^\d+$/.test(input)) {
                setCursor(Vim.firstNonBlank(editor.text, Vim.lineStartAt(editor.text, parseInt(input) - 1)))
                return
            }
            const match = input.match(/^(\S+?)(!?)(?:\s+(.*))?$/)
            const name = match ? match[1] : input
            const force = match && match[2] === "!"
            const argument = match && match[3] ? match[3].trim() : ""
            if (name === "w" || name === "write") {
                if (argument !== "") writeTo(argument)
                else save()
            } else if (name === "wq" || name === "x" || name === "xit") {
                pendingAction = "quit"
                const saved = argument !== "" ? writeTo(argument) : save()
                if (saved) afterSave()
            } else if (name === "q" || name === "quit" || name === "tabc" || name === "tabclose") {
                if (dirty && !force) showMessage("No write since last change (add ! to override)", true)
                else quitTab()
            } else if (name === "tabnew" || name === "tabe" || name === "tabedit") {
                if (argument !== "") {
                    newTab()
                    if (!openPath(argument, false)) removeCurrentTab()
                } else {
                    newTab()
                }
            } else if (name === "tabn" || name === "tabnext") {
                nextTab(1)
            } else if (name === "tabp" || name === "tabprevious" || name === "tabN") {
                nextTab(-1)
            } else if (name === "e" || name === "edit") {
                if (dirty && !force) { showMessage("No write since last change (add ! to override)", true); return }
                if (argument !== "") openPath(argument, false)
                else if (force && filePath !== "") openPath(filePath, false)
                else chooseFile("open")
            } else if (name === "enew" || name === "new") {
                if (dirty && !force) { showMessage("No write since last change (add ! to override)", true); return }
                setDocument("", "")
            } else {
                showMessage("Not an editor command: " + input, true)
            }
        }

        function handleVimKey(event) {
            if (!vimEnabled) return
            // Pressing Shift (or another modifier) on its own must not cancel a
            // pending "r", "d", "g", ... before the shifted key arrives.
            if (isModifierKey(event.key)) return
            if (event.modifiers & Qt.ControlModifier) {
                if (vimMode === "normal" && event.key === Qt.Key_R) { redo(); event.accepted = true }
                return
            }
            if ((event.modifiers & Qt.AltModifier) && !(event.modifiers & Qt.MetaModifier)
                && vimMode === "normal"
                && (event.key === Qt.Key_J || event.key === Qt.Key_K
                    || event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                const count = Math.max(1, parseInt(vimCount) || 1)
                vimPending = ""
                vimCount = ""
                moveLines(event.key === Qt.Key_J || event.key === Qt.Key_Down ? count : -count)
                event.accepted = true
                return
            }
            if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return

            if (vimMode === "visual") {
                event.accepted = true
                handleVisualKey(event)
                return
            }
            if (vimMode === "insert") {
                if (event.key === Qt.Key_Escape) { leaveInsert(); event.accepted = true }
                return
            }
            if (vimMode === "replace") {
                if (event.key === Qt.Key_Escape) {
                    leaveInsert()
                } else if (event.key === Qt.Key_Backspace) {
                    if (replaceHistory.length > 0) {
                        const history = replaceHistory.slice()
                        const edit = history.pop()
                        editor.remove(edit.position, edit.position + edit.inserted.length)
                        editor.insert(edit.position, edit.removed)
                        editor.cursorPosition = edit.position
                        replaceHistory = history
                    }
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    editor.insert(editor.cursorPosition, "\n")
                    replaceHistory = []
                } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                    replaceTyped(event.text)
                }
                event.accepted = true
                return
            }

            // Normal mode consumes every key so nothing edits the buffer by accident.
            event.accepted = true
            handleNormalKey(event)
        }

        function isModifierKey(key) {
            return key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
                || key === Qt.Key_AltGr || key === Qt.Key_Meta || key === Qt.Key_Super_L
                || key === Qt.Key_Super_R || key === Qt.Key_CapsLock || key === Qt.Key_NumLock
                || key === Qt.Key_Mode_switch
        }

        // Records each finished change so "." can replay it.
        function handleNormalKey(event) {
            if (vimPending === "" && event.text === ".") {
                const count = parseInt(vimCount) || 0
                vimCount = ""
                repeatLastChange(count)
                return
            }
            if (vimPending === "" && vimCount === "") {
                recordKeys = []
                recordCount = ""
                recordTick = changeTick
            }
            const countBefore = vimCount
            runNormalKey(event)
            if (event.key === Qt.Key_Escape) return
            if (/^[0-9]$/.test(event.text) && vimCount === countBefore + event.text)
                recordCount += event.text
            else
                recordKeys = recordKeys.concat([{text: event.text, key: event.key}])
            if (vimPending !== "" || vimCount !== "" || changeTick === recordTick) return
            const change = {keys: recordKeys, count: recordCount, insert: null}
            if (vimMode === "insert" || vimMode === "replace") pendingChange = change
            else if (vimMode === "normal") lastChange = change
        }

        function runNormalKey(event) {
            const key = event.text
            if (event.key === Qt.Key_Escape) {
                vimPending = ""
                vimCount = ""
                return
            }
            if (vimPending === "" || vimPending === "d" || vimPending === "c" || vimPending === "y") {
                if ((key >= "1" && key <= "9") || (key === "0" && vimCount !== "")) {
                    vimCount += key
                    return
                }
            }
            const count = Math.max(1, parseInt(vimCount) || 1)
            const hadCount = vimCount !== ""
            const pending = vimPending
            vimPending = ""
            vimCount = ""
            const text = editor.text
            const cursor = editor.cursorPosition
            const isWord = backend.isWordCharacter

            if (pending === "r") {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) replaceWithLineBreak(count)
                else if (key.length > 0 && key.charCodeAt(0) >= 32) replaceCharacters(key, count)
                return
            }
            if (pending === ">" || pending === "<") {
                if (key === pending) shiftLines(pending === ">" ? 1 : -1, count)
                return
            }
            if (pending === "g") {
                if (key === "g")
                    setCursor(Vim.firstNonBlank(text, hadCount ? Vim.lineStartAt(text, count - 1) : 0))
                else if (key === "t") {
                    if (hadCount) switchTab(count - 1)
                    else nextTab(1)
                } else if (key === "T") nextTab(-count)
                else if (key === "v") reselectVisual()
                return
            }
            if (pending === "d" || pending === "c" || pending === "y") {
                if (key === pending) { applyLineOperator(pending, count); return }
                if (key === "i" || key === "a") { vimPending = pending + key; return }
                let end = cursor
                if (key === "w" || key === "e") {
                    // Like Vim, "cw" changes to the end of the word; "dw" stops at the line end.
                    const toWordEnd = pending === "c" || key === "e"
                    let position = cursor
                    for (let i = 0; i < count; ++i) {
                        position = toWordEnd ? Vim.nextCharacter(text, Vim.wordEnd(text, position, isWord))
                            : Vim.wordForwardRaw(text, position, isWord)
                    }
                    end = Math.min(position, Math.max(Vim.lineEnd(text, cursor), cursor))
                    applyOperator(pending, cursor, end)
                } else if (key === "b") {
                    let start = cursor
                    for (let i = 0; i < count; ++i) start = Vim.wordBackward(text, start, isWord)
                    applyOperator(pending, start, cursor)
                } else if (key === "$") {
                    applyOperator(pending, cursor, Vim.lineEnd(text, cursor))
                } else if (key === "0") {
                    applyOperator(pending, Vim.lineStart(text, cursor), cursor)
                } else if (key === "j" || key === "k") {
                    if (key === "k") setCursor(Vim.verticalMove(text, cursor, -count, goalColumn))
                    applyLineOperator(pending, count + 1)
                } else if (key === "G") {
                    const lines = Vim.lineCount(text) - Vim.lineIndex(text, cursor)
                    applyLineOperator(pending, lines)
                }
                return
            }
            if (pending.length === 2 && (pending[1] === "i" || pending[1] === "a")) {
                if (key === "w") {
                    const word = Vim.innerWord(text, cursor, isWord)
                    let end = word.end
                    if (pending[1] === "a")
                        while (end < Vim.lineEnd(text, cursor) && (text[end] === " " || text[end] === "\t")) end += 1
                    applyOperator(pending[0], word.start, end)
                }
                return
            }

            const lineStart = Vim.lineStart(text, cursor)
            const lineEnd = Vim.lineEnd(text, cursor)
            if (key === "h" || event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
                let position = cursor
                for (let i = 0; i < count && position > lineStart; ++i) position = Vim.previousCharacter(text, position)
                setCursor(position)
            } else if (key === "l" || event.key === Qt.Key_Right || key === " ") {
                let position = cursor
                for (let i = 0; i < count; ++i) position = Vim.nextCharacter(text, position)
                setCursor(Math.min(position, lineEnd))
            } else if (key === "j" || event.key === Qt.Key_Down || event.key === Qt.Key_Return) {
                setCursor(Vim.verticalMove(text, cursor, count, goalColumn), true)
            } else if (key === "k" || event.key === Qt.Key_Up) {
                setCursor(Vim.verticalMove(text, cursor, -count, goalColumn), true)
            } else if (event.key === Qt.Key_PageDown) {
                setCursor(Vim.verticalMove(text, cursor, pageLines(), goalColumn), true)
            } else if (event.key === Qt.Key_PageUp) {
                setCursor(Vim.verticalMove(text, cursor, -pageLines(), goalColumn), true)
            } else if (key === "0" || event.key === Qt.Key_Home) {
                setCursor(lineStart)
            } else if (key === "^") {
                setCursor(Vim.firstNonBlank(text, cursor))
            } else if (key === "$" || event.key === Qt.Key_End) {
                setCursor(lineEnd)
                goalColumn = 1 << 30
            } else if (key === "w") {
                let position = cursor
                for (let i = 0; i < count; ++i) position = Vim.wordForward(text, position, isWord)
                setCursor(position)
            } else if (key === "b") {
                let position = cursor
                for (let i = 0; i < count; ++i) position = Vim.wordBackward(text, position, isWord)
                setCursor(position)
            } else if (key === "e") {
                let position = cursor
                for (let i = 0; i < count; ++i) position = Vim.wordEnd(text, position, isWord)
                setCursor(position)
            } else if (key === "G") {
                const line = hadCount ? count - 1 : Vim.lineCount(text) - 1
                setCursor(Vim.firstNonBlank(text, Vim.lineStartAt(text, line)))
            } else if (key === "i") {
                beginInsert(cursor)
            } else if (key === "a") {
                beginInsert(Math.min(Vim.nextCharacter(text, cursor), lineEnd))
            } else if (key === "I") {
                beginInsert(Vim.firstNonBlankRaw(text, cursor))
            } else if (key === "A") {
                beginInsert(lineEnd)
            } else if (key === "o") {
                pushUndo()
                editor.insert(lineEnd, "\n")
                beginInsert(lineEnd + 1, true)
            } else if (key === "O") {
                pushUndo()
                editor.insert(lineStart, "\n")
                beginInsert(lineStart, true)
            } else if (key === "x" || event.key === Qt.Key_Delete) {
                deleteCharacters(count, false)
            } else if (key === "X") {
                deleteCharacters(count, true)
            } else if (key === "D") {
                applyOperator("d", cursor, lineEnd)
            } else if (key === "C") {
                applyOperator("c", cursor, lineEnd)
                if (cursor === lineEnd) beginInsert(cursor)
            } else if (key === "s") {
                pushUndo()
                let end = cursor
                for (let i = 0; i < count && end < lineEnd; ++i) end = Vim.nextCharacter(text, end)
                editor.remove(cursor, end)
                beginInsert(cursor, true)
            } else if (key === "S") {
                applyLineOperator("c", count)
            } else if (key === "J") {
                joinLines(hadCount ? count : 2)
            } else if (key === "~") {
                toggleCase(count)
            } else if (key === "p" || key === "P") {
                paste(key === "p", count)
            } else if (key === "u") {
                undo()
            } else if (key === "R") {
                pushUndo()
                replaceHistory = []
                vimMode = "replace"
                trackInsert(cursor)
            } else if (key === "n" || key === "N") {
                search(key === "n" ? lastSearchForward : !lastSearchForward, count)
            } else if (key === "*" || key === "#") {
                searchWord(key === "*", count)
            } else if (key === "v" || key === "V") {
                enterVisual(cursor, cursor, key === "V")
            } else if (key === ":" || key === "/" || key === "?") {
                openCommandLine(key)
            } else if (key === "d" || key === "c" || key === "y" || key === "g" || key === "r"
                || key === ">" || key === "<") {
                vimPending = key
                vimCount = hadCount ? String(count) : ""
            }
        }

        // ---- Visual mode ---------------------------------------------------

        function enterVisual(anchor, position, linewise) {
            visualAnchor = anchor
            visualCursor = position
            visualLine = linewise
            vimPending = ""
            vimCount = ""
            vimMode = "visual"
            updateVisualSelection()
        }

        function reselectVisual() {
            if (!lastVisual) { showMessage("No previous Visual area", true); return }
            const text = editor.text
            enterVisual(Vim.normalPosition(text, lastVisual.anchor),
                Vim.normalPosition(text, lastVisual.cursor), lastVisual.line)
        }

        function exitVisual(position) {
            lastVisual = {anchor: visualAnchor, cursor: visualCursor, line: visualLine}
            visualSync = true
            editor.deselect()
            vimMode = "normal"
            vimPending = ""
            vimCount = ""
            visualSync = false
            setCursor(position === undefined ? visualCursor : position)
        }

        function visualBounds() {
            const text = editor.text
            const lo = Math.min(visualAnchor, visualCursor)
            const hi = Math.max(visualAnchor, visualCursor)
            return {lo: lo, hi: hi,
                lines: Vim.lineIndex(text, hi) - Vim.lineIndex(text, lo) + 1,
                start: visualLine ? Vim.lineStart(text, lo) : lo,
                end: visualLine ? Vim.lineEnd(text, hi) : Math.min(text.length, Vim.nextCharacter(text, hi))}
        }

        function updateVisualSelection() {
            const text = editor.text
            const bounds = visualBounds()
            // Linewise selections take the line break too, so empty lines show.
            const end = visualLine ? Math.min(text.length, bounds.end + 1) : bounds.end
            visualSync = true
            if (visualCursor >= visualAnchor) editor.select(bounds.start, end)
            else editor.select(end, bounds.start)
            visualSync = false
            flick.ensureVisible(editor.positionToRectangle(visualCursor))
        }

        // A mouse drag or double-click selection in normal mode starts Visual
        // mode; a click that clears the selection leaves it.
        function syncVisualFromSelection() {
            if (visualSync || !vimEnabled || (vimMode !== "normal" && vimMode !== "visual")) return
            if (editor.selectedText === "") {
                if (vimMode === "visual") {
                    vimMode = "normal"
                    setCursor(editor.cursorPosition)
                }
                return
            }
            const start = editor.selectionStart
            const last = Vim.previousCharacter(editor.text, editor.selectionEnd)
            const backward = editor.cursorPosition === start
            visualAnchor = backward ? last : start
            visualCursor = backward ? start : last
            visualLine = false
            vimPending = ""
            vimCount = ""
            vimMode = "visual"
        }

        function isVisualMotion(event) {
            const key = event.text
            if (key.length === 1 && "hjklwbe0123456789^$GgnN*# ".indexOf(key) >= 0) return true
            return [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End,
                Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Backspace, Qt.Key_Return, Qt.Key_Enter]
                .indexOf(event.key) >= 0
        }

        // Motions reuse the normal-mode handler on the moving end.
        function visualMotion(event) {
            visualSync = true
            editor.cursorPosition = visualCursor
            runNormalKey(event)
            visualCursor = editor.cursorPosition
            visualSync = false
            updateVisualSelection()
        }

        function visualOperator(op, linewise) {
            const bounds = visualBounds()
            const lines = linewise || visualLine
            exitVisual(bounds.lo)
            if (lines) applyLineOperator(op, bounds.lines)
            else applyOperator(op, bounds.start, bounds.end)
        }

        function visualShift(direction) {
            const bounds = visualBounds()
            exitVisual(bounds.lo)
            shiftLines(direction, bounds.lines)
        }

        function visualEdit(transform) {
            const bounds = visualBounds()
            const text = editor.text
            exitVisual(bounds.start)
            const before = text.slice(bounds.start, bounds.end)
            const after = transform(before)
            if (after === before) return
            pushUndo()
            editor.remove(bounds.start, bounds.end)
            editor.insert(bounds.start, after)
            setCursor(bounds.start)
        }

        function changeCase(value, how) {
            let out = ""
            for (const ch of value) {
                if (how === "u") out += ch.toLowerCase()
                else if (how === "U") out += ch.toUpperCase()
                else out += ch === ch.toUpperCase() ? ch.toLowerCase() : ch.toUpperCase()
            }
            return out
        }

        function replaceAll(value, character) {
            let out = ""
            for (const ch of value) out += ch === "\n" ? ch : character
            return out
        }

        // "p" swaps the selection into the register; "P" keeps the register.
        function visualPut(swap) {
            const reg = vimRegister
            if (reg.text === "") { exitVisual(); return }
            const bounds = visualBounds()
            const linewise = visualLine
            const text = editor.text
            const removed = text.slice(bounds.start, bounds.end)
            let inserted = reg.text
            if (linewise && reg.linewise) inserted = reg.text.slice(0, -1)
            else if (!linewise && reg.linewise) inserted = "\n" + reg.text
            exitVisual(bounds.start)
            pushUndo()
            editor.remove(bounds.start, bounds.end)
            editor.insert(bounds.start, inserted)
            if (swap) vimRegister = {text: linewise ? removed + "\n" : removed, linewise: linewise}
            if (linewise || reg.linewise)
                setCursor(Vim.firstNonBlank(editor.text, bounds.start + (linewise ? 0 : 1)))
            else
                setCursor(bounds.start + inserted.length - 1)
        }

        function handleVisualKey(event) {
            const key = event.text
            if (event.key === Qt.Key_Escape) { exitVisual(); return }
            if (vimPending === "r") {
                vimPending = ""
                if (key.length > 0 && key.charCodeAt(0) >= 32) visualEdit(value => replaceAll(value, key))
                return
            }
            if (vimPending === "g" && key !== "g") { vimPending = ""; vimCount = ""; return }
            if (vimPending === "" && "vVo".indexOf(key) >= 0 && key !== "") {
                vimCount = ""
                if (key === "o") {
                    const anchor = visualAnchor
                    visualAnchor = visualCursor
                    visualCursor = anchor
                } else if ((key === "V") === visualLine) {
                    exitVisual()
                    return
                } else {
                    visualLine = key === "V"
                }
                updateVisualSelection()
                return
            }
            if (vimPending === "") {
                if (key === "d" || key === "x" || event.key === Qt.Key_Delete) { visualOperator("d", false); return }
                if (key === "X" || key === "D") { visualOperator("d", true); return }
                if (key === "c" || key === "s") { visualOperator("c", false); return }
                if (key === "C" || key === "S" || key === "R") { visualOperator("c", true); return }
                if (key === "y") { visualOperator("y", false); return }
                if (key === "Y") { visualOperator("y", true); return }
                if (key === ">" || key === "<") { visualShift(key === ">" ? 1 : -1); return }
                if (key === "~" || key === "u" || key === "U") { visualEdit(value => changeCase(value, key)); return }
                if (key === "J") {
                    const bounds = visualBounds()
                    exitVisual(bounds.lo)
                    joinLines(Math.max(2, bounds.lines))
                    return
                }
                if (key === "p" || key === "P") { visualPut(key === "p"); return }
                if (key === "r") { vimPending = "r"; vimCount = ""; return }
            }
            if (isVisualMotion(event)) visualMotion(event)
        }

        function pageLines() {
            return Math.max(1, Math.floor(flick.height / Math.max(1, editorMetrics.height)) - 2)
        }

        Timer {
            id: messageTimer
            interval: 3200
            onTriggered: card.message = ""
        }

        FileDialog {
            id: openDialog
            title: "Open note"
            fileMode: FileDialog.OpenFile
            nameFilters: ["Text and Markdown (*.txt *.md *.markdown)", "Text (*.txt)",
                "Markdown (*.md *.markdown)", "All files (*)"]
            currentFolder: card.folderOf(card.filePath)
            onAccepted: card.openPath(selectedFile.toString(), false)
            onRejected: card.focusEditor()
        }

        FileDialog {
            id: saveDialog
            title: "Save note"
            fileMode: FileDialog.SaveFile
            nameFilters: ["Markdown (*.md)", "Text (*.txt)"]
            defaultSuffix: selectedNameFilter.extensions.length > 0
                ? selectedNameFilter.extensions[0] : "md"
            currentFolder: card.folderOf(card.filePath)
            onAccepted: {
                if (card.writeTo(selectedFile.toString())) card.afterSave()
                card.focusEditor()
            }
            onRejected: {
                card.pendingAction = ""
                card.focusEditor()
            }
        }

        Shortcut {
            sequences: [StandardKey.Save]
            onActivated: card.save()
        }
        Shortcut {
            sequence: "Ctrl+Shift+S"
            onActivated: card.chooseFile("save")
        }
        Shortcut {
            sequences: [StandardKey.Open]
            onActivated: card.chooseFile("open")
        }
        Shortcut {
            sequences: [StandardKey.New, "Ctrl+T"]
            onActivated: card.newTab()
        }
        Shortcut {
            sequence: "Ctrl+W"
            onActivated: card.closeTab()
        }
        Shortcut {
            sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
            onActivated: card.nextTab(1)
        }
        Shortcut {
            sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]
            onActivated: card.nextTab(-1)
        }

        // ---- Layout --------------------------------------------------------
        // Terminal-like: a tab strip with the file name, the editor filling the
        // rest, and every file action in the right-click menu.

        readonly property color barTint: Qt.alpha(Theme.text, 0.06)
        readonly property color tabTint: Qt.alpha(Theme.text, 0.11)
        readonly property int barHeight: 38

        Rectangle {
            anchors.fill: parent
            radius: card.cornerRadius
            color: card.surfaceColor
            border.width: Theme.cardBorderWidth
            border.color: Theme.cardBorder
        }

        Item {
            id: tabBar
            objectName: "note-tab-bar"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: card.barHeight
            clip: true

            // Rounded on top only, following the card corners.
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: -card.cornerRadius
                radius: card.cornerRadius
                color: card.barTint
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: if (win.Window.window) win.Window.window.startSystemMove()
                onDoubleClicked: card.toggleMaximized()
            }

            // Tabs scroll sideways when they outgrow the bar; + opens a new one.
            Flickable {
                id: tabStrip
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.min(contentWidth, tabBar.width - windowButtons.width - 24)
                contentWidth: tabRow.width
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width
                clip: true

                function revealCurrent() {
                    const tab = tabRepeater.itemAt(card.currentTab)
                    if (!tab) return
                    if (tab.x < contentX) contentX = tab.x
                    else if (tab.x + tab.width > contentX + width)
                        contentX = tab.x + tab.width - width
                }

                Connections {
                    target: card
                    function onCurrentTabChanged() { Qt.callLater(tabStrip.revealCurrent) }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        tabStrip.contentX = Math.max(0, Math.min(tabStrip.contentWidth - tabStrip.width,
                            tabStrip.contentX - delta / 2))
                    }
                }

                Row {
                    id: tabRow
                    height: tabStrip.height

                    Repeater {
                        id: tabRepeater
                        model: card.tabs.length

                        delegate: Rectangle {
                            id: tabItem
                            required property int index
                            readonly property bool current: index === card.currentTab
                            objectName: "note-tab-" + index
                            width: Math.min(220, Math.max(120, tabText.implicitWidth + 82))
                            height: tabRow.height
                            color: current ? card.tabTint
                                : tabMouse.containsMouse ? Qt.alpha(Theme.text, 0.04) : "transparent"
                            // Only the outer corner follows the card's rounding.
                            topLeftRadius: index === 0 ? card.cornerRadius : 0

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) card.closeTab(tabItem.index)
                                    else card.switchTab(tabItem.index)
                                }
                            }

                            Text {
                                id: tabText
                                objectName: "note-title"
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 28
                                anchors.rightMargin: 48
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.tabTitle(tabItem.index)
                                elide: Text.ElideMiddle
                                color: tabItem.current ? card.textColor : card.dimColor
                                font.family: "monospace"
                                font.pixelSize: 13
                            }

                            Rectangle {
                                objectName: "note-dirty-dot"
                                anchors.right: tabText.left
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Theme.accent
                                visible: card.tabDirty(tabItem.index)
                            }

                            Rectangle {
                                objectName: "note-tab-close"
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: width / 2
                                color: tabCloseMouse.containsMouse ? Theme.controlHover : "transparent"

                                FlatIcon {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    name: "close"
                                    ink: Theme.text
                                }

                                MouseArea {
                                    id: tabCloseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.closeTab(tabItem.index)
                                }
                            }
                        }
                    }

                    Item {
                        width: 40
                        height: tabRow.height

                        Rectangle {
                            objectName: "note-new-tab"
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: width / 2
                            color: newTabMouse.containsMouse ? Theme.controlHover : "transparent"

                            FlatIcon {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                name: "add"
                                ink: Theme.text
                            }

                            MouseArea {
                                id: newTabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.newTab()
                            }
                        }
                    }
                }
            }

            Row {
                id: windowButtons
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                WindowButton {
                    objectName: "note-minimize"
                    glyph: "minimize"
                    onClicked: if (win.Window.window) win.Window.window.showMinimized()
                }
                WindowButton {
                    objectName: "note-maximize"
                    glyph: "maximize"
                    onClicked: card.toggleMaximized()
                }
                WindowButton {
                    objectName: "note-close"
                    glyph: "close"
                    onClicked: card.closeWindow()
                }
            }
        }

        Item {
            id: editorFrame
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabBar.bottom
            anchors.bottom: statusLine.top

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                anchors.topMargin: 14
                anchors.bottomMargin: 8
                visible: !card.preview
                clip: true
                contentWidth: width
                contentHeight: editor.height
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {}

                function ensureVisible(rect) {
                    if (rect.y < contentY) contentY = rect.y
                    else if (rect.y + rect.height > contentY + height)
                        contentY = rect.y + rect.height - height
                }

                TextEdit {
                    id: editor
                    objectName: "note-editor"
                    width: flick.width - 8
                    height: Math.max(implicitHeight, flick.height)
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    color: card.textColor
                    selectionColor: Theme.selected
                    selectedTextColor: card.textColor
                    selectByMouse: true
                    persistentSelection: false
                    font.family: "monospace"
                    font.pixelSize: 15
                    tabStopDistance: editorMetrics.advanceWidth * 4
                    cursorVisible: activeFocus
                    focus: true
                    Accessible.name: "Note text"

                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => card.handleVimKey(event)

                    onTextChanged: card.dirty = text !== card.savedText
                    onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                    onSelectedTextChanged: card.syncVisualFromSelection()
                    onCursorPositionChanged: {
                        // Mouse clicks may land on a line break in normal mode.
                        if (card.normalMode && card.vimMode === "normal" && selectedText === "") {
                            const normal = Vim.normalPosition(text, cursorPosition)
                            if (normal !== cursorPosition) cursorPosition = normal
                        }
                    }

                    // Terminal-style cursor: a solid block in normal mode, a bar while inserting.
                    cursorDelegate: Rectangle {
                        readonly property bool block: card.normalMode
                        width: block ? Math.max(8, blockMetrics.advanceWidth) : 2
                        height: editor.cursorRectangle.height
                        color: block ? Qt.alpha(Theme.accent, 0.55) : Theme.accent
                        // Visual mode draws its own block at the moving end below.
                        visible: editor.activeFocus && card.vimMode !== "visual"
                    }

                    Rectangle {
                        objectName: "note-visual-cursor"
                        readonly property rect at: {
                            editor.text
                            editor.width
                            if (card.vimMode !== "visual") return Qt.rect(0, 0, 0, 0)
                            return editor.positionToRectangle(Math.min(card.visualCursor, editor.length))
                        }
                        visible: card.vimMode === "visual" && editor.activeFocus
                        x: at.x
                        y: at.y
                        width: Math.max(8, blockMetrics.advanceWidth)
                        height: at.height
                        color: Qt.alpha(Theme.accent, 0.55)
                    }
                }

                TextMetrics {
                    id: editorMetrics
                    font: editor.font
                    text: " "
                }

                TextMetrics {
                    id: blockMetrics
                    font: editor.font
                    text: {
                        const at = card.vimMode === "visual" ? card.visualCursor : editor.cursorPosition
                        const ch = editor.text.slice(at, Vim.nextCharacter(editor.text, at))
                        // A tab spans several columns; keep the block one cell wide.
                        return ch === "" || ch === "\n" || ch === "\t" ? " " : ch
                    }
                }
            }

            Flickable {
                id: previewFlick
                anchors.fill: flick
                visible: card.preview
                clip: true
                contentWidth: width
                contentHeight: previewText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {}

                TextEdit {
                    id: previewText
                    width: previewFlick.width - 8
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.MarkdownText
                    text: card.preview ? editor.text : ""
                    color: card.textColor
                    selectionColor: Theme.selected
                    font.family: card.family
                    font.pixelSize: 14
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            // With Vim off there is no status line; messages float at the bottom.
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                visible: !card.vimEnabled && card.message !== ""
                text: card.message
                color: card.messageError ? "#C0392B" : card.dimColor
                font.family: card.family
                font.pixelSize: 12
            }
        }

        MouseArea {
            objectName: "note-context-area"
            anchors.fill: editorFrame
            acceptedButtons: Qt.RightButton
            onClicked: mouse => {
                const point = mapToItem(card, mouse.x, mouse.y)
                contextMenu.popup(point.x, point.y)
            }
        }

        // Status line: Vim mode or command line on the left, position on the right.
        Item {
            id: statusLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            // Clear of the panel's bottom-right resize grip.
            anchors.rightMargin: 34
            anchors.bottomMargin: card.vimEnabled ? 12 : 0
            height: card.vimEnabled ? 28 : 6
            visible: card.vimEnabled

            // Each Vim mode has its own text color.
            readonly property color modeColor: card.vimMode === "insert" ? "#3FA34D"
                : card.vimMode === "replace" ? "#D9534F"
                : card.vimMode === "command" ? "#D08A1E"
                : card.vimMode === "visual" ? "#A65FC0" : "#4A86C8"

            Text {
                id: modeText
                objectName: "note-mode"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "-- " + (card.vimMode === "visual" && card.visualLine ? "VISUAL LINE"
                    : card.vimMode.toUpperCase()) + " --"
                color: statusLine.modeColor
                font.family: "monospace"
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Text {
                anchors.left: modeText.right
                anchors.leftMargin: 12
                anchors.right: positionText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: card.vimMode !== "command"
                text: card.message !== "" ? card.message
                    : (card.vimCount + card.vimPending) !== "" ? card.vimCount + card.vimPending
                    : card.filePath
                elide: Text.ElideMiddle
                color: card.messageError ? "#C0392B" : card.dimColor
                font.family: "monospace"
                font.pixelSize: 12
            }

            Row {
                anchors.left: modeText.right
                anchors.leftMargin: 12
                anchors.right: positionText.left
                anchors.verticalCenter: parent.verticalCenter
                visible: card.vimMode === "command"

                Text {
                    id: commandPrefix
                    text: ":"
                    color: card.textColor
                    font.family: "monospace"
                    font.pixelSize: 13
                }

                TextInput {
                    id: commandInput
                    objectName: "note-command"
                    width: parent.width - commandPrefix.width
                    color: card.textColor
                    selectionColor: Theme.selected
                    font.family: "monospace"
                    font.pixelSize: 13
                    clip: true
                    Keys.onReturnPressed: card.runCommandLine()
                    Keys.onEnterPressed: card.runCommandLine()
                    Keys.onEscapePressed: card.closeCommandLine()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace && text.length === 0) {
                            card.closeCommandLine()
                            event.accepted = true
                        }
                    }
                    onActiveFocusChanged: {
                        if (!activeFocus && card.vimMode === "command") card.vimMode = "normal"
                    }
                }
            }

            Text {
                id: positionText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: card.cursorLine + ":" + card.cursorColumn
                color: card.dimColor
                font.family: "monospace"
                font.pixelSize: 12
            }
        }

        Controls.Menu {
            id: contextMenu
            objectName: "note-menu"
            width: 224
            padding: 4
            closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
            onClosed: card.focusEditor()

            background: Rectangle {
                radius: 10
                color: Theme.cardSurface
                border.width: 1
                border.color: Theme.line
            }

            NoteMenuItem {
                objectName: "note-new"
                text: "New"
                shortcut: "Ctrl+N"
                onTriggered: card.newTab()
            }
            NoteMenuItem {
                objectName: "note-open"
                text: "Open"
                shortcut: "Ctrl+O"
                onTriggered: card.chooseFile("open")
            }
            NoteMenuItem {
                objectName: "note-save"
                text: "Save"
                shortcut: "Ctrl+S"
                onTriggered: card.save()
            }
            NoteMenuItem {
                objectName: "note-save-as"
                text: "Save as"
                shortcut: "Ctrl+Shift+S"
                onTriggered: card.chooseFile("save")
            }
            NoteMenuItem {
                objectName: "note-preview"
                text: card.preview ? "Edit markdown" : "Preview markdown"
                // Always listed; only Markdown files can be previewed.
                enabled: card.isMarkdown
                onTriggered: card.preview = !card.preview
            }

            // "Vim: on off" as plain text: the active choice is solid, the other
            // faded. Clicking the row toggles Vim and keeps the menu open.
            Rectangle {
                id: vimRow
                objectName: "note-vim-toggle"
                width: contextMenu.availableWidth
                height: 34
                radius: 7
                color: vimRowMouse.containsMouse ? Theme.controlHover : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "Vim:"
                        color: Theme.text
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                    }
                    Text {
                        objectName: "note-vim-on"
                        readonly property bool active: card.vimEnabled
                        text: "on"
                        color: Theme.text
                        opacity: active ? 1 : 0.35
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                    }
                    Text {
                        objectName: "note-vim-off"
                        readonly property bool active: !card.vimEnabled
                        text: "off"
                        color: Theme.text
                        opacity: active ? 1 : 0.35
                        font.family: Qt.application.font.family
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    id: vimRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: backend.setNoteVimEnabled(!card.vimEnabled)
                }
            }
        }

        function toggleMaximized() {
            const window = win.Window.window
            if (!window) return
            if (window.visibility === Window.Maximized) window.showNormal()
            else window.showMaximized()
        }

        // Unsaved-changes prompt for New, Open, and :wq-style closes.
        Item {
            id: unsavedPrompt
            objectName: "note-unsaved-prompt"
            anchors.fill: parent
            z: 20
            visible: card.pendingAction !== "" && !saveDialog.visible && !card.choosingFile
            enabled: visible
            // Take keyboard focus while shown so Esc cancels instead of reaching Vim.
            onVisibleChanged: if (visible) forceActiveFocus()
            Keys.onEscapePressed: card.cancelPrompt()

            Rectangle {
                anchors.fill: parent
                radius: card.cornerRadius
                // Dim with black so the backdrop darkens on light and dark themes alike.
                color: Qt.rgba(0, 0, 0, 0.45)
            }

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 360)
                height: 108
                radius: 18
                color: Theme.cardSurface
                border.width: Theme.cardBorderWidth
                border.color: Theme.cardBorder

                Text {
                    x: 20
                    y: 18
                    width: parent.width - 40
                    text: "Save changes to " + card.fileName + "?"
                    elide: Text.ElideMiddle
                    color: card.textColor
                    font.family: card.family
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    spacing: 6

                    NoteButton {
                        label: "Cancel"
                        onClicked: card.cancelPrompt()
                    }
                    NoteButton {
                        label: "Discard"
                        onClicked: card.runAction(card.pendingAction)
                    }
                    NoteButton {
                        label: "Save"
                        primary: true
                        onClicked: { if (card.save()) card.afterSave() }
                    }
                }
            }
        }
    }

    component NoteMenuItem: Controls.MenuItem {
        id: menuItem
        property string shortcut: ""
        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        hoverEnabled: true

        contentItem: Item {
            opacity: menuItem.enabled ? 1 : 0.35

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: menuItem.text
                color: Theme.text
                font.family: Qt.application.font.family
                font.pixelSize: 14
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: menuItem.shortcut
                color: Qt.alpha(Theme.text, 0.45)
                font.family: Qt.application.font.family
                font.pixelSize: 12
            }
        }
        background: Rectangle {
            radius: 7
            color: menuItem.hovered && menuItem.enabled ? Theme.controlHover : "transparent"
        }
    }

    component WindowButton: Rectangle {
        id: windowButton
        property string glyph: ""
        signal clicked()

        width: 24
        height: 24
        radius: 12
        color: buttonMouse.containsMouse ? Theme.controlHover : Qt.alpha(Theme.text, 0.08)

        Rectangle {
            visible: windowButton.glyph === "minimize"
            anchors.centerIn: parent
            width: 8
            height: 1.5
            color: Theme.text
        }
        Rectangle {
            visible: windowButton.glyph === "maximize"
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 1
            color: "transparent"
            border.width: 1.5
            border.color: Theme.text
        }
        FlatIcon {
            visible: windowButton.glyph === "close"
            anchors.centerIn: parent
            width: 12
            height: 12
            name: "close"
            ink: Theme.text
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: windowButton.clicked()
        }
    }

    component NoteButton: Rectangle {
        id: button
        property string label: ""
        property bool primary: false
        property bool active: false
        signal clicked()

        width: buttonLabel.implicitWidth + 24
        height: 30
        radius: 15
        color: primary || active ? Theme.accent
            : buttonHover.hovered ? Theme.controlHover : Theme.control
        scale: buttonHover.hovered ? 1.04 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.label
            color: button.primary || button.active ? Theme.accentText : Theme.text
            font.family: Qt.application.font.family
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        HoverHandler { id: buttonHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
