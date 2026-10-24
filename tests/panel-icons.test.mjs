import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';
import vm from 'node:vm';

const extensionDir = fileURLToPath(new URL('../gnome-extension/', import.meta.url));
const source = readFileSync(new URL('../gnome-extension/extension.js', import.meta.url), 'utf8');

function fixture() {
    const reads = [], created = [], errors = [];
    let failRead = false;
    const context = vm.createContext({
        Extension: class {}, PopupMenu: {PopupMenuManager: class {}},
        TextEncoder, TextDecoder,
        GLib: {
            build_filenamev: parts => parts.join('/'),
            file_get_contents(path) {
                reads.push(path);
                if (failRead) throw new Error('Temporary read failure');
                return [true, readFileSync(path)];
            },
            Bytes: class { constructor(bytes) { this.bytes = bytes; } },
        },
        Gio: {
            BytesIcon: {new(bytes) {
                const icon = {svg: new TextDecoder().decode(bytes.bytes)};
                created.push(icon);
                return icon;
            }},
            File: {new_for_path: path => path},
            FileIcon: class { constructor({file}) { this.file = file; } },
        },
        logError: error => errors.push(error),
    });
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export default class ZhyprbolaExtension', 'globalThis.Dock = class ZhyprbolaExtension'), context);
    const dock = new context.Dock();
    dock.path = extensionDir;
    dock._panelIconSources = new Map();
    dock._panelGicons = new Map();
    return {dock, reads, created, errors, failReads: value => { failRead = value; }};
}

test('repeated use of the same component and color shares one icon and one source read', () => {
    const {dock, reads, created} = fixture();
    const icon = dock._panelGicon('settings', '#be345f');
    for (let i = 0; i < 100; i++)
        assert.equal(dock._panelGicon('settings', '#be345f'), icon);
    assert.equal(reads.length, 1);
    assert.equal(created.length, 1);
});

test('colors stay independent and switching themes back reuses the original icon', () => {
    const {dock, reads, created} = fixture();
    const white = dock._panelGicon('settings');
    const accent = dock._panelGicon('settings', '#be345f');
    assert.notEqual(white, accent);
    assert.match(white.svg, /fill="#ffffff"/);
    assert.match(accent.svg, /fill="#be345f"/);
    assert.equal(dock._panelGicon('settings', '#BE345F'), accent);
    assert.equal(dock._panelGicon('settings'), white);
    assert.equal(reads.length, 1);
    assert.equal(created.length, 2);
});

test('strong Wi-Fi shares the regular artwork while other signal states stay distinct', () => {
    const {dock, reads, created} = fixture();
    const strong = dock._panelGicon('wifi-strong');
    assert.equal(dock._panelGicon('wifi'), strong);
    assert.notEqual(dock._panelGicon('wifi-weak'), strong);
    assert.equal(reads.length, 2);
    assert.ok(reads[0].endsWith('/icons/wifi.svg'));
    assert.equal(created.length, 2);
});

test('a failed read uses the existing fallback without poisoning subsequent cache entries', () => {
    const {dock, reads, errors, failReads} = fixture();
    failReads(true);
    assert.ok(dock._panelGicon('settings').file.endsWith('/icons/settings.svg'));
    failReads(false);
    const icon = dock._panelGicon('settings');
    assert.equal(dock._panelGicon('settings'), icon);
    assert.match(icon.svg, /<svg/);
    assert.equal(reads.length, 2);
    assert.equal(errors.length, 1);
});
