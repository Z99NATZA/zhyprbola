import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

function fixture() {
    const events = [];
    const windows = [];
    const idles = [];
    const context = vm.createContext({
        Extension: class {},
        PopupMenu: {PopupMenuManager: class {}},
        TextDecoder,
        GLib: {
            PRIORITY_DEFAULT_IDLE: 0,
            SOURCE_REMOVE: false,
            idle_add(_priority, callback) { idles.push(callback); return idles.length; },
        },
        global: {display: {list_all_windows: () => windows}},
    });
    const source = readFileSync(new URL('../gnome-extension/extension.js', import.meta.url), 'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export default class ZhyprbolaExtension',
            'globalThis.Dock = class ZhyprbolaExtension'), context);
    const dock = new context.Dock();
    dock._pinnedPanels = [];
    dock._panelWindows = new Set();
    dock._pinnedPanelSyncId = 0;
    const window = (name, title) => {
        const item = {
            minimized: false,
            above: false,
            get_title: () => title,
            is_above() { return this.above; },
            make_above() { this.above = true; events.push(`pin:${name}`); },
            unmake_above() { this.above = false; events.push(`unpin:${name}`); },
            raise() { events.push(`raise:${name}`); },
            connectObject(...args) { this.callbacks = args; },
            disconnectObject() {},
        };
        windows.push(item);
        return item;
    };
    const flush = () => {
        while (idles.length)
            idles.shift()();
    };
    return {dock, window, windows, events, flush};
}

test('pinned panels stay above ordinary windows in pin order', () => {
    const {dock, window, events} = fixture();
    window('chrome', 'Chrome');
    const clock = window('clock', 'Zhyprbola Clock & Weather');
    const keys = window('keys', 'Zhyprbola Key Visualizer');
    dock._pinnedPanels = ['clock-weather', 'key-visualizer'];
    dock._applyPinnedPanels();
    assert.deepEqual(events, [
        'pin:clock', 'raise:clock', 'pin:keys', 'raise:keys',
    ]);
    assert.equal(clock.above, true);
    assert.equal(keys.above, true);
});

test('unpin only removes the selected component from the above layer', () => {
    const {dock, window, events} = fixture();
    const clock = window('clock', 'Zhyprbola Clock & Weather');
    const keys = window('keys', 'Zhyprbola Key Visualizer');
    dock._pinnedPanels = ['clock-weather', 'key-visualizer'];
    dock._applyPinnedPanels();
    events.length = 0;
    dock._pinnedPanels = ['key-visualizer'];
    dock._applyPinnedPanels(['clock-weather']);
    assert.deepEqual(events, ['unpin:clock', 'raise:keys']);
    assert.equal(clock.above, false);
    assert.equal(keys.above, true);
});

test('pinning an already-above component later moves it to the top', () => {
    const {dock, window, events} = fixture();
    window('clock', 'Zhyprbola Clock & Weather');
    window('keys', 'Zhyprbola Key Visualizer');
    dock._pinnedPanels = ['clock-weather', 'key-visualizer'];
    dock._applyPinnedPanels();
    events.length = 0;
    dock._pinnedPanels = ['key-visualizer', 'clock-weather'];
    dock._applyPinnedPanels();
    assert.deepEqual(events, ['raise:keys', 'raise:clock']);
});

test('new component windows acquire their saved pin after the title appears', () => {
    const {dock, window, events, flush} = fixture();
    let title = '';
    const keys = window('keys', '');
    keys.get_title = () => title;
    dock._pinnedPanels = ['key-visualizer'];
    dock._watchPanelWindow(keys);
    flush();
    assert.equal(keys.above, false);
    title = 'Zhyprbola Key Visualizer';
    keys.callbacks[1]();
    flush();
    assert.deepEqual(events, ['pin:keys', 'raise:keys']);
});
