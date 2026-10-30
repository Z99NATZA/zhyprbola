.pragma library

function nextCharacter(text, position) {
    if (position >= text.length) return text.length
    const point = text.codePointAt(position)
    return Math.min(text.length, position + (point > 0xffff ? 2 : 1))
}

function previousCharacter(text, position) {
    if (position <= 0) return 0
    const last = text.charCodeAt(position - 1)
    return position - (last >= 0xdc00 && last <= 0xdfff && position > 1 ? 2 : 1)
}

function normalPosition(text, position) {
    return Math.max(0, Math.min(position, previousCharacter(text, text.length)))
}

function characterKind(text, position, isWordCharacter) {
    const character = text.slice(position, nextCharacter(text, position))
    if (/\s/.test(character)) return 0
    return isWordCharacter(character) ? 1 : 2
}

function wordForward(text, position, isWordCharacter) {
    let cursor = position
    const kind = characterKind(text, cursor, isWordCharacter)
    while (cursor < text.length && characterKind(text, cursor, isWordCharacter) === kind)
        cursor = nextCharacter(text, cursor)
    while (cursor < text.length && characterKind(text, cursor, isWordCharacter) === 0)
        cursor = nextCharacter(text, cursor)
    return normalPosition(text, cursor)
}

function wordBackward(text, position, isWordCharacter) {
    let cursor = previousCharacter(text, position)
    while (cursor > 0 && characterKind(text, cursor, isWordCharacter) === 0)
        cursor = previousCharacter(text, cursor)
    const kind = characterKind(text, cursor, isWordCharacter)
    while (cursor > 0 && characterKind(text, previousCharacter(text, cursor), isWordCharacter) === kind)
        cursor = previousCharacter(text, cursor)
    return cursor
}

function innerWord(text, position, isWordCharacter) {
    if (text.length === 0) return {start: 0, end: 0}
    let start = normalPosition(text, position)
    let end = nextCharacter(text, start)
    const kind = characterKind(text, start, isWordCharacter)
    while (start > 0 && characterKind(text, previousCharacter(text, start), isWordCharacter) === kind)
        start = previousCharacter(text, start)
    while (end < text.length && characterKind(text, end, isWordCharacter) === kind)
        end = nextCharacter(text, end)
    return {start: start, end: end}
}
