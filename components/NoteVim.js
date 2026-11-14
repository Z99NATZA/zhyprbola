.pragma library
.import "TaskVim.js" as TaskVim

// Multi-line helpers for the Note editor's Vim mode. Positions are UTF-16
// offsets into the whole document; character steps reuse TaskVim so surrogate
// pairs move as one character.

function nextCharacter(text, position) { return TaskVim.nextCharacter(text, position) }
function previousCharacter(text, position) { return TaskVim.previousCharacter(text, position) }

function lineStart(text, position) {
    if (position <= 0) return 0
    return text.lastIndexOf("\n", position - 1) + 1
}

function lineEnd(text, position) {
    const index = text.indexOf("\n", position)
    return index < 0 ? text.length : index
}

// Normal mode never rests on a line break unless the line is empty.
function normalPosition(text, position) {
    const clamped = Math.max(0, Math.min(position, text.length))
    const start = lineStart(text, clamped)
    const end = lineEnd(text, clamped)
    if (end <= start) return start
    return Math.max(start, Math.min(clamped, previousCharacter(text, end)))
}

function column(text, position) { return position - lineStart(text, position) }

function lineIndex(text, position) {
    let count = 0
    let index = text.indexOf("\n")
    while (index >= 0 && index < position) {
        count += 1
        index = text.indexOf("\n", index + 1)
    }
    return count
}

function lineCount(text) {
    let count = 1
    let index = text.indexOf("\n")
    while (index >= 0) {
        count += 1
        index = text.indexOf("\n", index + 1)
    }
    return count
}

function lineStartAt(text, index) {
    let position = 0
    for (let line = 0; line < index; ++line) {
        const end = text.indexOf("\n", position)
        if (end < 0) break
        position = end + 1
    }
    return position
}

function verticalMove(text, position, delta, goalColumn) {
    let target = lineStart(text, position)
    if (delta > 0) {
        for (let step = 0; step < delta; ++step) {
            const end = lineEnd(text, target)
            if (end >= text.length) break
            target = end + 1
        }
    } else {
        for (let step = 0; step < -delta && target > 0; ++step)
            target = lineStart(text, target - 1)
    }
    return normalPosition(text, Math.min(target + goalColumn, lineEnd(text, target)))
}

function firstNonBlankRaw(text, position) {
    const end = lineEnd(text, position)
    let index = lineStart(text, position)
    while (index < end && (text[index] === " " || text[index] === "\t")) index += 1
    return index
}

function firstNonBlank(text, position) {
    return normalPosition(text, firstNonBlankRaw(text, position))
}

function wordForward(text, position, isWordCharacter) {
    return TaskVim.wordForward(text, position, isWordCharacter)
}

// Unclamped "w" target for operators: may land on a line break or text end.
function wordForwardRaw(text, position, isWordCharacter) {
    let cursor = position
    if (cursor >= text.length) return text.length
    const kind = TaskVim.characterKind(text, cursor, isWordCharacter)
    while (cursor < text.length && TaskVim.characterKind(text, cursor, isWordCharacter) === kind)
        cursor = nextCharacter(text, cursor)
    while (cursor < text.length && TaskVim.characterKind(text, cursor, isWordCharacter) === 0)
        cursor = nextCharacter(text, cursor)
    return cursor
}

function wordBackward(text, position, isWordCharacter) {
    return TaskVim.wordBackward(text, position, isWordCharacter)
}

function wordEnd(text, position, isWordCharacter) {
    let cursor = nextCharacter(text, position)
    while (cursor < text.length && TaskVim.characterKind(text, cursor, isWordCharacter) === 0)
        cursor = nextCharacter(text, cursor)
    if (cursor >= text.length) return normalPosition(text, text.length)
    const kind = TaskVim.characterKind(text, cursor, isWordCharacter)
    let next = nextCharacter(text, cursor)
    while (next < text.length && TaskVim.characterKind(text, next, isWordCharacter) === kind) {
        cursor = next
        next = nextCharacter(text, cursor)
    }
    return cursor
}

function innerWord(text, position, isWordCharacter) {
    // Keep the object on the cursor's line, as Vim does.
    const start = lineStart(text, position)
    const end = lineEnd(text, position)
    const line = text.slice(start, end)
    const range = TaskVim.innerWord(line, position - start, isWordCharacter)
    return {start: start + range.start, end: start + range.end}
}

// Range covering `count` whole lines from the cursor's line, plus the line
// text for a linewise register.
function lineRange(text, position, count) {
    const start = lineStart(text, position)
    let end = lineEnd(text, position)
    for (let line = 1; line < count && end < text.length; ++line)
        end = lineEnd(text, end + 1)
    let removeStart = start
    let removeEnd = end
    if (end < text.length) removeEnd = end + 1
    else if (start > 0) removeStart = start - 1
    return {start: start, end: end, removeStart: removeStart, removeEnd: removeEnd,
        text: text.slice(start, end) + "\n"}
}

function findForward(text, needle, position) {
    if (needle.length === 0) return -1
    const index = text.indexOf(needle, position + 1)
    return index >= 0 ? index : text.indexOf(needle)
}

function findBackward(text, needle, position) {
    if (needle.length === 0) return -1
    const index = position > 0 ? text.lastIndexOf(needle, position - 1) : -1
    return index >= 0 ? index : text.lastIndexOf(needle)
}
