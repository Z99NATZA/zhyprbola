import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

test('AT-SPI forwards held-key repeats and stops when the parent closes', () => {
    const listeners = new Map();
    const output = [];
    let parentClosed;
    let loopQuit = false;
    const device = {
        get_capabilities: () => 1,
        connect: (name, callback) => listeners.set(name, callback),
    };
    const context = vm.createContext({
        Atspi: {
            init() {},
            Device: {new: () => device},
            DeviceCapability: {KEYBOARD_MONITOR: 1},
            ModifierType: {SHIFT: 0, CONTROL: 2, ALT: 3, SUPER: 6},
        },
        Gdk: {
            keyval_name: keysym => keysym === 0x1000e01 ? 'Thai_kokai' : 'a',
            keyval_to_unicode: keysym => keysym === 0x1000e01 ? 0x0e01 : keysym,
        },
        Gio: {
            DBus: {session: {call_sync: () => ({})}},
            DBusCallFlags: {NONE: 0},
        },
        GLib: {
            MainLoop: class { run() {} quit() { loopQuit = true; } },
            IOChannel: {unix_new: () => ({})},
            IOCondition: {HUP: 16, ERR: 8},
            PRIORITY_DEFAULT: 0,
            SOURCE_REMOVE: false,
            io_add_watch: (_channel, _priority, _condition, callback) => {
                parentClosed = callback;
            },
        },
        print: line => output.push(JSON.parse(line)),
    });
    const source = readFileSync(new URL('../scripts/key-capture.js', import.meta.url), 'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, ''), context);

    assert.equal(output[0].type, 'ready');
    listeners.get('key-pressed')(device, 38, 0x61, 1 << 2, '\x01');
    assert.equal(output[1].text, 'a');
    assert.equal(output[1].ctrl, true);
    listeners.get('key-pressed')(device, 38, 0x61, 1 << 2, '\x01');
    assert.equal(output.length, 3);
    assert.equal(output[2].type, 'press');
    assert.equal(output[2].text, 'a');
    assert.equal(output[2].ctrl, true);
    listeners.get('key-released')(device, 38, 0x61, 0, '');
    listeners.get('key-pressed')(device, 38, 0x1000e01, 0, 'ก');
    assert.equal(output.at(-1).text, 'ก');
    assert.equal(parentClosed(), false);
    assert.equal(loopQuit, true);
});

test('denied keyboard monitor never reports ready', () => {
    const output = [];
    const context = vm.createContext({
        Atspi: {
            init() {},
            Device: {new: () => ({get_capabilities: () => 1})},
            DeviceCapability: {KEYBOARD_MONITOR: 1},
        },
        Gio: {
            DBus: {session: {call_sync: () => { throw new Error('Access denied'); }}},
            DBusCallFlags: {NONE: 0},
        },
        print: line => output.push(JSON.parse(line)),
    });
    const source = readFileSync(new URL('../scripts/key-capture.js', import.meta.url), 'utf8');
    assert.throws(() => vm.runInContext(source.replace(/^import .*;\n/gm, ''), context),
        /Global keyboard monitoring was denied: Access denied/);
    assert.deepEqual(output, []);
});
