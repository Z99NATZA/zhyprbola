import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

function fixture() {
    const monitor = {index: 1, x: 1920, y: 0, width: 2560, height: 1440};
    const windows = [], timers = new Map(), calls = [], animations = [], connections = new Map();
    const skippedActors = new Set();
    let config = {}, changed, appeared, dismissed, cancelled = false, launched = 0, nextTimer = 0;
    const process = {wait_async(_cancel, callback) { this.finished = callback; }, wait_finish() {}, force_exit() { this.killed = true; }};
    const context = vm.createContext({
        TextDecoder, logError: error => { throw error; },
        Clutter: {AnimationMode: {EASE_OUT_QUAD: 1}, EventType: {BUTTON_PRESS: 1, TOUCH_BEGIN: 2}, EVENT_PROPAGATE: 0},
        St: {Button: class {
            connect(name, callback) { if (name === 'clicked') this.click = callback; }
            set_style(style) { this.style = style; }
            set_position(x, y) { this.x = x; this.y = y; }
            set_size(width, height) { this.width = width; this.height = height; }
            destroy() { this.destroyed = true; }
        }},
        Gio: {BusType: {SESSION: 0}, BusNameWatcherFlags: {NONE: 0}, DBusCallFlags: {NONE: 0},
            DBusSignalFlags: {NONE: 0}, FileMonitorFlags: {NONE: 0},
            bus_watch_name: (_type, _name, _flags, callback) => { appeared = callback; return 1; },
            bus_unwatch_name() {},
            DBus: {session: {
                signal_subscribe: (...args) => { dismissed = args.at(-1); return 1; }, signal_unsubscribe() {},
                call: (...args) => { calls.push(args[3]); args.at(-1)({call_finish() {}}, {}); },
            }},
            File: {new_for_path: () => ({monitor_directory: () => ({
                connect: (_name, callback) => { changed = callback; }, cancel: () => { cancelled = true; },
            })})}},
        GLib: {build_filenamev: parts => parts.join('/'), get_user_config_dir: () => '/config',
            file_get_contents: () => [true, new TextEncoder().encode(JSON.stringify(config))],
            mkdir_with_parents() {}, PRIORITY_DEFAULT: 0, SOURCE_REMOVE: false, SOURCE_CONTINUE: true,
            timeout_add: (_priority, _interval, callback) => { const id = ++nextTimer; timers.set(id, callback); return id; },
            source_remove: id => timers.delete(id)},
        Main: {wm: {skipNextEffect: actor => skippedActors.add(actor)},
            layoutManager: {primaryMonitor: monitor, addTopChrome(_button, options) { this.chrome = options; },
            removeChrome() {}, getWorkAreaForMonitor: () => ({...monitor, height: 1400})},
            activateWindow: window => { window.activated = true; }},
        global: {
            stage: {connect: (_name, callback) => { connections.set('click', callback); return 1; },
                disconnect: () => connections.delete('click')},
            display: {list_all_windows: () => windows,
                connect: (_name, callback) => { connections.set('focus', callback); return 1; },
                disconnect: () => connections.delete('focus')},
        },
    });
    const source = readFileSync(new URL('../gnome-extension/screenshotEdge.js', import.meta.url), 'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export function edgeGeometry', 'globalThis.edgeGeometry = function edgeGeometry')
        .replace('export class ScreenshotEdge', 'globalThis.ScreenshotEdge = class ScreenshotEdge'), context);
    const edge = new context.ScreenshotEdge(() => { launched++; return process; });
    const actor = {mapped: true, set_pivot_point(x, y) { this.pivot = {x, y}; },
        remove_all_transitions() {}, ease(options) { animations.push(options); }};
    const window = {get_title: () => 'Zhyprbola Screenshots', get_compositor_private: () => actor,
        get_frame_rect: () => window.frame ?? {x: 0, y: 0, width: 600, height: 564},
        move_resize_frame: (_user, x, y, width, height) => { window.frame = {x, y, width, height}; }};
    const map = () => {
        if (!windows.includes(window)) windows.push(window);
        for (const [id, callback] of [...timers]) if (!callback()) timers.delete(id);
    };
    return {edge, context, monitor, window, actor, windows, timers, calls, animations, connections, process, skippedActors,
        map, launched: () => launched, ready: () => appeared(), dismissed: () => dismissed(),
        cancelled: () => cancelled, click: (x, y) => connections.get('click')(null, {type: () => 1, get_coords: () => [x, y]}),
        configure: value => { config = value; changed(null, {get_basename: () => 'screenshots-edge'}); }};
}

test('handle stays visible in fullscreen and uses space-around at every position', () => {
    const {edge, context, monitor, configure} = fixture();
    assert.equal(context.Main.layoutManager.chrome.trackFullscreen, false);
    for (const side of ['left', 'right']) for (const alignment of ['top', 'center', 'bottom']) {
        configure({side, alignment});
        assert.equal(edge._button.width, 5);
        assert.equal(edge._button.height, 100);
        assert.equal(edge._button.x, side === 'left' ? monitor.x : monitor.x + monitor.width - 5);
        assert.equal(edge._button.y, alignment === 'top' ? 190 : alignment === 'bottom' ? 1150 : 670);
    }
});

test('prewarmed process queues opening until D-Bus is ready and is reused after hiding', () => {
    const {edge, window, ready, map, calls, animations, launched, configure} = fixture();
    assert.equal(launched(), 1);
    edge.toggle();
    assert.equal(calls.length, 0);
    ready();
    map();
    assert.equal(calls[0], 'Show');
    assert.equal(window.activated, true);
    edge.hide();
    animations.at(-1).onComplete();
    assert.equal(calls.at(-1), 'Hide');
    configure({side: 'right', alignment: 'bottom'});
    edge.toggle();
    map();
    assert.equal(launched(), 1);
    assert.equal(calls.at(-1), 'Show');
    assert.deepEqual(window.frame, {x: 3880, y: 824, width: 600, height: 564});
});

test('a rapid reopen invalidates the previous collapse callback', () => {
    const {edge, ready, map, animations, calls} = fixture();
    ready(); edge.toggle(); map();
    edge.hide();
    const stale = animations.at(-1).onComplete;
    edge.toggle(); map();
    stale();
    assert.equal(calls.at(-1), 'Show');
    assert.equal(edge._desiredOpen, true);
});

test('collapse suppresses the second native closing effect only for the screenshots actor', () => {
    const {edge, ready, map, actor, animations, calls, skippedActors} = fixture();
    ready(); edge.toggle(); map();
    // The effect is armed even when QML hides directly on Escape.
    assert.equal(skippedActors.delete(actor), true);
    edge.hide();
    assert.equal(calls.at(-1), 'Show');
    animations.at(-1).onComplete();
    assert.equal(calls.at(-1), 'Hide');
    assert.deepEqual([...skippedActors], [actor]);
    assert.equal(skippedActors.has({}), false);
});

test('outside clicks hide the panel while preserving the click for other apps', () => {
    const {edge, ready, map, click, animations, calls} = fixture();
    ready(); edge.toggle(); map();
    assert.equal(click(2000, 600), 0);
    assert.equal(edge._desiredOpen, true);
    assert.equal(click(3000, 600), 0);
    assert.equal(edge._desiredOpen, false);
    animations.at(-1).onComplete();
    assert.equal(calls.at(-1), 'Hide');
});

test('focus moving to another application also hides, without a modal grab', () => {
    const {edge, context, window, ready, map, connections} = fixture();
    ready(); edge.toggle(); map();
    context.global.display.focus_window = window;
    connections.get('focus')();
    context.global.display.focus_window = {};
    connections.get('focus')();
    assert.equal(edge._desiredOpen, false);
});

test('Escape dismissal resets state and disable cleans up its own process and listeners', () => {
    const {edge, ready, map, dismissed, calls, timers, cancelled, connections} = fixture();
    ready(); edge.toggle(); map();
    dismissed();
    assert.equal(edge._desiredOpen, false);
    edge.destroy();
    assert.equal(calls.at(-1), 'Quit');
    assert.equal(timers.size, 0);
    assert.equal(cancelled(), true);
    assert.equal(connections.size, 0);
    assert.equal(edge._button.destroyed, true);
});

test('space-around gives equal inner gaps and half-sized outer gaps', () => {
    const {context} = fixture();
    const monitor = {x: 100, y: 200, width: 1920, height: 1440};
    const top = context.edgeGeometry(monitor, 'left', 'top');
    const center = context.edgeGeometry(monitor, 'left', 'center');
    const bottom = context.edgeGeometry(monitor, 'left', 'bottom');
    const outer = top.y - monitor.y;
    assert.equal(center.y - top.y - top.height, outer * 2);
    assert.equal(bottom.y - center.y - center.height, outer * 2);
    assert.equal(monitor.y + monitor.height - bottom.y - bottom.height, outer);
});
