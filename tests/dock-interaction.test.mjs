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
    set_pivot_point(x, y) { Object.assign(this, {pivotX: x, pivotY: y}); }
    set_rotation_angle(axis, angle) { Object.assign(this, {rotationAxis: axis, angle}); }
    add_style_class_name() { this.live(); }
    remove_style_class_name() { this.live(); }
    add_style_pseudo_class() { this.live(); }
    remove_style_pseudo_class() { this.live(); }
    ease(props) { this.live(); Object.assign(this, props); }
}

class NativeAppMenu {
    constructor(sourceActor, side, options) {
        Object.assign(this, {sourceActor, side, options, actor: new Actor(), isOpen: false});
    }
    setApp(app) { this.app = app; }
    open() { this.isOpen = true; }
    close() { this.isOpen = false; }
    toggle() { this.isOpen = !this.isOpen; }
    destroy() { this.close(); this.actor.destroy(); this.destroyed = true; }
}

function fixture(length = 400) {
    const idles = new Map();
    let nextId = 0;
    const context = vm.createContext({
        St: {Widget: Actor, Icon: Actor, Button: Actor,
            Label: class extends Actor {
                constructor(props) { super(props); this.clutter_text = {}; }
            }, ButtonMask: {ONE: 1},
            Side: {LEFT: 0, RIGHT: 1, TOP: 2, BOTTOM: 3},
            DirectionType: {TAB_FORWARD: 0}},
        Clutter: {FixedLayout: class {}, AnimationMode: {EASE_OUT_QUAD: 0},
            RotateAxis: {Z_AXIS: 2}, ActorAlign: {CENTER: 0},
            ClickGesture: Actor, BUTTON_SECONDARY: 3},
        Pango: {EllipsizeMode: {END: 3}},
        DND: {makeDraggable: actor => (actor.draggable = new Actor())},
        GLib: {PRIORITY_DEFAULT_IDLE: 0, SOURCE_REMOVE: false,
            idle_add: (_, callback) => { idles.set(++nextId, callback); return nextId; }},
        Main: {layoutManager: {primaryMonitor: {x: 0, y: 0, width: length + 8, height: 900},
            removeChrome() {}}, uiGroup: new Actor()},
        AppMenu: NativeAppMenu,
        SoundMenu: NativeAppMenu,
        BrightnessMenu: NativeAppMenu,
        PopupMenu: {PopupMenuManager: class {}},
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
    return {dock, group, render, flush, idles, context};
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
            minimize() { this.minimized = true; this.minimizeCalls++; },
            unminimize() { this.minimized = false; this.restoreCalls++; },
            activate() { this.activateCalls++; }, ...options};
        windows.push(window);
        return window;
    };
    return {dock, display, windows, workspace, otherWorkspace, addWindow,
        switchWorkspace(value) { activeWorkspace = value; }};
}

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

test('partially reopening saved windows still hides visible windows in one click', () => {
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
    assert.equal(b.minimized, false);
});

test('a new visible window is hidden without restoring windows from the previous round', () => {
    const {dock, addWindow} = desktopFixture();
    const a = addWindow(1);
    dock._toggleDesktop();
    const b = addWindow(2);
    dock._toggleDesktop();
    assert.equal(a.minimized, true);
    assert.equal(b.minimized, true);
    dock._toggleDesktop();
    assert.equal(a.minimized, false);
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
    assert.equal(dock._formatDockDate(now), '๐๗/๑๐/๒๕๖๙');
    assert.equal(dock._formatDockTime(now), '๑๕:๑๔:๐๙');
});

test('dock reserves enough region width for inline date and time', () => {
    const {dock} = fixture(828);
    dock._dockGroupOrder = ['apps', 'running', 'zhyprbola'];
    dock._dockRegions = new Map(dock._dockGroupOrder.map(name => [name, new Actor()]));
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
    assert.ok(componentsWidth <= 828 * 0.68);
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

test('right-click opens GNOME menus for Apps and Running without activating a window', () => {
    for (const name of ['apps', 'running']) {
        const {dock, group} = fixture();
        const entry = item(1);
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
    setup.context.global = {display: {list_all_windows: () => live}};
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
