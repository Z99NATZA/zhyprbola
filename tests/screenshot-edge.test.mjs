import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

function fixture() {
    const monitor = {index: 1, x: 1920, y: 0, width: 2560, height: 1440};
    const windows = [], timers = new Map(), calls = [], animations = [], connections = new Map();
    const skippedActors = new Set();
    let config = {}, desktopConfig = {}, appeared, dismissed, cancelled = false;
    let launched = 0, nextTimer = 0;
    const changed = [];
    const process = {wait_async(_cancel, callback) { this.finished = callback; }, wait_finish() {}, force_exit() { this.killed = true; }};
    const context = vm.createContext({
        TextDecoder, logError: error => { throw error; },
        Clutter: {AnimationMode: {EASE_OUT_QUAD: 1}, EventType: {BUTTON_PRESS: 1, TOUCH_BEGIN: 2}, EVENT_PROPAGATE: 0},
        St: {Button: class {
            connect(name, callback) {
                if (name === 'clicked') this.click = callback;
                if (name === 'notify::hover') this.hoverChanged = callback;
            }
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
                connect: (_name, callback) => { changed.push(callback); }, cancel: () => { cancelled = true; },
            })})}},
        GLib: {build_filenamev: parts => parts.join('/'), get_user_config_dir: () => '/config',
            file_get_contents: path => [true, new TextEncoder().encode(JSON.stringify(
                path.endsWith('show-desktop-edge') ? desktopConfig : config))],
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
        .replace('export function edgeHandleGeometries',
            'globalThis.edgeHandleGeometries = function edgeHandleGeometries')
        .replace('export function showDesktopEdgeGeometry',
            'globalThis.showDesktopEdgeGeometry = function showDesktopEdgeGeometry')
        .replace('export class ShowDesktopEdge',
            'globalThis.ShowDesktopEdge = class ShowDesktopEdge')
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
        configure: value => {
            config = value;
            for (const callback of changed)
                callback(null, {get_basename: () => 'screenshots-edge'});
        },
        configureDesktop: value => {
            desktopConfig = value;
            for (const callback of changed)
                callback(null, {get_basename: () => 'show-desktop-edge'});
        }};
}

test('show desktop handle shares the selected slot with Screenshots', () => {
    const {context, monitor, configure} = fixture();
    let toggles = 0;
    const handle = new context.ShowDesktopEdge(() => toggles++, () => '#be345f');
    assert.equal(context.Main.layoutManager.chrome.trackFullscreen, false);
    for (const side of ['left', 'right']) for (const alignment of ['top', 'center', 'bottom']) {
        configure({side, alignment});
        const geometry = context.edgeHandleGeometries(monitor, {side, alignment});
        assert.equal(handle._button.width, 5);
        assert.equal(handle._button.height, 50);
        assert.equal(handle._button.x, side === 'left' ? monitor.x : monitor.x + monitor.width - 5);
        assert.equal(handle._button.y, geometry.showDesktop.y);
    }
    assert.match(handle._button.style, /#be345f/);
    handle._button.click();
    assert.equal(toggles, 1);
    handle.setChecked(true);
    assert.equal(handle._button.opacity, 225);
    handle._button.hover = true;
    handle._button.hoverChanged();
    assert.equal(handle._button.opacity, 255);
    handle.destroy();
    assert.equal(handle._button.destroyed, true);
});

test('show desktop sizes rotate on horizontal edges and avoid the dock side', () => {
    const {context, monitor, configure, configureDesktop} = fixture();
    let dockPosition = 'left';
    const handle = new context.ShowDesktopEdge(() => {}, () => '#be345f',
        () => dockPosition, () => 27);
    configure({side: 'left', alignment: 'center'});

    configureDesktop({position: 'left', width: 'lg', height: 'md'});
    assert.deepEqual({x: handle._button.x, y: handle._button.y,
        width: handle._button.width, height: handle._button.height},
    {x: monitor.x + 27, y: 737, width: 12, height: 75});

    dockPosition = 'top';
    configureDesktop({position: 'top', width: 'md', height: 'lg', alignment: 'top'});
    assert.deepEqual({x: handle._button.x, y: handle._button.y,
        width: handle._button.width, height: handle._button.height},
    {x: 2297, y: 27, width: 100, height: 8});

    dockPosition = 'bottom';
    configureDesktop({position: 'bottom', width: 'lg', height: 'md', alignment: 'bottom'});
    assert.deepEqual({x: handle._button.x, y: handle._button.y,
        width: handle._button.width, height: handle._button.height},
    {x: 4016, y: 1401, width: 75, height: 12});
});

test('edge handles form a compact centered group inside a slot and can swap order', () => {
    const {context, monitor} = fixture();
    const screenshots = {side: 'left', alignment: 'center'};
    const settings = {position: 'left', width: 'lg', height: 'md',
        alignment: 'center', order: 'screenshots-first'};

    let geometry = context.edgeHandleGeometries(
        monitor, screenshots, settings, 'left', 27);
    assert.deepEqual({...geometry.screenshots},
        {x: monitor.x + 27, y: 629, width: 5, height: 100});
    assert.deepEqual({...geometry.showDesktop},
        {x: monitor.x + 27, y: 737, width: 12, height: 75});

    settings.order = 'show-desktop-first';
    geometry = context.edgeHandleGeometries(monitor, screenshots, settings, 'left', 27);
    assert.deepEqual({...geometry.showDesktop},
        {x: monitor.x + 27, y: 629, width: 12, height: 75});
    assert.deepEqual({...geometry.screenshots},
        {x: monitor.x + 27, y: 712, width: 5, height: 100});
});

test('show desktop center remains independent from the Screenshots slot', () => {
    const {context, monitor} = fixture();
    const geometry = context.edgeHandleGeometries(monitor,
        {side: 'left', alignment: 'top'},
        {position: 'left', width: 'sm', height: 'sm', alignment: 'center'},
        'bottom', 27);

    assert.deepEqual({...geometry.screenshots},
        {x: monitor.x, y: 190, width: 5, height: 100});
    assert.deepEqual({...geometry.showDesktop},
        {x: monitor.x, y: 695, width: 5, height: 50});
});

test('handle stays visible in fullscreen and follows the three position slots', () => {
    const {edge, context, monitor, configure, configureDesktop} = fixture();
    assert.equal(context.Main.layoutManager.chrome.trackFullscreen, false);
    configureDesktop({position: 'top', alignment: 'center'});
    for (const side of ['left', 'right']) for (const alignment of ['top', 'center', 'bottom']) {
        configure({side, alignment});
        assert.equal(edge._button.width, 5);
        assert.equal(edge._button.height, 100);
        assert.equal(edge._button.x, side === 'left' ? monitor.x : monitor.x + monitor.width - 5);
        assert.equal(edge._button.y,
            alignment === 'top' ? 190 : alignment === 'bottom' ? 1150 : 670);
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
