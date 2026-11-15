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

// Keyword under or after the cursor on its line, for "*" and "#".
function keywordAt(text, position, isWordCharacter) {
    const end = lineEnd(text, position)
    let cursor = position
    while (cursor < end && TaskVim.characterKind(text, cursor, isWordCharacter) !== 1)
        cursor = nextCharacter(text, cursor)
    if (cursor >= end) return null
    return innerWord(text, cursor, isWordCharacter)
}

function isWholeWord(text, index, length, isWordCharacter) {
    if (index > 0 && TaskVim.characterKind(text, previousCharacter(text, index), isWordCharacter) === 1)
        return false
    const end = index + length
    return end >= text.length || TaskVim.characterKind(text, end, isWordCharacter) !== 1
}

// Whole-word search that wraps around the document, like Vim's \<word\>.
function findWord(text, needle, position, forward, isWordCharacter) {
    if (needle.length === 0) return -1
    const whole = index => isWholeWord(text, index, needle.length, isWordCharacter)
    const before = index => index > 0 ? text.lastIndexOf(needle, index - 1) : -1
    if (forward) {
        for (let i = text.indexOf(needle, position + 1); i >= 0; i = text.indexOf(needle, i + 1))
            if (whole(i)) return i
        for (let i = text.indexOf(needle); i >= 0 && i <= position; i = text.indexOf(needle, i + 1))
            if (whole(i)) return i
    } else {
        for (let i = before(position); i >= 0; i = before(i))
            if (whole(i)) return i
        for (let i = text.lastIndexOf(needle); i >= 0 && i >= position; i = before(i))
            if (whole(i)) return i
    }
    return -1
}

// One ">>" or "<<" step: a tab when the indent starts with one, else four spaces.
function shiftLine(line, direction) {
    if (direction > 0) return line.length === 0 ? line : (line[0] === "\t" ? "\t" : "    ") + line
    if (line[0] === "\t") return line.slice(1)
    let count = 0
    while (count < 4 && line[count] === " ") count += 1
    return line.slice(count)
}

// Move the cursor's line `delta` lines down (positive) or up, keeping its
// column. Returns the region to replace, or null at the document edge.
function moveLine(text, position, delta) {
    const start = lineStart(text, position)
    const end = lineEnd(text, position)
    const current = text.slice(start, end)
    const offset = position - start
    if (delta > 0) {
        if (end >= text.length) return null
        let last = end
        for (let step = 0; step < delta && last < text.length; ++step) last = lineEnd(text, last + 1)
        const below = text.slice(end + 1, last)
        return {start: start, end: last, text: below + "\n" + current, cursor: start + below.length + 1 + offset}
    }
    if (start === 0) return null
    let first = start
    for (let step = 0; step < -delta && first > 0; ++step) first = lineStart(text, first - 1)
    const above = text.slice(first, start - 1)
    return {start: first, end: end, text: current + "\n" + above, cursor: first + offset}
}

// Text typed during one insert or replace session, as an edit relative to
// where it started: `back` units removed before it, `forward` after it, then
// `text` inserted. Used to replay the session with ".".
function insertEdit(before, after, start) {
    let prefix = 0
    const prefixLimit = Math.min(start, before.length, after.length)
    while (prefix < prefixLimit && before.charCodeAt(prefix) === after.charCodeAt(prefix)) prefix += 1
    let suffix = 0
    const suffixLimit = Math.min(before.length - start, after.length - prefix)
    while (suffix < suffixLimit
        && before.charCodeAt(before.length - 1 - suffix) === after.charCodeAt(after.length - 1 - suffix))
        suffix += 1
    return {back: start - prefix, forward: before.length - suffix - start,
        text: after.slice(prefix, after.length - suffix)}
}
