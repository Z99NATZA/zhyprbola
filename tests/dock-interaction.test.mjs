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
    add_action(action) { (this.actions ??= []).push(action); }
    hide() { this.visible = false; }
    navigate_focus() { this.focusNavigated = true; }
    grab_key_focus() { Actor.keyFocus = this; }
    has_key_focus() { return Actor.keyFocus === this; }
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
    set_child(child) {
        for (const previous of this.children)
            previous.parent = null;
        this.children = [];
        this.add_child(child);
    }
    get_preferred_width() { return [0, Array.from(this.text ?? '').length * 8]; }
    get_preferred_height() { return [14, 14]; }
    set_position(x, y) { this.live(); Object.assign(this, {x, y}); }
    get_transformed_position() { return [this.x ?? 0, this.y ?? 0]; }
    get_transformed_size() { return [this.width ?? 0, this.height ?? 0]; }
    set_style(style) { this.live(); this.style = style; }
    set_pivot_point(x, y) { Object.assign(this, {pivotX: x, pivotY: y}); }
    set_rotation_angle(axis, angle) { Object.assign(this, {rotationAxis: axis, angle}); }
    add_style_class_name(name) { this.live(); (this.styleClasses ??= []).push(name); }
    remove_style_class_name() { this.live(); }
    add_style_pseudo_class() { this.live(); }
    remove_style_pseudo_class() { this.live(); }
    ease(props) { this.live(); Object.assign(this, props); }
}

class NativeAppMenu {
    constructor(sourceActor, side, options) {
        Object.assign(this, {sourceActor, side, options, actor: new Actor(), isOpen: false,
            actions: []});
        this._quitItem = this.addAction('Quit', () => this.app.request_quit());
    }
    setApp(app) { this.app = app; }
    addAction(label, callback) {
        const action = {
            label: {text: label}, callback, destroyed: false,
            activate() { this.callback(); },
            destroy() { this.destroyed = true; },
        };
        this.actions.push(action);
        return action;
    }
    open() { this.isOpen = true; }
    close() { this.isOpen = false; }
    toggle() { this.isOpen = !this.isOpen; }
    destroy() { this.close(); this.actor.destroy(); this.destroyed = true; }
}

class StaticPopupMenu {
    constructor(sourceActor, alignment, side) {
        Object.assign(this, {sourceActor, alignment, side, actor: new Actor(),
            box: new Actor(), items: [], isOpen: false});
        this.actor.add_child(this.box);
    }
    addMenuItem(item) { this.items.push(item); this.box.add_child(item); }
    addAction(label, callback, icon) {
        const action = new Actor({label: new Actor({text: label}), activate: callback, icon});
        this.items.push(action);
        return action;
    }
    toggle() { this.isOpen = !this.isOpen; }
    open(animation) { this.isOpen = true; this.openAnimation = animation; }
    close(animation) { this.isOpen = false; this.closeAnimation = animation; }
    destroy() { this.close(); this.actor.destroy(); this.destroyed = true; }
}

class StaticPopupMenuItem extends Actor {
    setSensitive(value) { this.sensitive = value; }
    constructor(props = {}) {
        assert.equal(Object.hasOwn(props, 'track_hover'), false,
            'PopupBaseMenuItem does not accept track_hover');
        super(props);
    }
}

function fixture(length = 400) {
    const idles = new Map();
    const keybindings = new Map();
    let nextId = 0;
    const context = vm.createContext({
        St: {Widget: Actor, BoxLayout: Actor, Icon: Actor, Button: Actor,
            Label: class extends Actor {
                constructor(props) { super(props); this.clutter_text = {}; }
            }, ButtonMask: {ONE: 1},
            Side: {LEFT: 0, RIGHT: 1, TOP: 2, BOTTOM: 3},
            DirectionType: {TAB_FORWARD: 0}},
        Clutter: {FixedLayout: class {}, BinLayout: class {}, AnimationMode: {EASE_OUT_QUAD: 0},
            RotateAxis: {Z_AXIS: 2}, ActorAlign: {CENTER: 0, START: 1, END: 2},
            ClickGesture: Actor, BUTTON_SECONDARY: 3},
        Pango: {EllipsizeMode: {NONE: 0, END: 3}},
        DND: {makeDraggable: actor => (actor.draggable = new Actor())},
        GLib: {PRIORITY_DEFAULT_IDLE: 0, SOURCE_REMOVE: false,
            idle_add: (_, callback) => { idles.set(++nextId, callback); return nextId; }},
        Meta: {KeyBindingFlags: {IGNORE_AUTOREPEAT: 1}, LaterType: {BEFORE_REDRAW: 1}},
        global: {
            display: {list_all_windows: () => []},
            compositor: {get_laters: () => ({
                add: (_, callback) => { idles.set(++nextId, callback); return nextId; },
                remove: id => idles.delete(id),
            })},
        },
        Mtk: {Rectangle: class { constructor(props) { Object.assign(this, props); } }},
        Shell: {ActionMode: {NORMAL: 1}},
        Main: {layoutManager: {primaryMonitor: {x: 0, y: 0, width: length + 8, height: 900},
            removeChrome() {}}, uiGroup: new Actor(), wm: {
            addKeybinding(name, settings, flags, modes, callback) {
                keybindings.set(name, {settings, flags, modes, callback});
            },
            removeKeybinding(name) { keybindings.delete(name); },
        }},
        AppMenu: NativeAppMenu,
        SoundMenu: NativeAppMenu,
        BrightnessMenu: NativeAppMenu,
        BatteryMenu: NativeAppMenu,
        PopupMenu: {PopupMenuManager: class {}, PopupMenu: StaticPopupMenu,
            PopupBaseMenuItem: StaticPopupMenuItem},
        BoxPointer: {PopupAnimation: {NONE: 'none'}},
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
        _dockComponents: {visible: [], hidden: [], quick: []},
        _dockGroupsByName: new Map([['running', group]]), _dockGroupOrder: ['running'],
        _dockRegions: new Map([['running', new Actor()]]),
        _dockItems: new Map([['running', []]]), _dockRenderState: new Map(),
        _runningOrder: new Map(), _nextRunningOrder: 0,
        _showDesktopButton: new Actor(), _panelIcons: new Map(),
        _showDesktopKeybindingRegistered: false, _keybindingSettings: null,
        _menuManager: {menus: [], addMenu(menu) { this.menus.push(menu); }},
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
    return {dock, group, render, flush, idles, keybindings, context};
}

function item(id, label = id) {
    const window = {focused: false, has_focus() { return this.focused; },
        get_stable_sequence() { return id; }, get_title: () => label};
    const app = {get_id: () => 'example.desktop', get_icon: () => 'icon',
        get_name: () => 'Example', get_windows: () => [window]};
    return {kind: 'app', app, window, label, running: true};
}

function workspaceFixture(side = 'bottom') {
    const setup = fixture();
    const {dock, context} = setup;
    const manager = new Actor({n_workspaces: 3, active: 1});
    manager.connectObject = (...args) => {
        for (let i = 0; i < args.length - 1; i += 2)
            manager.connect(args[i], args[i + 1]);
    };
    manager.get_active_workspace_index = () => manager.active;
    manager.activations = [];
    manager.get_workspace_by_index = index => ({activate: time => {
        manager.activations.push({index, time});
        manager.active = index;
        manager.emit('active-workspace-changed');
    }});
    context.global.workspace_manager = manager;
    context.global.get_current_time = () => 123;
    dock._dockPosition = side;
    dock._updateShowDesktopState = () => {};
    dock._themeName = 'current';
    dock._watchWorkspaces();
    return {...setup, manager};
}

function mixedRegionFixture(regions, side = 'bottom') {
    const setup = workspaceFixture(side);
    const {dock} = setup;
    dock._dockLayout = {version: 1, regions, hidden: [], quick: []};
    dock._dockComponents = dock._componentsForLayout(dock._dockLayout);
    dock._dockGroupOrder = ['apps', 'running', 'zhyprbola'];
    dock._dockGroupsByName = new Map();
    dock._dockRegions = new Map();
    for (const name of dock._regionNames()) {
        const group = new Actor();
        dock._dock.add_child(group);
        dock._dockGroupsByName.set(name, group);
        dock._dockRegions.set(name, new Actor());
    }
    dock._dateTimeLabels = new Map();
    dock._keyCountLabels = new Set();
    dock._keyCountText = () => 'keys:1d:42';
    dock._dateTimeItemLength = () => 80;
    dock._formatDockDate = () => '2026-10-23';
    dock._formatDockTime = () => '21:00';
    dock._panelGicon = name => name;
    return setup;
}

test('shared regions migrate legacy order and normalize duplicate/invalid placement', () => {
    const {dock, context} = fixture();
    const legacy = {visible: ['workspaces', 'settings', 'wifi'], hidden: ['todo'], quick: ['sound']};
    const layout = dock._readDockLayout(legacy, ['zhyprbola', 'running'], ['zhyprbola', 'apps', 'running']);
    assert.deepEqual(JSON.parse(JSON.stringify(layout.regions)),
        [['workspaces', 'settings', 'wifi'], [], ['running']]);
    assert.equal(layout.hidden.includes('apps'), true);
    context.TextDecoder = TextDecoder;
    context.GLib.file_get_contents = () => [true, new TextEncoder().encode(JSON.stringify({
        regions: [['running', 'settings', 'wifi', 'wifi'], ['running', 'apps', 'bogus'], []],
        hidden: ['settings', 'wifi', 'workspaces'], quick: ['running', 'workspaces', 'sound'],
    }))];
    const normalized = dock._readDockLayout(legacy, ['zhyprbola', 'running'], ['apps', 'running', 'zhyprbola']);
    assert.deepEqual(JSON.parse(JSON.stringify(normalized.regions)), [['running', 'settings', 'wifi'], ['apps'], []]);
    assert.deepEqual(JSON.parse(JSON.stringify(normalized.hidden)), ['workspaces', 'todo']);
    assert.deepEqual(JSON.parse(JSON.stringify(normalized.quick)), ['sound']);
});

test('components and app blocks render together on every edge and retain live controls during app changes', () => {
    for (const side of ['bottom', 'top', 'left', 'right']) {
        const {dock} = mixedRegionFixture([['workspaces', 'running', 'time-display'], ['settings'], ['key-count']], side);
        dock._dockItems.set('running', [item(1)]);
        dock._composeDockRegions();
        const group = dock._dockGroupsByName.get('region-1');
        const vertical = side === 'left' || side === 'right';
        dock._renderDockRegion('region-1', 400, vertical, 0);
        dock._renderDockRegion('region-2', 150, vertical, 1);
        dock._renderDockRegion('region-3', 150, vertical, 2);
        const pager = group.children[0];
        const clock = group.children[2];
        const label = dock._dateTimeLabels.get('time-display');
        assert.equal(group.children[1]._delegate.groupName, 'running');
        assert.equal(group.children[1]._delegate.item.window, dock._dockItems.get('running')[0].window);
        assert.equal(dock._keyCountLabels.size, 1);
        dock._dockItems.set('running', [item(1), item(2)]);
        dock._composeDockRegions();
        dock._renderDockRegion('region-1', 400, vertical, 0);
        assert.equal(group.children[0], pager);
        assert.equal(group.children[3], clock);
        assert.equal(dock._dateTimeLabels.get('time-display'), label);
        assert.equal(label.destroyed, undefined);
        assert.equal(dock._keyCountLabels.size, 1, 'another region retains its key-count label');
    }
});

test('dense regions borrow idle space on every edge and return it when their contents shrink', () => {
    const layout = [['workspaces'], ['running'],
        ['key-count', 'wifi', 'bluetooth', 'date-display', 'time-display',
            'input-source', 'components', 'sound', 'brightness', 'settings', 'power']];
    for (const side of ['bottom', 'top', 'left', 'right']) {
        const {dock, context} = mixedRegionFixture(layout.map(items => [...items]), side);
        const vertical = side === 'left' || side === 'right';
        context.Main.layoutManager.primaryMonitor = {x: 100, y: 200, width: 908, height: 908};
        dock._connectionNames = {wifi: 'Office Wi-Fi', bluetooth: 'Headphones'};
        dock._currentInputSourceCode = () => 'en';
        dock._dockItems.set('running', [item(1), item(2)]);
        dock._composeDockRegions();
        dock._layoutDock();
        const groups = dock._regionNames().map(name => dock._dockGroupsByName.get(name));
        for (const group of groups)
            assert.equal(group.children.some(child => child._dockOverflow), false, side);
        assert.equal(groups[2].children.at(-2)._panelName, 'settings');
        assert.equal(groups[2].children.at(-1)._panelName, 'power');
        const region = dock._dockRegions.get('region-3');
        assert.ok((vertical ? region.height : region.width) > 600);
        const total = [...dock._dockRegions.values()]
            .reduce((sum, actor) => sum + (vertical ? actor.height : actor.width), 0);
        assert.equal(total, 900, 'borrowing never expands the dock beyond the monitor');

        // App-only regions also borrow; labels are not required to trigger it.
        dock._dockLayout.regions[2] = ['settings', 'power'];
        dock._dockItems.set('running', Array.from({length: 15}, (_, index) => item(index + 1)));
        dock._composeDockRegions();
        dock._layoutDock();
        assert.equal(groups[1].children.length, 15);
        assert.equal(groups[1].children.some(child => child._dockOverflow), false);

        dock._dockItems.set('running', [item(1), item(2)]);
        dock._composeDockRegions();
        dock._layoutDock();
        for (const actor of dock._dockRegions.values())
            assert.equal(vertical ? actor.height : actor.width, 300, 'equal regions return when all contents fit');
    }
});

test('borrowing preserves a centered middle group until neighboring contents need its space', () => {
    const {dock, context} = mixedRegionFixture([['running'], ['settings'], []]);
    context.Main.layoutManager.primaryMonitor.width = 908;
    dock._dockItems.set('running', Array.from({length: 10}, (_, index) => item(index + 1)));
    dock._composeDockRegions();
    dock._layoutDock();
    const start = dock._dockRegions.get('region-1').width;
    const middle = dock._dockGroupsByName.get('region-2');
    assert.equal(start + middle.x + middle.width / 2, 449.5);
});

test('overflow remains available when the whole dock is full and disappears after space becomes available', () => {
    const {dock, context} = mixedRegionFixture([['running'], [], ['settings', 'power']]);
    context.Main.layoutManager.primaryMonitor.width = 308;
    dock._dockItems.set('running', Array.from({length: 15}, (_, index) => item(index + 1)));
    dock._composeDockRegions();
    dock._layoutDock();
    const group = dock._dockGroupsByName.get('region-1');
    const more = group.children.at(-1);
    assert.equal(more._dockOverflow, true);
    let hidden;
    dock._showOverflow = (_, items) => { hidden = items; };
    more.emit('clicked');
    assert.equal(hidden.length + group.children.length - 1, 15);
    assert.equal(dock._dockGroupsByName.get('region-3').children.length, 2);
    context.Main.layoutManager.primaryMonitor.width = 908;
    dock._layoutDock();
    assert.equal(group.children.length, 15);
    assert.equal(group.children.some(child => child._dockOverflow), false);
});

test('pinned and running instances of the same app keep distinct buttons in a shared region', () => {
    const {dock} = mixedRegionFixture([['apps', 'running'], [], ['settings']]);
    const app = item(1);
    dock._dockItems.set('apps', [app]);
    dock._dockItems.set('running', [app]);
    dock._composeDockRegions();
    dock._renderDockRegion('region-1', 300, false, 0);
    const group = dock._dockGroupsByName.get('region-1');
    const buttons = group.get_children();
    assert.equal(buttons[0]._delegate.groupName, 'apps');
    assert.equal(buttons[1]._delegate.groupName, 'running');
    assert.notEqual(buttons[0], buttons[1]);
    dock._renderDockRegion('region-1', 300, false, 0);
    assert.deepEqual(group.get_children(), buttons);
});

test('dragging running apps in a mixed region preserves surrounding components and commits only app order', () => {
    const {dock} = mixedRegionFixture([['workspaces', 'running', 'time-display'], [], ['settings']]);
    const a = item(1), b = item(2);
    dock._dockItems.set('running', [a, b]);
    dock._composeDockRegions();
    dock._renderDockRegion('region-1', 400, false, 0);
    const group = dock._dockGroupsByName.get('region-1');
    const [pager, first, second, clock] = group.get_children();
    first.x = 64;
    second.x = 95;
    assert.equal(dock._previewDockItemDrag('running', group, first._delegate, 120), true);
    assert.deepEqual(group.get_children(), [pager, second, first, clock]);
    dock._commitDockItemOrder('running', [second._delegate.key, first._delegate.key]);
    assert.equal(dock._dockItems.get('running')[0], b);
    assert.equal(dock._dockItems.get('running')[1], a);
    assert.deepEqual(Array.from(dock._dockItems.get('region-1'), value => value.kind),
        ['workspaces', 'app', 'app', 'date-time']);
});

test('component animation and popup anchors follow the component into its shared region', () => {
    const {dock} = mixedRegionFixture([['sound', 'todo'], ['running'], ['settings', 'components']]);
    const group = dock._dockGroupsByName.get('region-1');
    dock._composeDockRegions();
    dock._renderDockRegion('region-1', 300, false, 0);
    const [sound, todo] = group.get_children();
    todo.set_position(120, 900);
    todo.set_size(27, 27);
    let rect;
    dock._setPanelAnimationTarget({get_title: () => 'Zhyprbola Tasks', set_icon_geometry: value => { rect = value; }});
    assert.equal(rect?.x, 120);
    let source;
    dock._openSoundMenu = button => { source = button; };
    dock._openPanel('sound');
    assert.equal(source, sound);
    dock._renderDockRegion('region-1', 30, false, 0);
    const overflow = group.children[0];
    overflow.set_position(150, 900);
    overflow.set_size(27, 27);
    rect = null;
    dock._setPanelAnimationTarget({get_title: () => 'Zhyprbola Tasks', set_icon_geometry: value => { rect = value; }});
    assert.equal(rect?.x, 150);
});

test('canceling an app drag restores its block position without crossing surrounding components', () => {
    const {dock} = mixedRegionFixture([['workspaces', 'running', 'time-display'], [], ['settings']]);
    dock._dockItems.set('running', [item(1), item(2)]);
    dock._composeDockRegions();
    dock._renderDockRegion('region-1', 400, false, 0);
    const group = dock._dockGroupsByName.get('region-1');
    const original = group.get_children();
    const first = original[1];
    first.x = 64;
    original[2].x = 95;
    first.draggable.emit('drag-begin');
    assert.equal(first._delegate.originalIndex, 0);
    dock._previewDockItemDrag('running', group, first._delegate, 120);
    assert.equal(group.children[2], first);
    first.draggable.emit('drag-cancelled');
    assert.deepEqual(group.get_children(), original);
    first.draggable.emit('drag-end');
    assert.equal(dock._dockInteractions.size, 0);
});

test('date/time format changes resize inline labels after moving them to another region', () => {
    const {dock, flush} = mixedRegionFixture([['time-display'], [], ['settings']]);
    Object.assign(dock, {_dockBgOpacity: 50, _dockUngroupWindows: false,
        _useWallpaper: false, _edgeEnabled: false, _edgePosition: 'bottom',
        _dockGroups: ['zhyprbola', 'running'], _dateTimeSettings: {}, _pinnedApps: null,
        _connectionRefreshToken: ''});
    const reads = {Theme: '_themeName', DockPosition: '_dockPosition', DockBgOpacity: '_dockBgOpacity',
        DockUngroupWindows: '_dockUngroupWindows', UseWallpaper: '_useWallpaper', EdgeEnabled: '_edgeEnabled',
        EdgePosition: '_edgePosition', DockGroups: '_dockGroups', DockGroupOrder: '_dockGroupOrder',
        DockComponents: '_dockComponents', PinnedApps: '_pinnedApps', ConnectionRefreshToken: '_connectionRefreshToken'};
    for (const [reader, field] of Object.entries(reads)) dock[`_read${reader}`] = () => dock[field];
    dock._handlePanelRequest = () => {};
    dock._refreshDateTimeLabels = () => {};
    let length = 52;
    dock._dateTimeItemLength = () => length;
    dock._formatDockTime = () => length === 52 ? '21:00' : '21:00:00';
    dock._composeDockRegions();
    dock._layoutDock();
    const group = dock._dockGroupsByName.get('region-1');
    assert.equal(group.children[0].width, 52);
    length = 78;
    dock._readDateTimeSettings = () => ({showSeconds: true});
    dock._syncSettings();
    flush();
    assert.equal(group.children[0].width, 78);
    assert.equal(dock._dateTimeLabels.get('time-display').text, '21:00:00');
});

test('Workspaces defaults to Show and respects Hidden while rejecting Quick', () => {
    const {dock, context} = fixture();
    assert.equal(dock._readDockComponents().visible[0], 'workspaces');
    context.TextDecoder = TextDecoder;
    for (const zone of ['hidden', 'quick']) {
        const saved = {visible: ['settings'], hidden: [], quick: []};
        saved[zone] = ['workspaces'];
        context.GLib.file_get_contents = () => [true,
            new TextEncoder().encode(JSON.stringify(saved))];
        const layout = dock._readDockComponents();
        assert.equal(layout.quick.includes('workspaces'), false);
        assert.equal(layout[zone === 'quick' ? 'visible' : 'hidden'].includes('workspaces'), true);
    }
    dock._dockGroupsByName.set('zhyprbola', new Actor());
    dock._dockComponents.visible = ['workspaces'];
    dock._createComponentButtons();
    assert.equal(dock._dockItems.get('zhyprbola')[0].kind, 'workspaces');
});

test('workspace dots switch directly and retain their buttons across active changes on every edge', () => {
    for (const side of ['bottom', 'top', 'left', 'right']) {
        const {dock, manager} = workspaceFixture(side);
        const vertical = side === 'left' || side === 'right';
        const pager = dock._createWorkspacePager(vertical);
        const buttons = pager.get_children();
        assert.equal(pager.vertical, vertical);
        assert.equal(buttons.length, 3);
        assert.equal(vertical ? pager.width : pager.height, 27);
        assert.equal(vertical ? pager.height : pager.width, dock._dockItemLength({kind: 'workspaces'}));
        const assertSelected = index => {
            assert.deepEqual(pager.get_children(), buttons);
            for (const [i, button] of buttons.entries()) {
                assert.equal(button.checked, i === index);
                assert.equal(vertical ? button.width : button.height, 27);
                const dot = button.children[0];
                assert.equal(vertical ? dot.height : dot.width, i === index ? 18 : 6);
                assert.equal(vertical ? dot.width : dot.height, 6);
            }
        };
        assertSelected(1);
        buttons[2].emit('clicked');
        assert.deepEqual(manager.activations, [{index: 2, time: 123}]);
        assertSelected(2);
        buttons[2].emit('clicked');
        assert.equal(manager.activations.length, 1, 'active workspace does not reactivate');
        manager.active = 0;
        manager.emit('active-workspace-changed');
        assertSelected(0);
        manager.active = 1;
        manager.emit('workspaces-reordered');
        assertSelected(1);
        pager.destroy();
        assert.equal(dock._workspaceIndicators.size, 0);
        manager.emit('active-workspace-changed');
    }
});

test('workspace count changes update pagination length, preserve surviving buttons and queue layout', () => {
    const {dock, manager} = workspaceFixture();
    const pager = dock._createWorkspacePager(false);
    const first = pager.children[0];
    let layouts = 0;
    dock._queueLayout = () => layouts++;
    manager.n_workspaces = 5;
    manager.emit('notify::n-workspaces');
    assert.equal(pager.children.length, 5);
    assert.equal(pager.width, 92);
    assert.equal(pager.children[0], first);
    const removed = pager.children[4];
    manager.n_workspaces = 2;
    manager.active = 0;
    manager.emit('notify::n-workspaces');
    assert.equal(pager.children.length, 2);
    assert.equal(pager.width, 44);
    assert.equal(pager.children[0], first);
    assert.equal(removed.destroyed, true);
    dock._activateWorkspace(4);
    assert.equal(manager.activations.length, 0);
    assert.equal(layouts, 2);
});

test('workspace pagination participates in dock sizing and exposes direct actions in overflow', () => {
    const {dock, group, manager} = workspaceFixture();
    dock._dockItems.set('running', [{kind: 'workspaces', name: 'workspaces', label: 'Workspaces'}]);
    dock._renderDockRegion('running', 150, false, 0);
    assert.equal(group.children[0].children.length, 3);
    manager.n_workspaces = 4;
    dock._renderDockRegion('running', 150, false, 0);
    assert.equal(group.children[0].children.length, 4, 'count invalidates cached region sizing');
    dock._renderDockRegion('running', 30, false, 0);
    const more = group.children[0];
    dock._panelGicon = name => name;
    assert.equal(more._dockOverflow, true);
    assert.equal(dock._workspaceIndicators.size, 0);
    more.emit('clicked');
    assert.equal(dock._overflowMenu.items.length, 4);
    assert.equal(dock._overflowMenu.items[1].label.text, 'Workspace 2 (current)');
    dock._overflowMenu.items[3].activate();
    assert.deepEqual(manager.activations, [{index: 3, time: 123}]);
});

test('first-open Settings is placed beside region 3 on every dock side', () => {
    const {dock, context} = fixture();
    context.Main.layoutManager.primaryMonitor = {index: 1, x: 1200, y: 100, width: 1920, height: 1080};
    context.Main.layoutManager.getWorkAreaForMonitor = index => {
        assert.equal(index, 1);
        return {x: 1200, y: 140, width: 1920, height: 1040};
    };
    const geometry = rect => ({
        get_transformed_position: () => [rect.x, rect.y],
        get_transformed_size: () => [rect.width, rect.height],
    });
    const cases = [
        ['bottom', {x: 1200, y: 1145, width: 1920, height: 35},
            {x: 2480, y: 1149, width: 640, height: 27}, [2788, 853]],
        ['top', {x: 1200, y: 140, width: 1920, height: 35},
            {x: 2480, y: 144, width: 640, height: 27}, [2788, 187]],
        ['left', {x: 1200, y: 100, width: 35, height: 1080},
            {x: 1204, y: 824, width: 27, height: 352}, [1247, 888]],
        ['right', {x: 3085, y: 100, width: 35, height: 1080},
            {x: 3089, y: 824, width: 27, height: 352}, [2753, 888]],
    ];
    for (const [side, dockRect, regionRect, expected] of cases) {
        dock._dockPosition = side;
        dock._dock = geometry(dockRect);
        // Follow the third region even when the component region is reordered.
        dock._dockGroupOrder = ['zhyprbola', 'apps', 'running'];
        dock._dockRegions = new Map([['running', geometry(regionRect)]]);
        let position;
        dock._moveSettingsNearDock({move_frame: (user, x, y) => {
            assert.equal(user, true);
            position = [x, y];
        }}, {width: 320, height: 280});
        assert.deepEqual(position, expected, side);
    }

    let position;
    dock._moveSettingsNearDock({move_frame: (_user, x, y) => { position = [x, y]; }},
        {width: 660, height: 720});
    assert.deepEqual(position, [2413, 448], 'large Settings stays inside the work area');
});

test('reopening an existing Settings window preserves its position', () => {
    const {dock, context} = fixture();
    const window = {get_title: () => 'Zhyprbola Settings'};
    context.global = {display: {list_all_windows: () => [window]}};
    let activated;
    dock._activateWindow = target => { activated = target; };
    dock._placeSettingsOnFirstOpen = () => assert.fail('existing Settings must not be repositioned');
    dock._openPanel('settings');
    assert.equal(activated, window);
});

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

test('overflow styles every action and opens Settings and Power from the same source', () => {
    const {dock, flush} = workspaceFixture();
    const source = new Actor();
    dock._themeName = 'mauve';
    dock._panelGicon = (name, color) => ({name, color});
    dock._formatDockDate = () => '2026-10-24';
    dock._keyCountText = () => 'keys:1d:42';
    const opened = [];
    dock._openPanel = name => opened.push(name);
    dock._openDateTimeSettings = () => opened.push('date-time');
    const items = ['workspaces', 'date-display', 'time-display', 'key-count', 'input-source', 'settings', 'power']
        .map(name => dock._componentItem(name));
    dock._formatDockTime = () => '23:08:35';
    dock._showOverflow(source, items);
    const menu = dock._overflowMenu;
    for (const action of menu.items) {
        assert.equal(action.label.style, 'color: #be345f;');
        assert.ok(action.styleClasses.includes('zhyprbola-overflow-item'));
        assert.ok(action.icon, 'every component uses its existing icon');
    }
    menu.items.find(action => action.label.text.startsWith('Date:')).activate();
    menu.items.find(action => action.label.text === 'Zhyprbola settings').activate();
    menu.items.find(action => action.label.text === 'Power').activate();
    assert.deepEqual(opened, ['date-time', 'settings']);
    flush();
    assert.equal(dock._powerMenu.sourceActor, source);
    assert.equal(dock._powerMenu.items.length, 3);
    for (const action of dock._powerMenu.items)
        assert.equal(action.label.style, 'color: #be345f;');
});

test('overflow and Power release pointer focus on leave while retaining keyboard focus otherwise', () => {
    const {dock, flush} = workspaceFixture();
    dock._panelGicon = name => name;
    dock._showOverflow(new Actor(), [dock._componentItem('power')]);
    const overflow = dock._overflowMenu;
    overflow.items[0].activate();
    flush();
    for (const menu of [overflow, dock._powerMenu]) {
        const action = menu.items[0];
        action.hover = true;
        action.active = true;
        action.grab_key_focus();
        action.emit('notify::hover');
        assert.equal(action.has_key_focus(), true, 'hover still focuses the row');
        action.hover = false;
        action.emit('notify::hover');
        assert.equal(action.active, false);
        assert.equal(menu.actor.has_key_focus(), true, 'leaving removes the row focus highlight');

        action.grab_key_focus();
        action.active = true;
        assert.equal(action.has_key_focus(), true, 'keyboard focus can return without hovering');
        assert.equal(action.active, true);
        menu.actor.grab_key_focus();
        action.emit('notify::hover');
        assert.equal(menu.actor.has_key_focus(), true, 'leaving an unfocused row does not take focus');
    }
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

function desktopFixture() {
    const {dock, context} = fixture();
    const workspace = {}, otherWorkspace = {};
    let activeWorkspace = workspace;
    const windows = [];
    const display = {focus_window: null, list_all_windows: () => windows,
        sort_windows_by_stacking: values => values};
    context.global = {display, get_current_time: () => 123,
        workspace_manager: {get_active_workspace: () => activeWorkspace}};
    dock._desktopWindows = new Map();
    const addWindow = (id, options = {}) => {
        const window = {id, minimized: false, workspace, title: 'Example', wmClass: 'Example',
            minimizable: true, minimizeCalls: 0, restoreCalls: 0, activateCalls: 0,
            get_stable_sequence() { return this.id; }, get_title() { return this.title; },
            get_wm_class() { return this.wmClass; }, can_minimize() { return this.minimizable; },
            located_on_workspace(value) { return this.workspace === value; },
            set_icon_geometry(rect) { this.iconGeometry = {...rect}; },
            minimize() { this.minimized = true; this.minimizeCalls++; },
            unminimize() { this.minimized = false; this.restoreCalls++; },
            activate() { this.activateCalls++; }, ...options};
        windows.push(window);
        return window;
    };
    return {dock, display, windows, workspace, otherWorkspace, addWindow,
        switchWorkspace(value) { activeWorkspace = value; }};
}

test('component minimize and restore use their dock button on every screen edge', () => {
    const {dock, context} = fixture();
    const group = new Actor();
    dock._dockGroupsByName.set('zhyprbola', group);
    const button = new Actor({_panelName: 'todo', width: 27, height: 27});
    group.add_child(button);
    const window = {
        get_title: () => 'Zhyprbola Tasks',
        set_icon_geometry(rect) { this.geometry = {...rect}; },
        has_focus() { return this.focused; },
        minimize() { this.minimized = true; },
        unminimize() { this.minimized = false; },
        activate() { this.focused = true; },
    };
    Object.assign(context.global.display, {list_all_windows: () => [window]});
    context.global.get_current_time = () => 1;
    for (const [side, x, y] of [
        ['bottom', 2100, 1160], ['left', 1200, 800],
        ['right', 3090, 800], ['top', 2100, 100],
    ]) {
        dock._dockPosition = side;
        button.set_position(x, y);
        window.focused = true;
        dock._openPanel('todo');
        assert.equal(window.minimized, true);
        assert.deepEqual(window.geometry, {x, y, width: 27, height: 27});
        window.focused = false;
        dock._openPanel('todo');
        assert.equal(window.minimized, false);
        assert.deepEqual(window.geometry, {x, y, width: 27, height: 27});
    }
});

test('component animation targets follow overflow, quick menu, Settings and dock fallback', () => {
    const {dock} = fixture();
    const group = new Actor();
    dock._dockGroupsByName.set('zhyprbola', group);
    dock._dock.set_position(1200, 1153);
    dock._dock.set_size(1920, 27);
    const settings = new Actor({_panelName: 'settings', x: 1300, y: 1153, width: 27, height: 27});
    const quick = new Actor({_panelName: 'components', x: 1400, y: 1153, width: 27, height: 27});
    const overflow = new Actor({_dockOverflow: true, x: 1500, y: 1153, width: 27, height: 27});
    for (const button of [settings, quick, overflow])
        group.add_child(button);
    const window = {get_title: () => 'Zhyprbola Calendar',
        set_icon_geometry(rect) { this.geometry = {...rect}; }};
    dock._dockComponents.visible = ['calendar'];
    dock._setPanelAnimationTarget(window);
    assert.equal(window.geometry.x, 1500);
    dock._dockComponents.visible = [];
    dock._setPanelAnimationTarget(window);
    assert.equal(window.geometry.x, 1400);
    quick.destroy();
    dock._setPanelAnimationTarget(window);
    assert.equal(window.geometry.x, 1300);
    settings.destroy();
    dock._setPanelAnimationTarget(window);
    assert.deepEqual(window.geometry, {x: 2160, y: 1167, width: 1, height: 1});
    for (const title of ['Example', 'Zhyprbola Screenshots']) {
        window.get_title = () => title;
        window.set_icon_geometry = () => assert.fail('unrelated lifecycle');
        dock._setPanelAnimationTarget(window);
    }
});

test('layout publishes final geometry for QML minimize and cancels pending work on teardown', () => {
    const {dock, context, flush, idles} = fixture();
    const group = new Actor();
    dock._dockGroupsByName.set('zhyprbola', group);
    const button = new Actor({_panelName: 'bluetooth', width: 27, height: 27});
    group.add_child(button);
    const window = {get_title: () => 'Zhyprbola Panel',
        set_icon_geometry(rect) { this.geometry = {...rect}; }};
    context.global.display.list_all_windows = () => [window];
    dock._layoutDock();
    dock._queuePanelAnimationTargets();
    assert.equal(idles.size, 1, 'coalesce geometry updates');
    button.set_position(2345, 873);
    flush();
    assert.deepEqual(window.geometry, {x: 2345, y: 873, width: 27, height: 27});
    dock._queuePanelAnimationTargets();
    dock._destroyDock();
    assert.equal(idles.size, 0);
    assert.equal(dock._panelGeometryLaterId, 0);
});

test('show desktop shortcut registers, invokes the toggle, and unregisters', () => {
    const {dock, keybindings} = fixture();
    const settings = {};
    let toggleCalls = 0;
    dock.getSettings = () => settings;
    dock._toggleDesktop = () => toggleCalls++;

    dock._registerShowDesktopKeybinding();
    const binding = keybindings.get('zhyprbola-toggle-desktop');
    assert.equal(binding.settings, settings);
    assert.equal(binding.flags, 1);
    assert.equal(binding.modes, 1);
    binding.callback();
    assert.equal(toggleCalls, 1);

    dock._unregisterShowDesktopKeybinding();
    assert.equal(keybindings.has('zhyprbola-toggle-desktop'), false);
    assert.equal(dock._keybindingSettings, null);
});

test('show desktop hides on the first click and restores only its own windows', () => {
    const {dock, display, addWindow} = desktopFixture();
    const a = addWindow(1), b = addWindow(2), preMinimized = addWindow(3, {minimized: true});
    const component = addWindow(4, {title: 'Zhyprbola Settings'});
    const fixed = addWindow(5, {minimizable: false});
    display.focus_window = a;
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, true);
    assert.equal(component.minimized, false);
    assert.equal(fixed.minimized, false);
    dock._toggleDesktop();
    assert.equal(a.minimized, false);
    assert.equal(b.minimized, false);
    assert.equal(preMinimized.minimized, true);
    assert.equal(a.activateCalls, 1);
});

test('show desktop animates toward the dock center and follows dock moves on restore', () => {
    const {dock, addWindow} = desktopFixture();
    const a = addWindow(1, {
        minimize() {
            assert.deepEqual(this.iconGeometry, {x: 2160, y: 1167, width: 1, height: 1});
            this.minimized = true;
        },
        unminimize() {
            assert.deepEqual(this.iconGeometry, {x: 1214, y: 640, width: 1, height: 1});
            this.minimized = false;
        },
    });
    const skipped = addWindow(2, {minimized: true});
    dock._dock.set_position(1200, 1153);
    dock._dock.set_size(1920, 27);
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(skipped.iconGeometry, undefined);
    dock._dock.set_position(1200, 100);
    dock._dock.set_size(27, 1080);
    dock._toggleDesktop();
    assert.equal(a.minimized, false);
});

test('a new hide restores only windows visible before that hide', () => {
    const {dock, addWindow} = desktopFixture();
    const a = addWindow(1), b = addWindow(2);
    dock._toggleDesktop();
    a.unminimize();
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, true);
    assert.equal(b.restoreCalls, 0);
    dock._toggleDesktop();
    assert.equal(a.minimized, false);
    assert.equal(b.minimized, true);
});

test('a new visible window replaces the previous restore snapshot', () => {
    const {dock, addWindow} = desktopFixture();
    const a = addWindow(1);
    dock._toggleDesktop();
    const b = addWindow(2);
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, true);
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, false);
});

test('each workspace retains its own hide and restore history', () => {
    const {dock, addWindow, workspace, otherWorkspace, switchWorkspace} = desktopFixture();
    const a = addWindow(1), b = addWindow(2, {workspace: otherWorkspace});
    dock._toggleDesktop();
    switchWorkspace(otherWorkspace);
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, true);
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, false);
    switchWorkspace(workspace);
    dock._toggleDesktop();
    assert.equal(a.minimized, false);
});

test('restoring ignores closed windows and windows moved to another workspace', () => {
    const {dock, addWindow, windows, otherWorkspace} = desktopFixture();
    const closed = addWindow(1), moved = addWindow(2), live = addWindow(3);
    dock._toggleDesktop();
    windows.splice(windows.indexOf(closed), 1);
    moved.workspace = otherWorkspace;
    dock._toggleDesktop();
    assert.equal(closed.restoreCalls, 0);
    assert.equal(moved.minimized, true);
    assert.equal(live.minimized, false);
});

test('disabling restores windows hidden on every workspace', () => {
    const {dock, addWindow, otherWorkspace, switchWorkspace} = desktopFixture();
    const a = addWindow(1), b = addWindow(2, {workspace: otherWorkspace});
    dock._toggleDesktop();
    switchWorkspace(otherWorkspace);
    dock._toggleDesktop();
    dock._restoreDesktopWindows();
    assert.equal(a.minimized, false);
    assert.equal(b.minimized, false);
    assert.equal(dock._desktopWindows.size, 0);
});

test('Sound defaults to Quick when adding it to an existing component layout', () => {
    const {dock, context} = fixture();
    context.TextDecoder = TextDecoder;
    context.GLib.file_get_contents = () => [true,
        new TextEncoder().encode(JSON.stringify({visible: ['settings'], hidden: [], quick: ['wifi']}))];
    const layout = dock._readDockComponents();
    assert.equal(layout.visible.includes('sound'), false);
    assert.equal(layout.quick.filter(name => name === 'sound').length, 1);
    assert.equal(layout.quick[0], 'wifi');
});

test('Settings remains in Show when an older layout placed it in Hidden or Quick', () => {
    for (const zone of ['hidden', 'quick']) {
        const {dock, context} = fixture();
        context.TextDecoder = TextDecoder;
        const saved = {visible: [], hidden: [], quick: []};
        saved[zone] = ['settings'];
        context.GLib.file_get_contents = () => [true,
            new TextEncoder().encode(JSON.stringify(saved))];
        const layout = dock._readDockComponents();
        assert.equal(layout.visible.filter(name => name === 'settings').length, 1);
        assert.equal(layout.hidden.includes('settings'), false);
        assert.equal(layout.quick.includes('settings'), false);
    }
});

test('Sound respects explicit visible and hidden placement', () => {
    for (const zone of ['visible', 'hidden']) {
        const {dock, context} = fixture();
        context.TextDecoder = TextDecoder;
        const saved = {visible: [], hidden: [], quick: []};
        saved[zone] = ['sound'];
        context.GLib.file_get_contents = () => [true,
            new TextEncoder().encode(JSON.stringify(saved))];
        const layout = dock._readDockComponents();
        assert.equal(layout[zone].includes('sound'), true);
        assert.equal(layout.quick.includes('sound'), false);
    }
});

test('Sound appears in Quick on a fresh configuration', () => {
    const {dock} = fixture();
    const layout = dock._readDockComponents();
    assert.equal(layout.visible.includes('sound'), false);
    assert.equal(layout.quick.includes('sound'), true);
});

test('Key Visualizer defaults to Quick and respects saved placement', () => {
    const {dock, context} = fixture();
    const fresh = dock._readDockComponents();
    assert.equal(fresh.quick.includes('key-visualizer'), true);
    context.TextDecoder = TextDecoder;
    context.GLib.file_get_contents = () => [true,
        new TextEncoder().encode(JSON.stringify({visible: ['key-visualizer'],
            hidden: [], quick: []}))];
    const saved = dock._readDockComponents();
    assert.equal(saved.visible.includes('key-visualizer'), true);
    assert.equal(saved.quick.includes('key-visualizer'), false);
});

test('Date and Time default to dock and migrate old Quick placement', () => {
    const {dock, context} = fixture();
    const fresh = dock._readDockComponents();
    for (const name of ['date-display', 'time-display']) {
        assert.equal(fresh.visible.includes(name), true);
        assert.equal(fresh.quick.includes(name), false);
    }
    context.TextDecoder = TextDecoder;
    context.GLib.file_get_contents = () => [true,
        new TextEncoder().encode(JSON.stringify({visible: [], hidden: [],
            quick: ['date-display', 'time-display']}))];
    const saved = dock._readDockComponents();
    assert.equal(saved.visible.includes('date-display'), true);
    assert.equal(saved.visible.includes('time-display'), true);
    assert.equal(saved.quick.includes('date-display'), false);
    assert.equal(saved.quick.includes('time-display'), false);
});

test('Date and Time enter the dock as labels, not panel launchers', () => {
    const {dock} = fixture();
    dock._dockGroupsByName.set('zhyprbola', new Actor());
    dock._dockComponents.visible = ['date-display', 'time-display'];
    dock._createComponentButtons();
    assert.deepEqual(dock._dockItems.get('zhyprbola').map(item => item.kind),
        ['date-time', 'date-time']);
});

test('Daily Key Count defaults beside date and time and renders as an inline label', () => {
    const {dock} = fixture();
    const fresh = dock._readDockComponents();
    assert.equal(fresh.visible.includes('key-count'), true);
    assert.equal(fresh.quick.includes('key-count'), false);
    dock._dockGroupsByName.set('zhyprbola', new Actor());
    dock._dockComponents.visible = ['date-display', 'time-display', 'key-count'];
    dock._createComponentButtons();
    assert.deepEqual(dock._dockItems.get('zhyprbola').map(item => item.kind),
        ['date-time', 'date-time', 'key-count']);
});

test('Daily Key Count updates immediately and resets on the next local date', () => {
    const {dock} = fixture();
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(now.getDate() + 1);
    dock._keyCount = 41;
    dock._keyCountDate = dock._localDateKey(now);
    dock._keyCountDays = {[dock._keyCountDate]: 41};
    dock._keyCountLabels = new Set([{text: ''}]);
    dock._keyCountSaveId = 1;
    dock._recordKeyPress();
    assert.equal(dock._keyCount, 42);
    assert.equal([...dock._keyCountLabels][0].text, 'keys:1d:42');
    dock._saveKeyCount = () => {};
    dock._ensureCurrentKeyCountDate(tomorrow);
    assert.equal(dock._keyCount, 0);
    assert.equal(dock._keyCountDate, dock._localDateKey(tomorrow));
    assert.equal(dock._keyCountDays[dock._keyCountDate], 0);
    assert.equal([...dock._keyCountLabels][0].text, 'keys:1d:0');
});

test('Daily Key Count opens statistics and rotates with a vertical dock', () => {
    const {dock} = fixture();
    dock._keyCount = 1234;
    dock._keyCountLabels = new Set();
    dock._dateTimeLabels = new Map();
    dock._dockItems.set('running', [{kind: 'key-count', name: 'key-count'}]);
    let anchor = null;
    dock._openKeyCountMenu = button => { anchor = button; };
    const group = dock._dockGroupsByName.get('running');
    dock._renderDockRegion('running', 200, false, 0);
    assert.equal(group.children[0].width, 124);
    assert.equal(group.children[0].children[0].text, 'keys:1d:1,234');
    group.children[0].emit('clicked');
    assert.equal(anchor, group.children[0]);
    dock._renderDockRegion('running', 200, true, 0);
    assert.equal(group.children[0].height, 124);
    assert.equal(group.children[0].children[0].children[0].angle, -90);
});

test('Daily Key Count migrates the original single-day state into history', () => {
    const {dock, context} = fixture();
    context.TextDecoder = TextDecoder;
    context.GLib.file_get_contents = () => [true,
        new TextEncoder().encode(JSON.stringify({date: '2026-10-15', count: 321}))];
    dock._localDateKey = () => '2026-10-16';
    dock._loadKeyCount();
    assert.equal(dock._keyCount, 0);
    assert.equal(dock._keyCountDays['2026-10-15'], 321);
});

test('Key statistics aggregate rolling, calendar, best-day, and all-time totals', () => {
    const {dock} = fixture();
    dock._keyCountDays = {
        '2025-12-31': 700,
        '2026-04-15': 600,
        '2026-04-16': 500,
        '2026-07-15': 400,
        '2026-07-16': 300,
        '2026-09-16': 200,
        '2026-10-01': 1,
        '2026-10-02': 5,
        '2026-10-09': 10,
        '2026-10-10': 25,
        '2026-10-15': 50,
        '2026-10-16': 100,
    };
    const stats = Object.fromEntries(dock._keyCountStats(new Date(2026, 9, 16))
        .map(stat => [stat.key, stat.value]));
    assert.deepEqual({...stats}, {
        today: 100,
        '7-days': 175,
        '15-days': 190,
        month: 191,
        '3-months': 691,
        '6-months': 1591,
        year: 2191,
        'best-day': 700,
        all: 2891,
    });
});

test('rolling month statistics clamp month-end cutoffs', () => {
    const {dock} = fixture();
    dock._keyCountDays = {'2026-02-28': 10, '2026-02-27': 20, '2026-05-31': 1};
    const stats = Object.fromEntries(dock._keyCountStats(new Date(2026, 4, 31))
        .map(stat => [stat.key, stat.value]));
    assert.equal(stats['3-months'], 11);
});

test('Key statistics choices update the dock and open without animation', () => {
    const {dock} = fixture();
    dock._keyCount = 1234;
    dock._keyCountDate = '2026-10-16';
    dock._keyCountDays = {'2026-10-15': 100, '2026-10-16': 1234};
    dock._keyCountLabels = new Set([{text: ''}]);
    const stats = dock._keyCountStats.bind(dock);
    dock._keyCountStats = () => stats(new Date(2026, 9, 16));
    const button = new Actor();
    dock._openKeyCountMenu(button);
    assert.equal(dock._keyCountMenu.isOpen, true);
    assert.equal(dock._keyCountMenu.openAnimation, 'none');
    assert.equal(dock._keyCountMenu.items[0].reactive, false);
    assert.equal(dock._keyCountStatLabels.size, 9);
    assert.equal(dock._keyCountStatLabels.get('today').text, '1,234');
    assert.equal(dock._keyCountStatLabels.get('best-day').text, '1,234');
    assert.equal(dock._keyCountMenu.items[2].reactive, true);
    dock._keyCountMenu.items[2].emit('activate');
    assert.equal(dock._keyCountStatKey, '7-days');
    assert.equal([...dock._keyCountLabels][0].text, 'keys:7d:1,334');
    assert.equal(dock._keyCountMenu.closeAnimation, 'none');
    dock._openKeyCountMenu(button);
    assert.equal(dock._keyCountMenu.isOpen, true);
    assert.equal(dock._keyCountMenu.openAnimation, 'none');
});

test('dock date and time follow locale, format and seconds settings', () => {
    const {dock} = fixture();
    const now = new Date(2026, 9, 7, 15, 14, 9);
    dock._dateTimeSettings = {dateFormat: 'yyyy-MM-dd', dateLocale: 'global',
        timeFormat: '24-colon', timeLocale: 'global', showSeconds: false};
    assert.equal(dock._formatDockDate(now), '2026-10-07');
    assert.equal(dock._formatDockTime(now), '15:14');
    dock._dateTimeSettings.dateFormat = 'dd/MM/yyyy';
    dock._dateTimeSettings.dateLocale = 'thai';
    dock._dateTimeSettings.timeLocale = 'thai';
    dock._dateTimeSettings.showSeconds = true;
    assert.equal(dock._formatDockDate(now), '07/10/2569');
    assert.equal(dock._formatDockTime(now), '15:14:09');
    dock._dateTimeSettings.dateFormat = 'yyyy-MM-dd';
    assert.equal(dock._formatDockDate(now), '2569-10-07');
});

test('dock reserves enough region width for inline date and time', () => {
    const {dock} = fixture(828);
    dock._dockGroupOrder = ['apps', 'running', 'zhyprbola'];
    dock._dockRegions = new Map(dock._dockGroupOrder.map(name => [name, new Actor()]));
    dock._dockGroupsByName.set('zhyprbola', new Actor());
    dock._dateTimeSettings = {dateFormat: 'yyyy-MM-dd', dateLocale: 'global',
        timeFormat: '24-colon', timeLocale: 'global', showSeconds: false};
    const names = ['date-display', 'time-display', 'settings', 'bluetooth',
        'wifi', 'clock-weather', 'system-status', 'audio-spectrum', 'music'];
    dock._dockComponents.visible = names;
    dock._dockItems.set('zhyprbola', names.map(name => ({name,
        kind: name.endsWith('-display') ? 'date-time' : 'panel'})));
    dock._renderDockRegion = () => {};
    dock._layoutDock();
    const componentsWidth = dock._dockRegions.get('zhyprbola').width;
    assert.ok(componentsWidth > 828 / 3);
    assert.ok(componentsWidth <= 828);
});

test('dock centers clickable date and time like the input source in both layouts', () => {
    const {dock} = fixture();
    dock._dateTimeSettings = {dateFormat: 'yyyy-MM-dd', dateLocale: 'global',
        timeFormat: '24-colon', timeLocale: 'global', showSeconds: false};
    dock._dateTimeLabels = new Map();
    dock._dockItems.set('running', [
        {kind: 'date-time', name: 'date-display'},
        {kind: 'date-time', name: 'time-display'},
    ]);
    let opened = 0;
    dock._openDateTimeSettings = () => { opened++; };
    const group = dock._dockGroupsByName.get('running');
    dock._renderDockRegion('running', 200, false, 0);
    assert.equal(group.get_children().length, 2);
    assert.equal(group.get_children()[0].width, 106);
    assert.equal(group.get_children()[1].width, 52);
    for (const button of group.get_children()) {
        assert.match(button.style_class, /zhyprbola-dock-button/);
        assert.equal(button.height, 27);
        assert.equal(button.reactive, true);
        assert.equal(button.can_focus, true);
        assert.equal(button.children[0].height, undefined);
        assert.equal(button.children[0].x_align, 0);
        assert.equal(button.children[0].y_align, 0);
        button.emit('clicked');
    }
    assert.equal(opened, 2);
    assert.match(dock._dateTimeLabels.get('date-display').text, /^\d{4}-\d{2}-\d{2}$/);
    dock._renderDockRegion('running', 200, true, 0);
    assert.equal(group.get_children()[0].height, 106);
    assert.equal(group.get_children()[0].children[0].children[0].angle, -90);
    group.get_children()[0].emit('clicked');
    assert.equal(opened, 3);
});

test('side dock labels keep their natural height inside a centered rotated frame', () => {
    for (const side of ['left', 'right']) {
        const {dock, context} = fixture();
        dock._dockPosition = side;
        dock._dateTimeLabels = new Map();
        dock._keyCountLabels = new Set();
        dock._dateTimeItemLength = name => name === 'date-display' ? 180 : 78;
        dock._formatDockDate = () => 'ศุกร์, 23 ต.ค. 2026';
        dock._formatDockTime = () => '19:54:42';
        dock._keyCountText = () => 'keys:1d:8,677';
        const buttons = [dock._createDateTimeWidget('date-display', true),
            dock._createDateTimeWidget('time-display', true),
            dock._createKeyCountWidget(true)];
        for (const button of buttons) {
            const [widget] = button.children;
            const [frame] = widget.children;
            const [label] = frame.children;
            assert.ok(frame.layout_manager instanceof context.Clutter.BinLayout);
            assert.equal(frame.angle, -90);
            assert.equal(frame.pivotX, 0.5);
            assert.equal(frame.pivotY, 0.5);
            assert.equal(frame.x + frame.width / 2, widget.width / 2);
            assert.equal(frame.y + frame.height / 2, widget.height / 2);
            assert.equal(frame.height, button.width);
            assert.equal(frame.width, button.height);
            assert.equal(label.width, button.height - 8);
            assert.equal(label.height, undefined, 'text retains its natural line height');
            assert.equal(label.x_align, context.Clutter.ActorAlign.CENTER);
            assert.equal(label.y_align, context.Clutter.ActorAlign.CENTER);
            assert.equal(label.angle, undefined, 'the centered frame owns the rotation');
        }
        const countLabel = [...dock._keyCountLabels][0];
        countLabel.text = 'keys:1d:9';
        assert.equal(countLabel.height, undefined, 'live text updates retain natural height');
    }
});

test('date and time focus Settings without minimizing an already focused window', () => {
    const {dock, context} = fixture();
    dock._settingsSectionRequestPath = '/config/settings-section-request';
    let saved;
    let opened = 0;
    let focused = true;
    context.GLib.mkdir_with_parents = () => {};
    context.GLib.path_get_dirname = () => '/config';
    context.GLib.get_monotonic_time = () => 123;
    context.GLib.file_set_contents = (path, value) => { saved = {path, value}; };
    context.global = {display: {list_all_windows: () => [{
        get_title: () => 'Zhyprbola Settings',
        has_focus: () => focused,
    }]}};
    dock._openPanel = () => { opened++; };

    dock._openDateTimeSettings();
    assert.deepEqual(saved, {path: '/config/settings-section-request',
        value: '123:date-time\n'});
    assert.equal(opened, 0);
    focused = false;
    dock._openDateTimeSettings();
    assert.equal(opened, 1);
    context.global.display.list_all_windows = () => [];
    dock._openDateTimeSettings();
    assert.equal(opened, 2);
});

test('opening an existing Key Visualizer follows the shared panel toggle', () => {
    const {dock, context} = fixture();
    let activations = 0;
    let focused = false;
    let minimized = true;
    const window = {
        get_title: () => 'Zhyprbola Key Visualizer',
        has_focus: () => focused,
        get minimized() { return minimized; },
        unminimize: () => { minimized = false; },
        activate: () => { activations++; focused = true; },
        minimize: () => { minimized = true; focused = false; },
    };
    context.global = {
        display: {list_all_windows: () => [window]},
        get_current_time: () => 1,
    };
    dock._openPanel('key-visualizer', true);
    assert.equal(activations, 1);
    assert.equal(minimized, false);
    dock._openPanel('key-visualizer');
    assert.equal(activations, 1);
    assert.equal(minimized, true);
});

test('right-click opens GNOME menus without activating an app or window', () => {
    for (const name of ['apps', 'running']) {
        const {dock, group} = fixture();
        const entry = item(1);
        dock._dockUngroupWindows = false;
        const button = dock._createAppButton(entry, name);
        group.add_child(button);
        let activations = 0;
        dock._activateWindow = () => { activations++; };
        assert.equal(button.button_mask, 1);
        const gesture = button.actions[0];
        assert.equal(gesture.required_button, 3);
        assert.equal(gesture.recognize_on_press, true);
        gesture.emit('recognize');
        assert.equal(activations, 0);
        assert.equal(dock._appMenu.app, entry.app);
        assert.equal(dock._appMenu.isOpen, true);
        assert.equal(dock._appMenu.options.favoritesSection, false);
        assert.equal(dock._appMenu.options.showSingleWindows, true);
        button.emit('clicked');
        assert.equal(activations, 1);
    }
});

test('ungrouped Running menu closes only the window represented by its icon', () => {
    const {dock, group, context} = fixture();
    dock._dockUngroupWindows = true;
    context.global = {get_current_time: () => 321};
    const selected = item(1);
    const sibling = item(2);
    let selectedDeletes = 0;
    let siblingDeletes = 0;
    let appQuits = 0;
    selected.window.can_close = () => true;
    selected.window.delete = timestamp => {
        assert.equal(timestamp, 321);
        selectedDeletes++;
    };
    sibling.window.can_close = () => true;
    sibling.window.delete = () => { siblingDeletes++; };
    selected.app.get_windows = () => [selected.window, sibling.window];
    selected.app.request_quit = () => { appQuits++; };

    const button = dock._createAppButton(selected, 'running');
    group.add_child(button);
    button.actions[0].emit('recognize');

    assert.equal(dock._appMenu._quitItem.label.text, 'Close Window');
    dock._appMenu._quitItem.activate();
    assert.equal(selectedDeletes, 1);
    assert.equal(siblingDeletes, 0);
    assert.equal(appQuits, 0);
});

test('grouped Running menu keeps GNOME Quit at app scope', () => {
    const {dock, group} = fixture();
    dock._dockUngroupWindows = false;
    const entry = item(1);
    let appQuits = 0;
    entry.app.request_quit = () => { appQuits++; };
    const button = dock._createAppButton(entry, 'running');
    group.add_child(button);

    button.actions[0].emit('recognize');
    assert.equal(dock._appMenu._quitItem.label.text, 'Quit');
    dock._appMenu._quitItem.activate();
    assert.equal(appQuits, 1);
});

test('repeated right-click toggles the existing menu and switching icons destroys it', () => {
    const {dock, group, render} = fixture();
    render([item(1), item(2)]);
    const [a, b] = group.children;
    a.actions[0].emit('recognize');
    const menu = dock._appMenu;
    a.actions[0].emit('recognize');
    assert.equal(menu.isOpen, false);
    assert.equal(dock._appMenu, menu);
    b.actions[0].emit('recognize');
    assert.equal(menu.destroyed, true);
    assert.equal(dock._appMenu.sourceActor, b);
    assert.equal(dock._appMenu.isOpen, true);
});

test('a menu survives focus refresh but is destroyed when its source window closes', () => {
    const {dock, group, render} = fixture();
    const entry = item(1);
    render([entry]);
    group.children[0].actions[0].emit('recognize');
    const menu = dock._appMenu;
    render([{...entry, label: 'New title'}, item(2)]);
    assert.equal(dock._appMenu, menu);
    assert.equal(menu.isOpen, true);
    render([item(2)]);
    assert.equal(menu.destroyed, true);
    assert.equal(dock._appMenu, null);
});

test('keyboard popup focuses the menu and dragging closes it without reopening', () => {
    const {dock, group, render} = fixture();
    render([item(1)]);
    const button = group.children[0];
    button.emit('popup-menu');
    const menu = dock._appMenu;
    assert.equal(menu.actor.focusNavigated, true);
    button.draggable.emit('drag-begin');
    assert.equal(menu.isOpen, false);
    button.actions[0].emit('recognize');
    assert.equal(menu.isOpen, false);
    button.draggable.emit('drag-end');
});

test('dock teardown destroys the context menu before its source actor', () => {
    const {dock, group, render} = fixture();
    render([item(1)]);
    group.children[0].actions[0].emit('recognize');
    const menu = dock._appMenu;
    dock._destroyDock();
    assert.equal(menu.destroyed, true);
    assert.equal(dock._appMenu, null);
});

test('Sound requests open a Shell popup anchored to Components without launching a panel', () => {
    const {dock, group} = fixture();
    dock._themeName = 'mauve';
    dock._dockGroupsByName.set('zhyprbola', group);
    const button = new Actor({_panelName: 'components'});
    group.add_child(button);
    dock._openPanel('sound', true);
    const menu = dock._soundMenu;
    assert.equal(menu.sourceActor, button);
    assert.equal(menu.isOpen, true);
    dock._openPanel('sound', true);
    assert.equal(menu.isOpen, false);
    dock._destroyDock();
    assert.equal(menu.destroyed, true);
});


function orderedRunningFixture() {
    const setup = fixture();
    const windows = [item(1, 'TikTok'), item(2, 'Monkeytype'), item(3, 'Translate')];
    const live = windows.map(candidate => candidate.window);
    setup.context.global.display = {list_all_windows: () => live};
    setup.dock._appSystem = {get_running: () => windows.map(candidate => candidate.app)};
    setup.dock._windowTracker = {get_window_app: window =>
        windows.find(candidate => candidate.window === window)?.app};
    const refresh = items => {
        setup.render(setup.dock._orderRunningItems([...items]));
        return setup.group.children.filter(button => button._delegate?.item)
            .map(button => button._delegate.item.window.get_stable_sequence());
    };
    refresh(windows);
    setup.dock._commitDockItemOrder('running', [windows[2], windows[0], windows[1]]
        .map(candidate => setup.dock._itemOrderKey(candidate)));
    setup.flush();
    return {...setup, windows, live, refresh};
}

test('dragged running windows keep their slots across transient omission and title/focus changes', () => {
    const {windows: [a, b, c], refresh} = orderedRunningFixture();
    assert.deepEqual(refresh([b, c, a]), [3, 1, 2]);
    assert.deepEqual(refresh([a, b]), [1, 2]);
    c.window.focused = true;
    c.label = 'A different Chrome tab';
    assert.deepEqual(refresh([b, c, a]), [3, 1, 2]);
    assert.deepEqual(refresh([]), []);
    assert.deepEqual(refresh([a, b, c]), [3, 1, 2]);
});

test('running window identity survives app reassociation', () => {
    const {windows: [a, b, c], refresh} = orderedRunningFixture();
    const reassociated = {...c, app: {...c.app, get_id: () => 'chrome-new.desktop'}};
    assert.deepEqual(refresh([a, reassociated, b]), [3, 1, 2]);
});

test('dragging while a window is temporarily absent keeps unique order slots', () => {
    const {dock, windows: [a, b, c], refresh, flush} = orderedRunningFixture();
    refresh([a, b]);
    dock._commitDockItemOrder('running', [b, a].map(candidate => dock._itemOrderKey(candidate)));
    flush();
    refresh([c, b, a]);
    const ranks = [...dock._runningOrder.values()];
    assert.equal(new Set(ranks).size, ranks.length);
    assert.deepEqual(refresh([a, c, b]), [2, 1, 3]);
});

test('closed windows release their order slots and newly opened windows append', () => {
    const {dock, windows: [a, b, c], live, refresh} = orderedRunningFixture();
    live.splice(live.indexOf(c.window), 1);
    assert.deepEqual(refresh([a, b]), [1, 2]);
    assert.equal(dock._runningOrder.has(dock._itemOrderKey(c)), false);
    const reopened = item(4, 'Translate');
    live.push(reopened.window);
    assert.deepEqual(refresh([reopened, b, a]), [1, 2, 4]);
});


test('switching grouped mode and back preserves the dragged order of live windows', () => {
    const {dock, windows: [a, b, c], refresh} = orderedRunningFixture();
    const grouped = {kind: 'app', app: a.app, label: 'Chrome', running: true};
    dock._dockItems.set('running', dock._orderRunningItems([grouped]));
    assert.deepEqual(refresh([b, a, c]), [3, 1, 2]);
});

test('windows without native IDs keep distinct identities when titles change', () => {
    const {dock} = fixture();
    const a = item(1, 'Same title'), b = item(2, 'Same title');
    delete a.window.get_stable_sequence;
    delete b.window.get_stable_sequence;
    const originalKey = dock._itemOrderKey(a);
    assert.notEqual(originalKey, dock._itemOrderKey(b));
    a.window.get_title = () => 'Changed title';
    assert.equal(dock._itemOrderKey(a), originalKey);
});


test('Brightness migrates to Quick and respects explicit saved placement', () => {
    const {dock, context} = fixture();
    assert.equal(dock._readDockComponents().quick.includes('brightness'), true);
    context.TextDecoder = TextDecoder;
    for (const zone of ['visible', 'hidden', 'quick']) {
        const saved = {visible: [], hidden: [], quick: []};
        saved[zone] = ['brightness'];
        context.GLib.file_get_contents = () => [true,
            new TextEncoder().encode(JSON.stringify(saved))];
        const layout = dock._readDockComponents();
        assert.equal(layout[zone].filter(name => name === 'brightness').length, 1);
        assert.equal(['visible', 'hidden', 'quick'].filter(key =>
            layout[key].includes('brightness')).length, 1);
    }
    context.GLib.file_get_contents = () => [true,
        new TextEncoder().encode(JSON.stringify({visible: ['settings'], hidden: [], quick: ['wifi']}))];
    const layout = dock._readDockComponents();
    assert.equal(layout.visible.includes('brightness'), false);
    assert.equal(layout.quick.includes('brightness'), true);
});

test('Brightness opens from Settings on Components, toggles, and is destroyed with the dock', () => {
    const {dock, group} = fixture();
    dock._themeName = 'mauve';
    dock._dockGroupsByName.set('zhyprbola', group);
    const button = new Actor({_panelName: 'components'});
    group.add_child(button);
    dock._openPanel('brightness', true);
    const menu = dock._brightnessMenu;
    assert.equal(menu.sourceActor, button);
    assert.equal(menu.isOpen, true);
    dock._openPanel('brightness', true);
    assert.equal(menu.isOpen, false);
    dock._destroyDock();
    assert.equal(menu.destroyed, true);
});

test('Battery migrates to Quick and respects explicit saved placement', () => {
    const {dock, context} = fixture();
    assert.equal(dock._readDockComponents().quick.includes('battery'), true);
    context.TextDecoder = TextDecoder;
    for (const zone of ['visible', 'hidden', 'quick']) {
        const saved = {visible: [], hidden: [], quick: []};
        saved[zone] = ['battery'];
        context.GLib.file_get_contents = () => [true,
            new TextEncoder().encode(JSON.stringify(saved))];
        const layout = dock._readDockComponents();
        assert.equal(layout[zone].filter(name => name === 'battery').length, 1);
        assert.equal(['visible', 'hidden', 'quick'].filter(key =>
            layout[key].includes('battery')).length, 1);
    }
    context.GLib.file_get_contents = () => [true,
        new TextEncoder().encode(JSON.stringify({visible: ['settings'], hidden: [], quick: ['wifi']}))];
    const layout = dock._readDockComponents();
    assert.equal(layout.visible.includes('battery'), false);
    assert.equal(layout.quick.includes('battery'), true);
});

test('Battery opens from Settings on Components, toggles, and is destroyed with the dock', () => {
    const {dock, group} = fixture();
    dock._themeName = 'mauve';
    dock._dockGroupsByName.set('zhyprbola', group);
    const button = new Actor({_panelName: 'components'});
    group.add_child(button);
    dock._openPanel('battery', true);
    const menu = dock._batteryMenu;
    assert.equal(menu.sourceActor, button);
    assert.equal(menu.isOpen, true);
    dock._openPanel('battery', true);
    assert.equal(menu.isOpen, false);
    dock._destroyDock();
    assert.equal(menu.destroyed, true);
});

test('connection names use the active SSID and connected Bluetooth device', () => {
    const {dock} = fixture();
    assert.equal(dock._parseConnectionName('wifi', 'no:Other\nyes:Home\\:WiFi\\\\Lab\n'),
        'Home:WiFi\\Lab');
    assert.deepEqual({...dock._parseWifiConnection(
        'no:42:Other\nyes:78:Home\\:WiFi\\\\Lab\n')},
    {name: 'Home:WiFi\\Lab', strength: 78});
    assert.equal(dock._parseConnectionName('wifi', 'no:Other\n'), '');
    assert.equal(dock._parseConnectionName('bluetooth',
        '\x1b[0;94mDevice AA:BB:CC:DD:EE:FF My Headphones\x1b[0m\n'), 'My Headphones');
    assert.equal(dock._parseConnectionName('bluetooth', 'No default controller available\n'), '');
});

test('connection icons distinguish disabled radios and Wi-Fi signal levels', () => {
    const {dock} = fixture();
    dock._connectionNames = {wifi: 'Home', bluetooth: ''};
    dock._connectionStates = {wifi: {enabled: true, strength: 12},
        bluetooth: {enabled: false}};
    assert.equal(dock._connectionIconName('wifi'), 'wifi-weak');
    assert.equal(dock._connectionAccessibleName('wifi', 'Wi-Fi'),
        'Wi-Fi: Home, Weak signal');
    assert.equal(dock._connectionIconName('bluetooth'), 'bluetooth-off');
    assert.equal(dock._connectionAccessibleName('bluetooth', 'Bluetooth'), 'Bluetooth: Off');

    dock._connectionStates.wifi.strength = 50;
    assert.equal(dock._connectionIconName('wifi'), 'wifi-medium');
    dock._connectionStates.wifi.strength = 82;
    assert.equal(dock._connectionIconName('wifi'), 'wifi-strong');
    dock._connectionStates.wifi.enabled = false;
    assert.equal(dock._connectionIconName('wifi'), 'wifi-off');
    assert.equal(dock._connectionAccessibleName('wifi', 'Wi-Fi'), 'Wi-Fi: Off');
});

test('connection refresh tokens request an immediate dock status refresh', () => {
    const {dock} = fixture();
    Object.assign(dock, {_themeName: 'current', _dockBgOpacity: 50,
        _dockUngroupWindows: false, _useWallpaper: false, _edgeEnabled: false,
        _edgePosition: 'bottom', _dockGroups: ['zhyprbola'], _dateTimeSettings: {},
        _pinnedApps: null});
    dock._connectionRefreshToken = 'old';
    dock._readConnectionRefreshToken = () => 'new';
    dock._readTheme = () => dock._themeName;
    dock._readDockPosition = () => dock._dockPosition;
    dock._readDockBgOpacity = () => dock._dockBgOpacity;
    dock._readDockUngroupWindows = () => dock._dockUngroupWindows;
    dock._readUseWallpaper = () => dock._useWallpaper;
    dock._readEdgeEnabled = () => dock._edgeEnabled;
    dock._readEdgePosition = () => dock._edgePosition;
    dock._readDockGroups = () => dock._dockGroups;
    dock._readDockGroupOrder = () => dock._dockGroupOrder;
    dock._readDockComponents = () => dock._dockComponents;
    dock._readDateTimeSettings = () => dock._dateTimeSettings;
    dock._readPinnedApps = () => dock._pinnedApps;
    dock._handlePanelRequest = () => {};
    let refreshes = 0;
    dock._refreshConnections = () => refreshes++;
    dock._syncSettings();
    assert.equal(refreshes, 1);
    assert.equal(dock._connectionRefreshToken, 'new');
});

test('connection refresh requests queue behind an in-flight probe', async () => {
    const {dock} = fixture();
    dock._disabling = false;
    dock._connectionRefreshPending = true;
    dock._connectionRefreshQueued = false;
    await dock._refreshConnections();
    assert.equal(dock._connectionRefreshQueued, true);
});

test('connected dock buttons show an icon followed by 12 Unicode characters and dots on every side', () => {
    for (const side of ['bottom', 'top', 'left', 'right']) {
        const {dock} = fixture();
        dock._dockPosition = side;
        dock._panelGicon = name => name;
        dock._connectionNames = {wifi: 'WiFi😀123456789-long', bluetooth: 'Headphones123456'};
        for (const name of ['wifi', 'bluetooth']) {
            const button = dock._createPanelButton({iconName: name,
                accessibleName: name, panelName: name});
            const vertical = side === 'left' || side === 'right';
            const child = button.children[0];
            const frame = vertical ? child.children[0] : null;
            const content = vertical ? frame.children[0] : child;
            const [icon, label] = content.children;
            assert.equal(icon.gicon, name);
            assert.equal(content.vertical, false);
            assert.equal(content.style_class, 'zhyprbola-dock-connection-row');
            assert.equal(icon.y_align, 0);
            assert.equal(label.y_align, 0);
            assert.equal(icon.y_expand, false);
            assert.equal(label.y_expand, false);
            assert.equal(label.style_class, 'zhyprbola-dock-connection-label');
            assert.equal(label.text, Array.from(dock._connectionNames[name]).slice(0, 12).join('') + '...');
            assert.equal(label.clutter_text.ellipsize, 0);
            assert.equal(vertical ? button.width : button.height, 27);
            assert.equal(vertical ? button.height : button.width, 152);
            assert.equal(dock._panelIcons.get(name), icon);
            if (vertical) {
                assert.equal(frame.angle, -90);
                assert.equal(frame.x + frame.width / 2, child.width / 2);
                assert.equal(frame.y + frame.height / 2, child.height / 2);
            }
        }
    }
});

test('short and exactly 12-character connection names do not gain dots', () => {
    const {dock} = fixture();
    for (const name of ['Home', '123456789012', '😀12345678901'])
        assert.equal(dock._connectionLabel(name).text, name);
});

test('connection changes rerender dock labels and restore icons after disconnect', () => {
    const {dock, group} = fixture(800);
    dock._panelGicon = name => name;
    dock._connectionNames = {wifi: '', bluetooth: ''};
    dock._dateTimeLabels = new Map();
    dock._dockGroupsByName.set('zhyprbola', group);
    dock._dockItems.set('zhyprbola', ['wifi', 'bluetooth'].map(name =>
        ({kind: 'panel', name, label: name})));
    const render = () => dock._renderDockRegion('zhyprbola', 400, false, 0);
    render();
    assert.equal(group.children[0].children[0].gicon, 'wifi');
    dock._connectionNames.wifi = 'Home';
    render();
    assert.equal(group.children[0].children[0].children[1].text, 'Home');
    dock._connectionNames.wifi = 'Work';
    render();
    assert.equal(group.children[0].children[0].children[1].text, 'Work');
    dock._connectionNames.wifi = '';
    render();
    assert.equal(group.children[0].children[0].gicon, 'wifi');
    assert.equal(group.children[1].children[0].gicon, 'bluetooth');
    assert.equal(group.width, 58);
});

test('Wi-Fi signal changes rerender the dock icon', () => {
    const {dock, group} = fixture(800);
    dock._panelGicon = name => name;
    dock._connectionNames = {wifi: 'Home', bluetooth: ''};
    dock._connectionStates = {wifi: {enabled: true, strength: 20},
        bluetooth: {enabled: true}};
    dock._dateTimeLabels = new Map();
    dock._dockGroupsByName.set('zhyprbola', group);
    dock._dockItems.set('zhyprbola', [{kind: 'panel', name: 'wifi', label: 'Wi-Fi'}]);
    const render = () => dock._renderDockRegion('zhyprbola', 400, false, 0);
    render();
    assert.equal(group.children[0].children[0].children[0].gicon, 'wifi-weak');
    dock._connectionStates.wifi.strength = 90;
    render();
    assert.equal(group.children[0].children[0].children[0].gicon, 'wifi-strong');
});


test('key counter fallback suppresses held repeats and avoids a ready helper', () => {
    const {dock, context} = fixture();
    context.Clutter.EventType = {KEY_PRESS: 1, KEY_RELEASE: 2};
    context.Clutter.EVENT_PROPAGATE = 0;
    let count = 0;
    dock._recordKeyPress = () => count++;
    dock._keyCountPressed = new Set();
    const press = {type: () => 1, get_key_code: () => 38};
    const release = {type: () => 2, get_key_code: () => 38};
    assert.equal(dock._onKeyCountEvent(press), 0);
    dock._onKeyCountEvent(press);
    assert.equal(count, 1);
    dock._onKeyCountEvent(release);
    assert.equal(count, 1);
    dock._setKeyCounterReady(true);
    dock._onKeyCountEvent(press);
    assert.equal(count, 1);
    dock._onKeyCountEvent(release);
    dock._setKeyCounterReady(false);
    dock._onKeyCountEvent(press);
    assert.equal(count, 2);
    dock._onKeyCountEvent(release);
    dock._disabling = true;
    dock._onKeyCountEvent(press);
    assert.equal(count, 2);
});

test('key count access uses existing choice styling and hides when ready', () => {
    const {dock} = fixture();
    dock._keyCountDays = {};
    dock._openKeyCountMenu(new Actor());
    assert.match(dock._keyCountStatusLabel.text, /Limited to GNOME/);
    const access = dock._keyCountAccessItem;
    assert.ok(access.styleClasses.includes('zhyprbola-key-count-choice'));
    assert.equal(access.visible, true);
    let requested = false;
    dock._grantKeyCountAccess = () => { requested = true; };
    access.emit('activate');
    assert.equal(requested, true);
    dock._setKeyCounterReady(true);
    assert.equal(dock._keyCountStatusLabel.text, 'Counting across applications');
    assert.equal(access.visible, false);
    dock._setKeyCounterReady(false);
    assert.equal(access.visible, true);
    dock._keyCountMenu.destroy();
    assert.equal(dock._keyCountStatusLabel, null);
});


test('helper readiness switches counting and stale helper output is ignored', () => {
    const {dock, context} = fixture();
    context.GLib.PRIORITY_DEFAULT = 0;
    const process = {};
    dock._keyCountProcess = process;
    let count = 0;
    dock._recordKeyPress = () => count++;
    const lines = ['{"type":"ready"}', '{"type":"press"}', null];
    const stream = {
        read_line_async(_priority, _cancel, callback) { callback(this, {}); },
        read_line_finish_utf8() { return [lines.shift()]; },
    };
    dock._readKeyCounterLine(process, stream, {});
    assert.equal(dock._keyCountReady, true);
    assert.equal(count, 1);
    lines.push('{"type":"press"}');
    dock._keyCountProcess = {};
    dock._readKeyCounterLine(process, stream, {});
    assert.equal(count, 1);
});


test('direct keyboard authorization waits, retries after denial, and reconnects on success', () => {
    const {dock, context} = fixture();
    dock.path = '/extension';
    dock._keyCountDays = {};
    dock._openKeyCountMenu(new Actor());
    context.GLib.build_filenamev = parts => parts.join('/');
    context.GLib.source_remove = () => {};
    let callback;
    let success = false;
    let launches = 0;
    const process = {
        wait_async(_cancel, cb) { callback = cb; },
        wait_finish() {}, get_successful: () => success,
    };
    context.Gio = {
        SubprocessFlags: {STDOUT_SILENCE: 1, STDERR_SILENCE: 2},
        Subprocess: {new(args) {
            assert.deepEqual(Array.from(args), ['pkexec', '/extension/grant-key-capture']);
            launches++;
            return process;
        }},
    };
    dock._grantKeyCountAccess();
    assert.equal(dock._keyCountStatusLabel.text, 'Waiting for permission…');
    assert.equal(dock._keyCountAccessItem.sensitive, false);
    dock._grantKeyCountAccess();
    assert.equal(launches, 1);
    callback(process, {});
    assert.match(dock._keyCountStatusLabel.text, /cancelled or unavailable/);
    assert.equal(dock._keyCountAccessItem.sensitive, true);
    let restarted = false;
    dock._startKeyCounter = evdev => { restarted = evdev; };
    dock._keyCountRetryId = 123;
    success = true;
    dock._grantKeyCountAccess();
    callback(process, {});
    assert.equal(restarted, true);
    assert.equal(dock._keyCountRetryId, 0);
    dock._setKeyCounterReady(true);
    dock._grantKeyCountAccess();
    assert.equal(launches, 2);
});

test('authorization spawn errors remain retryable and late callbacks are ignored', () => {
    const {dock, context} = fixture();
    dock._keyCountDays = {};
    dock._openKeyCountMenu(new Actor());
    context.GLib.build_filenamev = parts => parts.join('/');
    context.Gio = {SubprocessFlags: {}, Subprocess: {new() { throw Error('missing'); }}};
    dock._grantKeyCountAccess();
    assert.match(dock._keyCountStatusLabel.text, /Could not request permission/);
    assert.equal(dock._keyCountAccessItem.sensitive, true);
    let callback;
    context.Gio.Subprocess.new = () => ({wait_async(_cancel, cb) { callback = cb; }});
    dock._grantKeyCountAccess();
    dock._keyCountGrantProcess = null;
    dock._disabling = true;
    callback({wait_finish() { assert.fail('stale callback'); }}, {});
});
