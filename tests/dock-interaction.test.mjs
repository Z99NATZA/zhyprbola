import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

// Run the extension's event handlers without a desktop session. The actors
// reject access after destruction, like the St.Button in the original log.
class Actor {
    constructor(props = {}) {
        Object.assign(this, {children: [], signals: new Map(), pressed: false,
            translation_x: 0, translation_y: 0}, props);
        if (props.child)
            this.add_child(props.child);
    }
    connect(name, callback) {
        const callbacks = this.signals.get(name) ?? [];
        callbacks.push(callback);
        this.signals.set(name, callbacks);
    }
    emit(name) {
        for (const callback of this.signals.get(name) ?? [])
            callback(this);
    }
    live() { assert.equal(this.destroyed, undefined, 'access to disposed actor'); }
    get_parent() { this.live(); return this.parent; }
    get_children() { this.live(); return [...this.children]; }
    add_child(child) { this.insert_child_at_index(child, this.children.length); }
    insert_child_at_index(child, index) {
        this.live(); child.live();
        child.parent = this;
        this.children.splice(index, 0, child);
    }
    set_child_at_index(child, index) {
        this.live(); child.live();
        this.children.splice(this.children.indexOf(child), 1);
        this.children.splice(index, 0, child);
    }
    destroy() {
        this.live();
        this.emit('destroy');
        for (const child of [...this.children])
            child.destroy();
        if (this.parent)
            this.parent.children.splice(this.parent.children.indexOf(this), 1);
        this.destroyed = true;
    }
    set_size(width, height) { this.live(); Object.assign(this, {width, height}); }
    set_position(x, y) { this.live(); Object.assign(this, {x, y}); }
    set_style() { this.live(); }
    add_style_class_name() { this.live(); }
    remove_style_class_name() { this.live(); }
    ease(props) { this.live(); Object.assign(this, props); }
}

function fixture(length = 400) {
    const idles = new Map();
    let nextId = 0;
    const context = vm.createContext({
        St: {Widget: Actor, Icon: Actor, Button: Actor},
        Clutter: {FixedLayout: class {}, AnimationMode: {EASE_OUT_QUAD: 0}},
        DND: {makeDraggable: actor => (actor.draggable = new Actor())},
        GLib: {PRIORITY_DEFAULT_IDLE: 0, SOURCE_REMOVE: false,
            idle_add: (_, callback) => { idles.set(++nextId, callback); return nextId; }},
        Main: {layoutManager: {primaryMonitor: {x: 0, y: 0, width: length + 8, height: 900},
            removeChrome() {}}},
        Extension: class {},
    });
    const source = readFileSync(new URL('../gnome-extension/extension.js', import.meta.url), 'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export default class ZhyprbolaExtension', 'globalThis.Dock = class ZhyprbolaExtension'), context);
    const dock = new context.Dock();
    const group = new Actor();
    dock._dock = new Actor();
    dock._dock.add_child(group);
    Object.assign(dock, {
        _dockPosition: 'bottom', _dockInteractions: new Set(), _dockRebuildPending: false,
        _dockGroupsByName: new Map([['running', group]]), _dockGroupOrder: ['running'],
        _dockRegions: new Map([['running', new Actor()]]),
        _dockItems: new Map([['running', []]]), _dockRenderState: new Map(),
        _showDesktopButton: new Actor(), _panelIcons: new Map(),
        _layoutEdgeSpectrum() {},
    });
    const flush = () => {
        while (idles.size) {
            const callbacks = [...idles.values()];
            idles.clear();
            for (const callback of callbacks)
                callback();
        }
    };
    const render = items => {
        dock._dockItems.set('running', items);
        dock._queueLayout();
        flush();
    };
    return {dock, group, render, flush, idles};
}

function item(id, label = id) {
    const window = {focused: false, has_focus() { return this.focused; },
        get_stable_sequence() { return id; }, get_title: () => label};
    const app = {get_id: () => 'example.desktop', get_icon: () => 'icon',
        get_name: () => 'Example', get_windows: () => [window]};
    return {kind: 'app', app, window, label, running: true};
}

test('focus and title changes keep the same clickable button and update its indicator', () => {
    const {dock, group, render} = fixture();
    const original = item(1);
    render([original]);
    const button = group.children[0];
    original.window.focused = true;
    const updated = {...original, label: 'Updated title'};
    render([updated]);
    assert.equal(group.children[0], button);
    assert.equal(button.accessible_name, updated.label);
    assert.equal(button._delegate.indicator.width, 14);
    let activated;
    dock._activateWindow = window => { activated = window; };
    button.emit('clicked');
    assert.equal(activated, updated.window);
});

test('new windows with identical titles replace the old activation target', () => {
    const {dock, group, render} = fixture();
    render([item(1, 'Same title')]);
    const oldButton = group.children[0];
    const replacement = item(2, 'Same title');
    render([replacement]);
    assert.equal(oldButton.destroyed, true);
    let activated;
    dock._activateWindow = window => { activated = window; };
    group.children[0].emit('clicked');
    assert.equal(activated, replacement.window);
});

test('adding, removing and reordering windows preserves surviving buttons', () => {
    const {group, render} = fixture();
    const a = item(1), b = item(2), c = item(3);
    render([a, b]);
    const [aButton, bButton] = group.children;
    render([c, b, a]);
    assert.equal(group.children[1], bButton);
    assert.equal(group.children[2], aButton);
    render([a, c]);
    assert.equal(group.children[0], aButton);
    assert.equal(bButton.destroyed, true);
});

test('a window closing between press and release cannot destroy the pressed button', () => {
    const {group, render, flush} = fixture();
    render([item(1)]);
    const button = group.children[0];
    button.pressed = true;
    button.emit('notify::pressed');
    render([]);
    assert.equal(button.destroyed, undefined);
    button.pressed = false;
    button.emit('notify::pressed');
    flush();
    assert.equal(button.destroyed, true);
});

test('refresh waits through drag cancellation and snap-back until drag-end', () => {
    const {dock, group, render, flush} = fixture();
    render([item(1)]);
    const button = group.children[0];
    button.draggable.emit('drag-begin');
    render([]);
    button.draggable.emit('drag-cancelled');
    flush();
    assert.equal(button.destroyed, undefined);
    assert.equal(dock._dockInteractions.size, 1);
    button.draggable.emit('drag-end');
    flush();
    assert.equal(button.destroyed, true);
    assert.equal(dock._previewDockItemDrag('running', group, button._delegate, 0), false);
    assert.doesNotThrow(() => button.draggable.emit('drag-end'));
});

test('settings rebuild waits for the active drag to finish', () => {
    const {dock, group, render, flush} = fixture();
    render([item(1)]);
    const button = group.children[0];
    button.draggable.emit('drag-begin');
    let rebuilt = 0;
    dock._destroyDock = () => { rebuilt++; };
    dock._createDock = () => {};
    dock._applyTheme = () => {};
    dock._applyDockPosition = () => {};
    dock._rebuildDock();
    assert.equal(rebuilt, 0);
    button.draggable.emit('drag-end');
    flush();
    assert.equal(rebuilt, 1);
});

test('overflow uses current window titles even when its button is retained', () => {
    const {dock, group, render} = fixture(75);
    const a = item(1), b = item(2), c = item(3);
    render([a, b, c]);
    const more = group.children.at(-1);
    render([a, {...b, label: 'Updated hidden window'}, c]);
    assert.equal(group.children.at(-1), more);
    let hidden;
    dock._showOverflow = (_, items) => { hidden = items; };
    more.emit('clicked');
    assert.equal(hidden[0].label, 'Updated hidden window');
});

test('dock teardown cancels the drag clone while the source is still alive', () => {
    const {dock, group, render, idles} = fixture();
    render([item(1)]);
    const button = group.children[0];
    button.draggable.emit('drag-begin');
    const clone = button._delegate.getDragActor();
    clone.connect('destroy', () => {
        button.live();
        button.draggable.emit('drag-cancelled');
        button.draggable.emit('drag-end');
    });
    dock._disabling = true;
    dock._destroyDock();
    assert.equal(clone.destroyed, true);
    assert.equal(button.destroyed, true);
    assert.equal(dock._dockInteractions.size, 0);
    assert.equal(idles.size, 0);
});
