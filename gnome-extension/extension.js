import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as DND from 'resource:///org/gnome/shell/ui/dnd.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Keyboard from 'resource:///org/gnome/shell/ui/status/keyboard.js';

const DockPosition = Object.freeze({
    LEFT: 'left',
    RIGHT: 'right',
    TOP: 'top',
    BOTTOM: 'bottom',
});

const DEFAULT_DOCK_POSITION = DockPosition.BOTTOM;
const SHOW_DESKTOP_SIZE = 10;

const DOCK_CONFIG = Object.freeze({
    iconSize: 16,
    buttonSize: 27,
    groupSpacing: 4,
    padding: 4,
});
const QUICK_MENU_CONFIG = Object.freeze({
    maxColumns: 5,
});

const DOCK_GROUPS = ['apps', 'running', 'zhyprbola'];
const DEFAULT_ENABLED_DOCK_GROUPS = ['zhyprbola', 'running'];
const DEFAULT_DOCK_GROUP_ORDER = ['apps', 'running', 'zhyprbola'];
const DOCK_COMPONENTS = [
    ['settings', 'Zhyprbola settings'],
    ['bluetooth', 'Bluetooth'],
    ['wifi', 'Wi-Fi'],
    ['clock-weather', 'Clock and Weather'],
    ['system-status', 'System Status'],
    ['audio-spectrum', 'Audio Spectrum'],
    ['music', 'Music Player'],
    ['todo', 'Tasks'],
    ['calendar', 'Calendar'],
    ['input-source', 'Input Source'],
    ['power', 'Power'],
    ['components', 'Components'],
];
const DEFAULT_PINNED_APPS = [
    ['google-chrome.desktop', 'com.google.Chrome.desktop', 'chromium.desktop'],
    ['org.gnome.Terminal.desktop', 'org.gnome.Console.desktop', 'kgx.desktop',
        'kitty.desktop'],
    ['org.gnome.TextEditor.desktop', 'org.gnome.gedit.desktop', 'xpad.desktop'],
    ['code.desktop', 'code-oss.desktop'],
];
const THEMES = [
    {name: 'current', wallpaper: '1.png', iconColor: '#875a82'},
    {name: 'white', wallpaper: '2.png', iconColor: '#467b9d'},
    {name: 'white-sky', wallpaper: '3.png', iconColor: '#1e73e7'},
    {name: 'forest', wallpaper: '4.png', iconColor: '#477f6d'},
    {name: 'one-half-gray', wallpaper: '5.png', iconColor: '#68717d'},
    {name: 'red', wallpaper: '6.png', iconColor: '#b83252'},
    {name: 'mauve', wallpaper: '7.png', iconColor: '#c45478'},
];

const PANEL_TITLES = Object.freeze({
    bluetooth: 'Zhyprbola Bluetooth',
    wifi: 'Zhyprbola Wi-Fi',
    'clock-weather': 'Zhyprbola Clock & Weather',
    'system-status': 'Zhyprbola System Status',
    'audio-spectrum': 'Zhyprbola Audio Spectrum',
    music: 'Zhyprbola Music Player',
    todo: 'Zhyprbola Tasks',
    calendar: 'Zhyprbola Calendar',
    settings: 'Zhyprbola Settings',
});

export default class ZhyprbolaExtension extends Extension {
    enable() {
        this._disabling = false;
        this._dockInteractions = new Set();
        this._dockRebuildPending = false;
        this._dock = null;
        this._showDesktopButton = null;
        this._desktopWindows = new Map();
        this._layoutIdleId = 0;
        this._appRefreshId = 0;
        this._wallpaperRefreshId = 0;
        this._settingsPlacementId = 0;
        this._edgePlacementId = 0;
        this._edgeProcess = null;
        this._settingsSyncId = 0;
        this._settingsMonitor = null;
        this._panelRequestId = 0;
        this._panelRequestPollId = 0;
        this._panelRequestMonitor = null;
        this._pendingPanels = new Set();
        this._lastFocusedWindow = global.display.focus_window;
        this._windowBeforeSettings = null;
        this._panelIconSources = new Map();
        this._inputSourceMenu = null;
        this._inputSourceButton = null;
        this._inputSourceLabel = null;
        this._inputSourceMenuCloseId = 0;
        this._runningOrder = new Map();
        this._nextRunningOrder = 0;
        this._themePath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'theme']);
        this._dockPositionPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-position']);
        this._dockBgOpacityPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-bg-opacity']);
        this._dockUngroupWindowsPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-ungroup-windows']);
        this._useWallpaperPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'use-wallpaper']);
        this._edgeEnabledPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'edge-spectrum-enabled']);
        this._edgePositionPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'edge-spectrum-position']);
        this._dockGroupsPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-groups']);
        this._dockGroupOrderPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-group-order']);
        this._dockComponentsPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-components']);
        this._pinnedAppsPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'pinned-apps']);
        this._panelRequestPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'panel-request']);
        this._themeName = this._readTheme();
        this._dockPosition = this._readDockPosition();
        this._dockBgOpacity = this._readDockBgOpacity();
        this._dockUngroupWindows = this._readDockUngroupWindows();
        this._useWallpaper = this._readUseWallpaper();
        this._edgeEnabled = this._readEdgeEnabled();
        this._edgePosition = this._readEdgePosition();
        this._dockGroups = this._readDockGroups();
        this._dockGroupOrder = this._readDockGroupOrder();
        this._dockComponents = this._readDockComponents();
        this._pinnedApps = this._readPinnedApps();
        this._panelRequest = this._readPanelRequest();
        this._appSystem = Shell.AppSystem.get_default();
        this._windowTracker = Shell.WindowTracker.get_default();
        this._backgroundSettings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.background',
        });
        this._inputSourceSettings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.input-sources',
        });
        this._inputSourceManager = Keyboard.getInputSourceManager?.() ?? null;

        this._createDock();
        this._applyDockPosition();
        this._applyTheme();
        this._applyWallpaper(true);
        this._watchSettings();
        this._startPanelRequestPolling();
        this._startEdgeSpectrum();

        this._appSystem.connectObject('app-state-changed',
            () => this._queueAppRefresh(), this);
        this._windowTracker.connectObject('tracked-windows-changed',
            () => this._queueAppRefresh(), this);

        global.display.connectObject(
            'workareas-changed', () => this._queueLayout(),
            'window-created', () => this._queueAppRefresh(),
            'notify::focus-window', () => {
                const focused = global.display.focus_window;
                // Clicking a launcher in Settings gives Settings focus first.
                if (focused?.get_title() === PANEL_TITLES.settings)
                    this._windowBeforeSettings = this._lastFocusedWindow;
                else if (focused)
                    this._windowBeforeSettings = null;
                if (focused)
                    this._lastFocusedWindow = focused;
                this._updateShowDesktopState();
                this._queueAppRefresh();
            }, this);
        global.workspace_manager.connectObject('active-workspace-changed',
            () => this._updateShowDesktopState(), this);
        Main.layoutManager.connectObject('monitors-changed', () => {
            this._queueLayout();
            this._restartEdgeSpectrum();
        }, this);
        this._inputSourceSettings.connectObject(
            'changed::current', () => this._queueInputSourceRefresh(),
            'changed::sources', () => this._queueInputSourceRefresh(), this);
        try {
            this._inputSourceManager?.connectObject(
                'current-source-changed', () => this._queueInputSourceRefresh(),
                'sources-changed', () => this._queueInputSourceRefresh(), this);
        } catch (error) {
            logError(error, 'Failed to watch GNOME input source manager');
        }
    }

    disable() {
        this._disabling = true;
        global.display.disconnectObject(this);
        global.workspace_manager.disconnectObject(this);
        Main.layoutManager.disconnectObject(this);
        this._appSystem.disconnectObject(this);
        this._windowTracker.disconnectObject(this);
        this._inputSourceSettings.disconnectObject(this);
        this._inputSourceManager?.disconnectObject?.(this);

        if (this._layoutIdleId) {
            GLib.source_remove(this._layoutIdleId);
            this._layoutIdleId = 0;
        }
        if (this._appRefreshId) {
            GLib.source_remove(this._appRefreshId);
            this._appRefreshId = 0;
        }
        if (this._inputSourceMenuCloseId) {
            GLib.source_remove(this._inputSourceMenuCloseId);
            this._inputSourceMenuCloseId = 0;
        }

        this._cancelWallpaperRefresh();
        if (this._settingsPlacementId) {
            GLib.source_remove(this._settingsPlacementId);
            this._settingsPlacementId = 0;
        }
        this._stopEdgeSpectrum();
        if (this._settingsSyncId) {
            GLib.source_remove(this._settingsSyncId);
            this._settingsSyncId = 0;
        }
        this._settingsMonitor?.cancel();
        this._settingsMonitor = null;
        if (this._panelRequestId) {
            GLib.source_remove(this._panelRequestId);
            this._panelRequestId = 0;
        }
        if (this._panelRequestPollId) {
            GLib.source_remove(this._panelRequestPollId);
            this._panelRequestPollId = 0;
        }
        this._panelRequestMonitor?.cancel();
        this._panelRequestMonitor = null;
        this._restoreDesktopWindows();
        this._destroyDock();
        this._appSystem = null;
        this._windowTracker = null;
        this._backgroundSettings = null;
        this._inputSourceSettings = null;
        this._inputSourceManager = null;
        this._panelIconSources = null;
        this._runningOrder = null;
        this._lastFocusedWindow = null;
        this._windowBeforeSettings = null;
    }

    _createDock() {
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT].includes(this._dockPosition);
        this._dock = new St.BoxLayout({
            style_class: `zhyprbola-dock zhyprbola-dock-${this._dockPosition}`,
            style: 'spacing: 0;',
            vertical,
            reactive: true,
            track_hover: true,
        });
        if (vertical)
            this._dock.add_style_class_name('zhyprbola-dock-vertical');

        this._dockGroupsByName = new Map();
        this._dockRegions = new Map();
        this._dockItems = new Map();
        this._dockRenderState = new Map();
        this._panelIcons = new Map();
        this._menuManager = new PopupMenu.PopupMenuManager(this._dock);
        for (const name of this._dockGroupOrder) {
            const region = new St.Widget({
                style_class: `zhyprbola-dock-region zhyprbola-dock-region-${name}`,
            });
            this._dock.add_child(region);
            this._dockRegions.set(name, region);
            if (!this._dockGroups.includes(name))
                continue;

            const group = new St.BoxLayout({
                style_class: `zhyprbola-dock-group zhyprbola-dock-group-${name}`,
                vertical,
                reactive: name === 'apps' || name === 'running',
            });
            if (name === 'apps' || name === 'running') {
                group._delegate = {
                    handleDragOver: (source, _actor, x, y) => {
                        if (!this._previewDockItemDrag(name, group, source,
                            vertical ? y : x))
                            return DND.DragMotionResult.CONTINUE;
                        return DND.DragMotionResult.MOVE_DROP;
                    },
                    acceptDrop: (source, _actor, x, y) => {
                        if (!this._previewDockItemDrag(name, group, source,
                            vertical ? y : x))
                            return false;
                        const keys = group.get_children()
                            .filter(child => child._delegate?.groupName === name)
                            .map(child => child._delegate.key);
                        source.dropAccepted = true;
                        GLib.idle_add_once(GLib.PRIORITY_DEFAULT_IDLE, () =>
                            this._commitDockItemOrder(name, keys));
                        return true;
                    },
                };
            }
            region.add_child(group);
            this._dockGroupsByName.set(name, group);
        }

        this._createComponentButtons();
        this._refreshAppGroups();

        Main.layoutManager.addChrome(this._dock, {
            affectsStruts: true,
            trackFullscreen: true,
        });
        this._showDesktopButton = new St.Button({
            style_class: 'zhyprbola-show-desktop',
            reactive: true,
            can_focus: true,
            track_hover: true,
            accessible_name: 'Show desktop / Restore windows',
        });
        this._showDesktopButton.connect('clicked', () => this._toggleDesktop());
        this._updateShowDesktopState();
        Main.layoutManager.addChrome(this._showDesktopButton, {
            affectsStruts: false,
            trackFullscreen: true,
        });
        this._layoutDock();
    }

    _isComponentWindow(window) {
        const title = window.get_title() ?? '';
        const wmClass = window.get_wm_class() ?? '';
        return title.startsWith('Zhyprbola ') || /zhyprbola/i.test(wmClass);
    }

    _toggleDesktop() {
        const windows = global.display.list_all_windows();
        const workspace = global.workspace_manager.get_active_workspace();
        const targets = global.display.sort_windows_by_stacking(windows.filter(window =>
            !this._isComponentWindow(window) && !window.minimized &&
            window.can_minimize() && window.located_on_workspace(workspace)));
        // Visible windows take priority over an earlier hide operation. A
        // partially restored desktop must not require two clicks to hide again.
        if (targets.length === 0) {
            this._restoreDesktopWindows(workspace);
            return;
        }

        const savedIds = new Set(this._desktopWindows.get(workspace)?.ids ?? []);
        const stillHidden = windows.filter(window =>
            savedIds.has(window.get_stable_sequence()) && window.minimized &&
            !this._isComponentWindow(window) && window.located_on_workspace(workspace));
        const focused = global.display.focus_window;
        this._desktopWindows.set(workspace, {
            ids: [...stillHidden, ...targets].map(window => window.get_stable_sequence()),
            focusedId: focused?.get_stable_sequence(),
        });
        for (const window of targets)
            window.minimize();
        this._updateShowDesktopState();
    }

    _updateShowDesktopState() {
        if (!this._showDesktopButton)
            return;
        const workspace = global.workspace_manager.get_active_workspace();
        const savedIds = new Set(this._desktopWindows.get(workspace)?.ids ?? []);
        const hidden = global.display.list_all_windows().some(window =>
            savedIds.has(window.get_stable_sequence()) && window.minimized &&
            window.located_on_workspace(workspace));
        if (hidden)
            this._showDesktopButton.add_style_pseudo_class('checked');
        else
            this._showDesktopButton.remove_style_pseudo_class('checked');
    }

    _restoreDesktopWindows(workspace = null) {
        // Resolve live windows by ID so closed windows cannot leave stale objects.
        const live = new Map(global.display.list_all_windows()
            .map(window => [window.get_stable_sequence(), window]));
        const activeWorkspace = global.workspace_manager.get_active_workspace();
        let restoreFocus = null;
        for (const [savedWorkspace, saved] of this._desktopWindows) {
            if (workspace && savedWorkspace !== workspace)
                continue;
            this._desktopWindows.delete(savedWorkspace);
            for (const id of saved.ids) {
                const window = live.get(id);
                if (!window || this._isComponentWindow(window) || !window.minimized ||
                    (workspace && !window.located_on_workspace(workspace)))
                    continue;
                window.unminimize();
                if (id === saved.focusedId && window.located_on_workspace(activeWorkspace))
                    restoreFocus = window;
            }
        }
        restoreFocus?.activate(global.get_current_time());
        this._updateShowDesktopState();
    }

    _createComponentButtons() {
        const group = this._dockGroupsByName.get('zhyprbola');
        if (!group)
            return;

        const labels = new Map(DOCK_COMPONENTS);
        this._dockItems.set('zhyprbola', this._dockComponents.visible.map(name => ({
            kind: name === 'input-source' ? 'input-source' : 'panel',
            name,
            label: labels.get(name),
        })));
    }

    _pinnedShellApps() {
        const entries = this._pinnedApps
            ? this._pinnedApps.map(id => [id]) : DEFAULT_PINNED_APPS;
        const apps = [];
        const ids = new Set();
        for (const candidates of entries) {
            const app = candidates.map(id => this._appSystem.lookup_app(id))
                .find(candidate => candidate);
            if (app && !ids.has(app.get_id())) {
                apps.push(app);
                ids.add(app.get_id());
            }
        }
        return apps;
    }

    _createAppButton(item, groupName) {
        const {app} = item;
        const content = new St.Widget({
            width: DOCK_CONFIG.buttonSize,
            height: DOCK_CONFIG.buttonSize,
            layout_manager: new Clutter.FixedLayout(),
        });
        const iconX = this._dockPosition === DockPosition.LEFT ? 5 : 6;
        const iconY = this._dockPosition === DockPosition.TOP ? 5 : 6;
        const icon = new St.Icon({
            gicon: app.get_icon(),
            icon_size: DOCK_CONFIG.iconSize,
            style_class: 'zhyprbola-dock-app-icon',
            x: iconX,
            y: iconY,
        });
        content.add_child(icon);
        const indicator = new St.Widget({
            style_class: 'zhyprbola-dock-app-indicator',
        });
        content.add_child(indicator);
        const button = new St.Button({
            style_class: 'zhyprbola-dock-app-button',
            child: content,
            can_focus: true,
            reactive: true,
            track_hover: true,
            accessible_name: item.label,
        });
        button.connect('clicked', () => {
            const current = button._delegate.item;
            current.window ? this._activateWindow(current.window)
                : this._activateApp(current.app);
        });
        const key = this._itemOrderKey(item);
        button._delegate = {
            groupName,
            key,
            button,
            item,
            indicator,
            destroyed: false,
            dragging: false,
            dragActor: null,
            dropAccepted: false,
            originalIndex: -1,
            getDragActor: () => {
                const actor = new St.Icon({
                    gicon: button._delegate.item.app.get_icon(),
                    icon_size: DOCK_CONFIG.iconSize,
                    style_class: 'zhyprbola-dock-app-icon',
                });
                button._delegate.dragActor = actor;
                actor.connect('destroy', () => { button._delegate.dragActor = null; });
                return actor;
            },
            getDragActorSource: () => button,
        };
        const delegate = button._delegate;
        button.connect('notify::pressed', () => this._trackDockInteraction(delegate));
        button.connect('destroy', () => {
            delegate.destroyed = true;
            this._dockInteractions.delete(delegate);
        });
        this._updateAppButton(button, item);
        const draggable = DND.makeDraggable(button, {timeoutThreshold: 200});
        draggable.connect('drag-begin', () => {
            if (delegate.destroyed)
                return;
            delegate.dragging = true;
            this._trackDockInteraction(delegate);
            const group = button.get_parent();
            button._delegate.originalIndex = group.get_children().indexOf(button);
            button._delegate.dropAccepted = false;
            button.reactive = false;
            content.opacity = 0;
            button.add_style_class_name('zhyprbola-dock-drag-placeholder');
        });
        const finishDrag = () => {
            if (delegate.destroyed)
                return;
            const group = button.get_parent();
            if (!group)
                return;
            if (!button._delegate.dropAccepted &&
                button._delegate.originalIndex >= 0)
                this._moveDockDragPlaceholder(group, button,
                    button._delegate.originalIndex);
            button.reactive = true;
            content.opacity = 255;
            button.remove_style_class_name('zhyprbola-dock-drag-placeholder');
        };
        draggable.connect('drag-end', () => {
            finishDrag();
            delegate.dragging = false;
            this._trackDockInteraction(delegate);
        });
        // Cancellation starts a snap-back animation. Keep the source alive
        // until drag-end, when DND releases its modal grab and source actor.
        draggable.connect('drag-cancelled', finishDrag);
        return button;
    }

    _trackDockInteraction(delegate) {
        if (!delegate.destroyed && (delegate.dragging || delegate.button.pressed))
            this._dockInteractions.add(delegate);
        else if (this._dockInteractions.delete(delegate))
            this._queueLayout();
    }

    _updateAppButton(button, item) {
        const {app, window = null, running} = item;
        button._delegate.item = item;
        button.accessible_name = item.label;
        const indicator = button._delegate.indicator;
        indicator.visible = running;
        const focused = window ? window.has_focus()
            : app.get_windows().some(appWindow => appWindow.has_focus());
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT]
            .includes(this._dockPosition);
        const width = vertical ? 4 : (focused ? 14 : 4);
        const height = vertical ? (focused ? 14 : 4) : 4;
        const iconX = this._dockPosition === DockPosition.LEFT ? 5 : 6;
        const iconY = this._dockPosition === DockPosition.TOP ? 5 : 6;
        indicator.set_size(width, height);
        indicator.set_position(this._dockPosition === DockPosition.LEFT ? 0
            : this._dockPosition === DockPosition.RIGHT ? DOCK_CONFIG.buttonSize - width
            : iconX + (DOCK_CONFIG.iconSize - width) / 2,
        this._dockPosition === DockPosition.TOP ? 0
            : this._dockPosition === DockPosition.BOTTOM ? DOCK_CONFIG.buttonSize - height
            : iconY + (DOCK_CONFIG.iconSize - height) / 2);
    }

    _previewDockItemDrag(groupName, group, source, position) {
        if (source?.destroyed || source?.groupName !== groupName ||
            source.button?.get_parent() !== group)
            return false;
        const buttons = group.get_children().filter(child =>
            child._delegate?.groupName === groupName);
        const step = DOCK_CONFIG.buttonSize + DOCK_CONFIG.groupSpacing;
        const targetIndex = buttons.filter(child => child !== source.button &&
            position >= (buttons.indexOf(child) * step + DOCK_CONFIG.buttonSize / 2))
            .length;
        this._moveDockDragPlaceholder(group, source.button, targetIndex);
        return true;
    }

    _moveDockDragPlaceholder(group, button, targetIndex) {
        // Reorder the empty button slot while the drag icon follows the pointer.
        const buttons = group.get_children().filter(child =>
            child._delegate?.groupName === button._delegate.groupName);
        if (buttons.indexOf(button) === targetIndex)
            return;
        group.set_child_at_index(button, targetIndex);
        const reordered = group.get_children().filter(child =>
            child._delegate?.groupName === button._delegate.groupName);
        const property = [DockPosition.LEFT, DockPosition.RIGHT]
            .includes(this._dockPosition) ? 'translation_y' : 'translation_x';
        const step = DOCK_CONFIG.buttonSize + DOCK_CONFIG.groupSpacing;
        for (const child of buttons) {
            if (child === button)
                continue;
            const delta = (buttons.indexOf(child) - reordered.indexOf(child)) * step;
            if (delta === 0)
                continue;
            child[property] += delta;
            child.ease({[property]: 0, duration: 130,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD});
        }
    }

    _commitDockItemOrder(groupName, keys) {
        const items = this._dockItems?.get(groupName);
        if (!items)
            return;
        const byKey = new Map(items.map(item => [this._itemOrderKey(item), item]));
        const visible = keys.map(key => byKey.get(key));
        if (visible.some(item => !item))
            return;
        const visibleKeys = new Set(keys);
        const reordered = [...visible, ...items.filter(item =>
            !visibleKeys.has(this._itemOrderKey(item)))];
        if (reordered.every((candidate, index) => candidate === items[index]))
            return;

        if (groupName === 'apps') {
            const ids = reordered.map(candidate => candidate.app.get_id());
            for (const id of this._pinnedApps ?? []) {
                if (!ids.includes(id))
                    ids.push(id);
            }
            try {
                GLib.mkdir_with_parents(GLib.path_get_dirname(this._pinnedAppsPath), 0o700);
                GLib.file_set_contents(this._pinnedAppsPath, `${ids.join(',')}\n`);
                this._pinnedApps = ids;
            } catch (error) {
                logError(error, 'Failed to save dock app order');
                return;
            }
        } else {
            reordered.forEach((candidate, index) =>
                this._runningOrder.set(this._itemOrderKey(candidate), index));
            this._nextRunningOrder = reordered.length;
        }
        this._dockItems.set(groupName, reordered);
        this._dockRenderState.delete(groupName);
        this._queueLayout();
    }

    _activateWindow(window) {
        if (!window)
            return;
        if (window.has_focus()) {
            window.minimize();
            return;
        }
        if (window.minimized)
            window.unminimize();
        window.activate(global.get_current_time());
    }

    _activateApp(app) {
        const focused = app.get_windows().find(window => window.has_focus());
        if (focused)
            focused.minimize();
        else
            app.activate();
    }

    _windowItemsForApp(app) {
        return app.get_windows()
            .filter(window => !window.get_title()?.startsWith('Zhyprbola '))
            .map(window => ({
                kind: 'app',
                app,
                window,
                label: window.get_title() || app.get_name(),
                running: true,
            }));
    }

    _itemOrderKey(item) {
        if (item.window) {
            const stableWindowId = item.window.get_stable_sequence?.();
            const windowId = stableWindowId ?? item.window.get_id?.() ??
                item.window.get_description?.() ?? item.window.get_title();
            return `${item.app.get_id()}:window:${windowId}`;
        }
        return `${item.app.get_id()}:app`;
    }

    _orderRunningItems(items) {
        const activeKeys = new Set();
        for (const item of items) {
            const key = this._itemOrderKey(item);
            activeKeys.add(key);
            if (!this._runningOrder.has(key))
                this._runningOrder.set(key, this._nextRunningOrder++);
        }
        for (const key of [...this._runningOrder.keys()]) {
            if (!activeKeys.has(key))
                this._runningOrder.delete(key);
        }
        if (this._runningOrder.size === 0)
            this._nextRunningOrder = 0;
        return items.sort((left, right) =>
            (this._runningOrder.get(this._itemOrderKey(left)) -
                this._runningOrder.get(this._itemOrderKey(right))) ||
            left.label.localeCompare(right.label));
    }

    _refreshAppGroups() {
        if (!this._dockGroupsByName)
            return;
        this._dockItems.set('apps', this._pinnedShellApps().map(app => {
            const windows = this._windowItemsForApp(app);
            return {kind: 'app', app, label: app.get_name(), running: windows.length > 0};
        }));

        const runningApps = new Map();
        const seenWindows = new Set();
        const addWindows = (app, windows) => {
            if (!app)
                return;
            for (const window of windows) {
                if (seenWindows.has(window) ||
                    window.get_title()?.startsWith('Zhyprbola '))
                    continue;
                seenWindows.add(window);
                const key = app.get_id() ?? app;
                if (!runningApps.has(key))
                    runningApps.set(key, {app, windows: []});
                runningApps.get(key).windows.push(window);
            }
        };
        for (const app of this._appSystem.get_running())
            addWindows(app, app.get_windows());
        for (const app of this._pinnedShellApps())
            addWindows(app, app.get_windows());
        for (const window of global.display.list_all_windows()) {
            if (!window.is_skip_taskbar())
                addWindows(this._windowTracker.get_window_app(window), [window]);
        }

        const running = [];
        for (const {app, windows} of runningApps.values()) {
            if (this._dockUngroupWindows)
                running.push(...windows.map(window => ({kind: 'app', app, window,
                    label: window.get_title() || app.get_name(), running: true})));
            else
                running.push({kind: 'app', app, label: app.get_name(), running: true,
                    window: app.get_windows().length === 0 ? windows[0] : null});
        }
        this._dockItems.set('running', this._orderRunningItems(running));
        this._queueLayout();
    }

    _queueAppRefresh() {
        if (this._appRefreshId)
            return;
        this._appRefreshId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._appRefreshId = 0;
            this._refreshAppGroups();
            return GLib.SOURCE_REMOVE;
        });
    }

    _queueInputSourceRefresh() {
        if (!this._dock)
            return;
        if (this._inputSourceMenu && !this._inputSourceMenuCloseId) {
            this._inputSourceMenuCloseId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                this._inputSourceMenuCloseId = 0;
                this._inputSourceMenu?.destroy();
                this._inputSourceMenu = null;
                return GLib.SOURCE_REMOVE;
            });
        }
        this._refreshInputSourceButton();
    }

    _readTheme() {
        try {
            const [, contents] = GLib.file_get_contents(this._themePath);
            const savedName = new TextDecoder().decode(contents).trim();
            const name = savedName === 'rose-galaxy' ? 'mauve' : savedName;
            return THEMES.some(theme => theme.name === name) ? name : 'current';
        } catch (_) {
            return 'current';
        }
    }

    _readDockPosition() {
        try {
            const [, contents] = GLib.file_get_contents(this._dockPositionPath);
            const name = new TextDecoder().decode(contents).trim();
            return Object.values(DockPosition).includes(name) ? name : DEFAULT_DOCK_POSITION;
        } catch (_) {
            return DEFAULT_DOCK_POSITION;
        }
    }

    _readDockBgOpacity() {
        try {
            const [, contents] = GLib.file_get_contents(this._dockBgOpacityPath);
            const text = new TextDecoder().decode(contents).trim();
            const opacity = Number(text);
            return text && Number.isInteger(opacity) && opacity >= 0 && opacity <= 100
                ? opacity : 50;
        } catch (_) {
            return 50;
        }
    }

    _readDockUngroupWindows() {
        try {
            const [, contents] = GLib.file_get_contents(this._dockUngroupWindowsPath);
            return new TextDecoder().decode(contents).trim() === 'true';
        } catch (_) {
            return false;
        }
    }

    _readUseWallpaper() {
        try {
            const [, contents] = GLib.file_get_contents(this._useWallpaperPath);
            return new TextDecoder().decode(contents).trim() === 'true';
        } catch (_) {
            return false;
        }
    }

    _readEdgeEnabled() {
        try {
            const [, contents] = GLib.file_get_contents(this._edgeEnabledPath);
            return new TextDecoder().decode(contents).trim() === 'true';
        } catch (_) {
            return false;
        }
    }

    _readEdgePosition() {
        try {
            const [, contents] = GLib.file_get_contents(this._edgePositionPath);
            const position = new TextDecoder().decode(contents).trim();
            return Object.values(DockPosition).includes(position)
                ? position : DockPosition.BOTTOM;
        } catch (_) {
            return DockPosition.BOTTOM;
        }
    }

    _readDockGroups() {
        try {
            const [, contents] = GLib.file_get_contents(this._dockGroupsPath);
            const names = new TextDecoder().decode(contents).trim().split(/[\s,]+/)
                .filter(name => DOCK_GROUPS.includes(name));
            const groups = [...new Set(names)];
            if (!groups.includes('zhyprbola'))
                groups.push('zhyprbola');
            return groups;
        } catch (_) {
            return [...DEFAULT_ENABLED_DOCK_GROUPS];
        }
    }

    _readDockGroupOrder() {
        try {
            const [, contents] = GLib.file_get_contents(this._dockGroupOrderPath);
            const names = new TextDecoder().decode(contents).trim()
                .split(/[\s,]+/).filter(name => DOCK_GROUPS.includes(name));
            return [...new Set(names),
                ...DEFAULT_DOCK_GROUP_ORDER.filter(name => !names.includes(name))];
        } catch (_) {
            return [...DEFAULT_DOCK_GROUP_ORDER];
        }
    }

    _readDockComponents() {
        const defaults = DOCK_COMPONENTS.map(([name]) => name);
        try {
            const [, contents] = GLib.file_get_contents(this._dockComponentsPath);
            const saved = JSON.parse(new TextDecoder().decode(contents));
            if (!Array.isArray(saved.visible) || !Array.isArray(saved.hidden))
                throw new Error('Invalid dock components');
            const known = new Set(defaults);
            const visible = [...new Set(saved.visible.filter(name => known.has(name)))];
            const hidden = [...new Set(saved.hidden.filter(name =>
                known.has(name) && !visible.includes(name)))];
            const quick = [...new Set((Array.isArray(saved.quick) ? saved.quick : [])
                .filter(name => name !== 'components' && known.has(name) &&
                    !visible.includes(name) && !hidden.includes(name)))];
            for (const name of defaults) {
                if (!visible.includes(name) && !hidden.includes(name) &&
                    !quick.includes(name))
                    visible.push(name);
            }
            return {visible, hidden, quick};
        } catch (_) {
            return {visible: defaults, hidden: [], quick: []};
        }
    }

    _readPinnedApps() {
        try {
            const [, contents] = GLib.file_get_contents(this._pinnedAppsPath);
            return new TextDecoder().decode(contents).trim()
                .split(/[\s,]+/).filter(Boolean);
        } catch (_) {
            return null;
        }
    }

    _readPanelRequest() {
        try {
            return new TextDecoder().decode(
                GLib.file_get_contents(this._panelRequestPath)[1]).trim();
        } catch (_) {
            return '';
        }
    }

    _watchSettings() {
        const directory = GLib.path_get_dirname(this._themePath);
        try {
            GLib.mkdir_with_parents(directory, 0o700);
            this._settingsMonitor = Gio.File.new_for_path(directory)
                .monitor_directory(Gio.FileMonitorFlags.NONE, null);
            this._settingsMonitor.connect('changed', () => {
                if (this._settingsSyncId)
                    return;
                this._settingsSyncId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
                    this._settingsSyncId = 0;
                    this._syncSettings();
                    return GLib.SOURCE_REMOVE;
                });
            });
            this._panelRequestMonitor = Gio.File.new_for_path(this._panelRequestPath)
                .monitor_file(Gio.FileMonitorFlags.NONE, null);
            this._panelRequestMonitor.connect('changed', () =>
                this._queuePanelRequest());
        } catch (error) {
            logError(error, 'Failed to watch Zhyprbola settings');
        }
    }

    _queuePanelRequest() {
        if (this._panelRequestId)
            return;
        this._panelRequestId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 30, () => {
            this._panelRequestId = 0;
            this._handlePanelRequest();
            return GLib.SOURCE_REMOVE;
        });
    }

    _startPanelRequestPolling() {
        if (this._panelRequestPollId)
            return;
        this._panelRequestPollId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            this._handlePanelRequest();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _handlePanelRequest() {
        const panelRequest = this._readPanelRequest();
        if (!panelRequest || panelRequest === this._panelRequest)
            return;

        this._panelRequest = panelRequest;
        const panelName = panelRequest.split(':').slice(1).join(':');
        if (PANEL_TITLES[panelName])
            this._openPanel(panelName, true);
    }

    _syncSettings() {
        const theme = this._readTheme();
        const position = this._readDockPosition();
        const bgOpacity = this._readDockBgOpacity();
        const dockUngroupWindows = this._readDockUngroupWindows();
        const useWallpaper = this._readUseWallpaper();
        const edgeEnabled = this._readEdgeEnabled();
        const edgePosition = this._readEdgePosition();
        const dockGroups = this._readDockGroups();
        const dockGroupOrder = this._readDockGroupOrder();
        const dockComponents = this._readDockComponents();
        const pinnedApps = this._readPinnedApps();
        const themeChanged = theme !== this._themeName;
        const positionChanged = position !== this._dockPosition;
        const bgOpacityChanged = bgOpacity !== this._dockBgOpacity;
        const dockUngroupWindowsChanged = dockUngroupWindows !== this._dockUngroupWindows;
        const wallpaperChanged = useWallpaper !== this._useWallpaper;
        const edgeChanged = edgeEnabled !== this._edgeEnabled ||
            edgePosition !== this._edgePosition;
        const groupsChanged = dockGroups.join(',') !== this._dockGroups.join(',') ||
            dockGroupOrder.join(',') !== this._dockGroupOrder.join(',') ||
            JSON.stringify(pinnedApps) !== JSON.stringify(this._pinnedApps);
        const componentsChanged = dockComponents.visible.join(',') !==
            this._dockComponents.visible.join(',') || dockComponents.hidden.join(',') !==
            this._dockComponents.hidden.join(',') || dockComponents.quick.join(',') !==
            this._dockComponents.quick.join(',');

        this._themeName = theme;
        this._dockPosition = position;
        this._dockBgOpacity = bgOpacity;
        this._dockUngroupWindows = dockUngroupWindows;
        this._useWallpaper = useWallpaper;
        this._edgeEnabled = edgeEnabled;
        this._edgePosition = edgePosition;
        this._dockGroups = dockGroups;
        this._dockGroupOrder = dockGroupOrder;
        this._dockComponents = dockComponents;
        this._pinnedApps = pinnedApps;

        this._handlePanelRequest();
        if (positionChanged || groupsChanged || componentsChanged || dockUngroupWindowsChanged)
            this._rebuildDock();
        else if (themeChanged)
            this._applyTheme();
        else if (bgOpacityChanged)
            this._applyDockBackground();
        if (themeChanged || wallpaperChanged)
            this._applyWallpaper(wallpaperChanged && useWallpaper);
        if (edgeChanged)
            this._restartEdgeSpectrum();
    }

    _startEdgeSpectrum() {
        if (!this._edgeEnabled || this._edgeProcess)
            return;

        const launcher = GLib.build_filenamev([this.path, 'panel-command.sh']);
        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor || !Gio.File.new_for_path(launcher).query_exists(null))
            return;

        try {
            const processLauncher =
                Gio.SubprocessLauncher.new(Gio.SubprocessFlags.NONE);
            processLauncher.setenv('ZHYPRBOLA_EDGE_SCREEN_X', String(monitor.x), true);
            processLauncher.setenv('ZHYPRBOLA_EDGE_SCREEN_Y', String(monitor.y), true);
            processLauncher.setenv('ZHYPRBOLA_EDGE_SCREEN_WIDTH',
                String(monitor.width), true);
            processLauncher.setenv('ZHYPRBOLA_EDGE_SCREEN_HEIGHT',
                String(monitor.height), true);
            const process = processLauncher.spawnv(['bash', launcher, 'edge-spectrum']);
            this._edgeProcess = process;
            this._placeEdgeSpectrum(process);
            process.wait_async(null, (source, result) => {
                try {
                    source.wait_finish(result);
                } catch (error) {
                    logError(error, 'Failed to wait for edge spectrum');
                }
                if (this._edgeProcess === process)
                    this._edgeProcess = null;
            });
        } catch (error) {
            logError(error, 'Failed to open edge spectrum');
        }
    }

    _stopEdgeSpectrum() {
        this._edgeWindow = null;
        if (this._edgePlacementId) {
            GLib.source_remove(this._edgePlacementId);
            this._edgePlacementId = 0;
        }
        this._edgeProcess?.force_exit();
        this._edgeProcess = null;
    }

    _restartEdgeSpectrum() {
        this._stopEdgeSpectrum();
        this._startEdgeSpectrum();
    }

    _placeEdgeSpectrum(process) {
        let attempts = 0;
        this._edgePlacementId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
            const window = global.display.list_all_windows().find(item =>
                item.get_title() === 'Zhyprbola Edge Spectrum' &&
                item.get_pid() === Number(process.get_identifier()));
            const frame = window?.get_frame_rect();
            const actor = window?.get_compositor_private();
            const monitor = Main.layoutManager.primaryMonitor;
            if (actor?.mapped && frame?.width > 0 && frame?.height > 0 && monitor) {
                this._edgeWindow = window;
                window.connectObject('unmanaged', () => {
                    if (this._edgeWindow === window)
                        this._edgeWindow = null;
                }, this);
                this._layoutEdgeSpectrum();
                this._edgePlacementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            if (++attempts >= 100 || process.get_if_exited()) {
                this._edgePlacementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    _layoutEdgeSpectrum() {
        const window = this._edgeWindow;
        const monitor = Main.layoutManager.primaryMonitor;
        if (!window || !monitor)
            return;
        const frame = window.get_frame_rect();
        let x = monitor.x;
        let y = monitor.y;
        if (this._edgePosition === DockPosition.RIGHT)
            x += monitor.width - frame.width;
        else if (this._edgePosition === DockPosition.BOTTOM)
            y += monitor.height - frame.height;

        // Attach the spectrum baseline to the dock instead of reserving a
        // second fixed margin inside the spectrum window.
        if (this._dock && this._edgePosition === this._dockPosition) {
            switch (this._edgePosition) {
            case DockPosition.LEFT:
                x = this._dock.get_x() + this._dock.get_width();
                break;
            case DockPosition.RIGHT:
                x = this._dock.get_x() - frame.width;
                break;
            case DockPosition.TOP:
                y = this._dock.get_y() + this._dock.get_height();
                break;
            case DockPosition.BOTTOM:
                y = this._dock.get_y() - frame.height;
                break;
            }
        }
        if (frame.x !== x || frame.y !== y)
            window.move_frame(false, x, y);
    }

    _applyTheme() {
        if (this._themeName === 'white' || this._themeName === 'white-sky') {
            this._dock.add_style_class_name('zhyprbola-dock-white');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-white');
        }
        if (this._themeName === 'white-sky') {
            this._dock.add_style_class_name('zhyprbola-dock-white-sky');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-white-sky');
        }
        if (this._themeName === 'forest') {
            this._dock.add_style_class_name('zhyprbola-dock-forest');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-forest');
        }
        if (this._themeName === 'one-half-gray') {
            this._dock.add_style_class_name('zhyprbola-dock-one-half-gray');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-one-half-gray');
        }
        if (this._themeName === 'red') {
            this._dock.add_style_class_name('zhyprbola-dock-red');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-red');
        }
        if (this._themeName === 'mauve') {
            this._dock.add_style_class_name('zhyprbola-dock-mauve');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-mauve');
        }
        this._applyDockBackground();
        for (const [name, icon] of this._panelIcons)
            icon.gicon = this._panelGicon(name);
        this._overflowMenu?.destroy();
        this._overflowMenu = null;
        this._quickMenu?.destroy();
        this._quickMenu = null;
        this._inputSourceMenu?.destroy();
        this._inputSourceMenu = null;
    }

    _applyDockBackground() {
        const color = (THEMES.find(theme => theme.name === this._themeName) ?? THEMES[0])
            .iconColor;
        const red = parseInt(color.slice(1, 3), 16);
        const green = parseInt(color.slice(3, 5), 16);
        const blue = parseInt(color.slice(5, 7), 16);
        this._dock.set_style(`spacing: 0; background-color: rgba(${red}, ${green}, ` +
            `${blue}, ${this._dockBgOpacity / 100});`);
    }

    _applyDockPosition() {
        this._layoutDock();
    }

    _rebuildDock() {
        if (this._dockInteractions.size > 0) {
            this._dockRebuildPending = true;
            return;
        }
        this._dockRebuildPending = false;
        this._destroyDock();
        this._createDock();
        this._applyTheme();
        this._applyDockPosition();
    }

    _destroyDock() {
        if (!this._dock)
            return;

        // Destroy the drag clone while its source is still alive so DND can
        // cancel and release its modal grab before the dock is destroyed.
        for (const delegate of [...this._dockInteractions])
            delegate.dragActor?.destroy();
        this._dockInteractions.clear();

        this._inputSourceMenu?.destroy();
        this._inputSourceMenu = null;
        if (this._inputSourceMenuCloseId) {
            GLib.source_remove(this._inputSourceMenuCloseId);
            this._inputSourceMenuCloseId = 0;
        }
        this._inputSourceButton = null;
        this._inputSourceLabel = null;
        this._powerMenu?.destroy();
        this._powerMenu = null;
        this._overflowMenu?.destroy();
        this._overflowMenu = null;
        this._quickMenu?.destroy();
        this._quickMenu = null;
        if (this._showDesktopButton) {
            Main.layoutManager.removeChrome(this._showDesktopButton);
            this._showDesktopButton.destroy();
            this._showDesktopButton = null;
        }
        Main.layoutManager.removeChrome(this._dock);
        this._dock.destroy();
        this._dock = null;
        this._dockGroupsByName = null;
        this._dockRegions = null;
        this._dockItems = null;
        this._dockRenderState = null;
        this._menuManager = null;
        this._panelIcons = null;
    }

    _applyWallpaper(forceRefresh = false) {
        if (!this._useWallpaper || !this._backgroundSettings) {
            this._cancelWallpaperRefresh();
            return;
        }

        const theme = THEMES.find(item => item.name === this._themeName);
        if (!theme)
            return;

        const path = GLib.build_filenamev([this.path, 'wallpapers', theme.wallpaper]);
        const file = Gio.File.new_for_path(path);
        if (!file.query_exists(null)) {
            logError(new Error(`Missing Zhyprbola wallpaper: ${path}`));
            return;
        }

        const uri = file.get_uri();
        if (forceRefresh &&
            this._backgroundSettings.get_string('picture-uri') === uri &&
            this._backgroundSettings.get_string('picture-uri-dark') === uri) {
            this._backgroundSettings.set_string('picture-uri', '');
            this._backgroundSettings.set_string('picture-uri-dark', '');
            this._scheduleWallpaperSet(uri);
            return;
        }

        this._cancelWallpaperRefresh();
        this._setWallpaperUri(uri);
    }

    _scheduleWallpaperSet(uri) {
        this._cancelWallpaperRefresh();

        this._wallpaperRefreshId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
            this._wallpaperRefreshId = 0;
            this._setWallpaperUri(uri);
            return GLib.SOURCE_REMOVE;
        });
    }

    _cancelWallpaperRefresh() {
        if (!this._wallpaperRefreshId)
            return;

        GLib.source_remove(this._wallpaperRefreshId);
        this._wallpaperRefreshId = 0;
    }

    _setWallpaperUri(uri) {
        if (!this._backgroundSettings)
            return;

        this._backgroundSettings.set_string('picture-uri', uri);
        this._backgroundSettings.set_string('picture-uri-dark', uri);
        this._backgroundSettings.set_string('picture-options', 'zoom');
    }

    _inputSources() {
        const managerSources = this._managerInputSources();
        if (managerSources.length > 0)
            return managerSources;
        try {
            return this._inputSourceSettings.get_value('sources').deep_unpack()
                .map(([type, id]) => ({type, id}));
        } catch (error) {
            logError(error, 'Failed to read GNOME input sources');
            return [];
        }
    }

    _managerInputSources() {
        const sources = this._inputSourceManager?.inputSources ??
            this._inputSourceManager?._inputSources;
        if (!sources)
            return [];
        const values = Array.isArray(sources) ? sources : Object.values(sources);
        return values.map((source, index) => ({
            type: source.type,
            id: source.id,
            index: source.index ?? index,
            code: source.shortName,
            label: source.displayName,
            managerSource: source,
        }));
    }

    _currentManagerInputSource() {
        return this._inputSourceManager?.currentSource ??
            this._inputSourceManager?._currentSource ?? null;
    }

    _currentInputSourceIndex(sources = this._inputSources()) {
        if (sources.length === 0)
            return -1;
        const currentSource = this._currentManagerInputSource();
        if (currentSource) {
            const current = sources.findIndex(source =>
                source.managerSource === currentSource ||
                (currentSource.index !== undefined &&
                    source.index === currentSource.index) ||
                (source.type === currentSource.type && source.id === currentSource.id));
            if (current >= 0)
                return current;
        }
        try {
            const current = this._inputSourceSettings.get_uint('current');
            return current < sources.length ? current : 0;
        } catch (error) {
            return 0;
        }
    }

    _inputSourceCode(source = null) {
        if (source?.code)
            return source.code.toLowerCase();
        if (source?.shortName)
            return source.shortName.toLowerCase();
        const id = source?.id ?? '';
        if (id.startsWith('th'))
            return 'th';
        if (id.startsWith('us') || id.startsWith('en'))
            return 'en';
        return id.slice(0, 2).toLowerCase() || '--';
    }

    _inputSourceName(source = null) {
        if (source?.label)
            return source.label;
        if (source?.displayName)
            return source.displayName;
        const id = source?.id ?? '';
        if (id.startsWith('th'))
            return 'Thai';
        if (id.startsWith('us'))
            return 'English (US)';
        if (id.startsWith('en'))
            return 'English';
        return id || 'Unknown';
    }

    _currentInputSourceCode() {
        const sources = this._inputSources();
        const index = this._currentInputSourceIndex(sources);
        return this._inputSourceCode(sources[index] ?? this._currentManagerInputSource());
    }

    _refreshInputSourceButton() {
        const code = this._currentInputSourceCode();
        if (this._inputSourceLabel)
            this._inputSourceLabel.text = code;
        if (this._inputSourceButton)
            this._inputSourceButton.accessible_name = `Input Source: ${code}`;
    }

    _createInputSourceButton() {
        const label = new St.Label({
            text: this._currentInputSourceCode(),
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'zhyprbola-dock-language-label',
        });
        const button = new St.Button({
            style_class: 'zhyprbola-dock-button zhyprbola-dock-language-button',
            child: label,
            can_focus: true,
            reactive: true,
            track_hover: true,
            accessible_name: `Input Source: ${label.text}`,
        });
        button.connect('clicked', () => this._openInputSourceMenu(button));
        this._inputSourceButton = button;
        this._inputSourceLabel = label;
        return button;
    }

    _openInputSourceMenu(button) {
        if (this._inputSourceMenu?.sourceActor === button) {
            this._inputSourceMenu.toggle();
            return;
        }
        if (this._inputSourceMenuCloseId) {
            GLib.source_remove(this._inputSourceMenuCloseId);
            this._inputSourceMenuCloseId = 0;
        }
        this._inputSourceMenu?.destroy();
        const side = {
            [DockPosition.LEFT]: St.Side.RIGHT,
            [DockPosition.RIGHT]: St.Side.LEFT,
            [DockPosition.TOP]: St.Side.BOTTOM,
            [DockPosition.BOTTOM]: St.Side.TOP,
        }[this._dockPosition];
        const menu = new PopupMenu.PopupMenu(button, 0.5, side);
        const theme = THEMES.find(item => item.name === this._themeName);
        const sources = this._inputSources();
        const current = this._currentInputSourceIndex(sources);
        menu.actor.add_style_class_name('zhyprbola-input-source-menu');
        menu.box.set_style(`background-color: #fafcfd; color: ${theme.iconColor};`);
        for (const [index, source] of sources.entries()) {
            const item = menu.addAction(this._inputSourceName(source), () => {
                if (source.managerSource?.activate)
                    source.managerSource.activate(true);
                else
                    this._inputSourceSettings.set_uint('current', index);
                this._queueInputSourceRefresh();
            });
            item.actor.add_style_class_name('zhyprbola-input-source-item');
            item.label.x_expand = true;
            item.label.set_style(`color: ${theme.iconColor};`);
            const code = new St.Label({
                text: this._inputSourceCode(source),
                style_class: 'zhyprbola-input-source-code',
            });
            code.set_style(`color: ${theme.iconColor};`);
            item.actor.add_child(code);
            if (index === current)
                item.setOrnament(PopupMenu.Ornament.DOT);
        }
        Main.uiGroup.add_child(menu.actor);
        menu.actor.hide();
        this._menuManager.addMenu(menu);
        this._inputSourceMenu = menu;
        menu.open();
    }

    _createPanelButton({iconName, accessibleName, panelName}) {
        const icon = new St.Icon({
            gicon: this._panelGicon(iconName),
            style_class: 'zhyprbola-dock-icon',
        });
        this._panelIcons.set(iconName, icon);

        const button = new St.Button({
            style_class: 'zhyprbola-dock-button',
            child: icon,
            can_focus: true,
            reactive: true,
            track_hover: true,
            accessible_name: accessibleName,
        });

        button.connect('clicked', () => {
            if (panelName === 'power')
                this._openPowerMenu(button);
            else if (panelName === 'components')
                this._openQuickMenu(button);
            else
                this._openPanel(panelName);
        });
        return button;
    }

    _panelGicon(name, color = '#ffffff') {
        const path = GLib.build_filenamev([this.path, 'icons', `${name}.svg`]);
        try {
            let source = this._panelIconSources.get(name);
            if (!source) {
                const [, contents] = GLib.file_get_contents(path);
                source = new TextDecoder().decode(contents);
                this._panelIconSources.set(name, source);
            }
            const svg = source.replace(/#fff(?:fff)?\b/gi, color);
            return Gio.BytesIcon.new(new GLib.Bytes(new TextEncoder().encode(svg)));
        } catch (error) {
            logError(error, `Failed to color Zhyprbola icon: ${name}`);
            return new Gio.FileIcon({file: Gio.File.new_for_path(path)});
        }
    }

    _renderDockRegion(name, length, vertical, slot) {
        const group = this._dockGroupsByName.get(name);
        if (!group)
            return;
        const items = this._dockItems.get(name) ?? [];
        const state = `${length}:${items.length}:${vertical}:${slot}:` +
            JSON.stringify(items.map(item => item.kind === 'app'
                ? this._itemOrderKey(item) : item.name));
        const appButtons = new Map(group.get_children()
            .filter(child => child._delegate?.groupName === name)
            .map(child => [child._delegate.key, child]));
        if (this._dockRenderState.get(name) === state) {
            for (const item of items) {
                const button = item.kind === 'app'
                    ? appButtons.get(this._itemOrderKey(item)) : null;
                if (button)
                    this._updateAppButton(button, item);
            }
            return;
        }

        this._overflowMenu?.destroy();
        this._overflowMenu = null;
        if (name === 'zhyprbola') {
            this._quickMenu?.destroy();
            this._quickMenu = null;
        }
        if (name === 'zhyprbola') {
            this._inputSourceMenu?.destroy();
            this._inputSourceMenu = null;
            if (this._inputSourceMenuCloseId) {
                GLib.source_remove(this._inputSourceMenuCloseId);
                this._inputSourceMenuCloseId = 0;
            }
            this._inputSourceButton = null;
            this._inputSourceLabel = null;
            this._powerMenu?.destroy();
            this._powerMenu = null;
            this._panelIcons.clear();
        }
        const maxSlots = Math.max(0, Math.floor((length + DOCK_CONFIG.groupSpacing) /
            (DOCK_CONFIG.buttonSize + DOCK_CONFIG.groupSpacing)));
        const overflow = items.length > maxSlots;
        const visibleCount = overflow ? Math.max(0, maxSlots - 1) : items.length;
        const visibleKeys = new Set(items.slice(0, visibleCount)
            .filter(item => item.kind === 'app').map(item => this._itemOrderKey(item)));
        for (const child of group.get_children()) {
            if (!visibleKeys.has(child._delegate?.key))
                child.destroy();
        }
        for (const item of items.slice(0, visibleCount)) {
            const existing = item.kind === 'app'
                ? appButtons.get(this._itemOrderKey(item)) : null;
            if (existing) {
                this._updateAppButton(existing, item);
                group.set_child_at_index(existing, items.indexOf(item));
                continue;
            }
            const button = item.kind === 'input-source'
                ? this._createInputSourceButton()
                : item.kind === 'panel'
                ? this._createPanelButton({iconName: item.name,
                    accessibleName: item.label, panelName: item.name})
                : this._createAppButton(item, name);
            group.insert_child_at_index(button, items.indexOf(item));
        }
        if (overflow) {
            const more = new St.Button({
                style_class: 'zhyprbola-dock-button zhyprbola-dock-more',
                child: new St.Icon({icon_name: 'view-more-symbolic',
                    style_class: 'zhyprbola-dock-icon'}),
                can_focus: true,
                reactive: true,
                track_hover: true,
                accessible_name: `More ${name}`,
            });
            more.connect('clicked', () =>
                this._showOverflow(more,
                    (this._dockItems.get(name) ?? []).slice(visibleCount)));
            group.add_child(more);
        }

        const count = visibleCount + (overflow ? 1 : 0);
        const used = count * DOCK_CONFIG.buttonSize +
            Math.max(0, count - 1) * DOCK_CONFIG.groupSpacing;
        const offset = slot === 0 ? 0 : slot === 1
            ? Math.floor((length - used) / 2) : length - used;
        group.set_size(vertical ? DOCK_CONFIG.buttonSize : used,
            vertical ? used : DOCK_CONFIG.buttonSize);
        group.set_position(vertical ? 0 : Math.max(0, offset),
            vertical ? Math.max(0, offset) : 0);
        this._dockRenderState.set(name, state);
    }

    _showOverflow(button, items) {
        if (this._overflowMenu?.sourceActor === button) {
            this._overflowMenu.toggle();
            return;
        }
        this._overflowMenu?.destroy();
        const side = {
            [DockPosition.LEFT]: St.Side.RIGHT,
            [DockPosition.RIGHT]: St.Side.LEFT,
            [DockPosition.TOP]: St.Side.BOTTOM,
            [DockPosition.BOTTOM]: St.Side.TOP,
        }[this._dockPosition];
        const menu = new PopupMenu.PopupMenu(button, 0.5, side);
        const theme = THEMES.find(item => item.name === this._themeName);
        menu.actor.add_style_class_name('zhyprbola-overflow-menu');
        menu.box.set_style(`background-color: #fafcfd; color: ${theme.iconColor};`);
        for (const item of items) {
            const icon = item.kind === 'panel'
                ? this._panelGicon(item.name, theme.iconColor)
                : item.kind === 'input-source' ? null : item.app.get_icon();
            menu.addAction(item.label, () => {
                if (item.name === 'power') {
                    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                        if (this._dock)
                            this._openPowerMenu(button);
                        return GLib.SOURCE_REMOVE;
                    });
                } else if (item.name === 'components') {
                    GLib.idle_add_once(GLib.PRIORITY_DEFAULT_IDLE, () =>
                        this._dock && this._openQuickMenu(button));
                } else if (item.kind === 'input-source') {
                    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                        if (this._dock)
                            this._openInputSourceMenu(button);
                        return GLib.SOURCE_REMOVE;
                    });
                } else if (item.kind === 'panel')
                    this._openPanel(item.name);
                else
                    item.window ? this._activateWindow(item.window) : this._activateApp(item.app);
            }, icon);
        }
        Main.uiGroup.add_child(menu.actor);
        menu.actor.hide();
        this._menuManager.addMenu(menu);
        this._overflowMenu = menu;
        menu.open();
    }

    _openQuickMenu(button) {
        if (this._quickMenu?.sourceActor === button) {
            this._quickMenu.toggle();
            return;
        }
        this._quickMenu?.destroy();
        const side = {
            [DockPosition.LEFT]: St.Side.RIGHT,
            [DockPosition.RIGHT]: St.Side.LEFT,
            [DockPosition.TOP]: St.Side.BOTTOM,
            [DockPosition.BOTTOM]: St.Side.TOP,
        }[this._dockPosition];
        const menu = new PopupMenu.PopupMenu(button, 0.5, side);
        const theme = THEMES.find(item => item.name === this._themeName);
        menu.actor.add_style_class_name('zhyprbola-quick-menu');
        menu.actor.add_style_class_name(`zhyprbola-quick-${theme.name}`);
        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        const grid = new St.BoxLayout({vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            style_class: 'zhyprbola-quick-grid'});
        const names = this._dockComponents.quick;
        let columns = 1;
        if (names.length === 0) {
            grid.add_child(new St.Label({text: 'No quick components',
                style_class: 'zhyprbola-quick-empty'}));
        } else {
            const rowCount = Math.ceil(names.length / QUICK_MENU_CONFIG.maxColumns);
            columns = Math.ceil(names.length / rowCount);
            for (let start = 0; start < names.length; start += columns) {
                const row = new St.BoxLayout({
                    x_align: Clutter.ActorAlign.CENTER,
                    style_class: 'zhyprbola-quick-row',
                });
                for (const name of names.slice(start, start + columns)) {
                    const icon = new St.Icon({
                        gicon: this._panelGicon(name),
                        style_class: 'zhyprbola-quick-icon',
                    });
                    const buttonItem = new St.Button({
                        child: icon,
                        style_class: 'zhyprbola-quick-button',
                        reactive: true,
                        can_focus: true,
                        track_hover: true,
                        accessible_name: new Map(DOCK_COMPONENTS).get(name),
                    });
                    buttonItem.connect('clicked', () => {
                        menu.close();
                        GLib.idle_add_once(GLib.PRIORITY_DEFAULT_IDLE, () => {
                            if (!this._dock)
                                return;
                            if (name === 'power')
                                this._openPowerMenu(button);
                            else if (name === 'input-source')
                                this._openInputSourceMenu(button);
                            else
                                this._openPanel(name);
                        });
                    });
                    row.add_child(buttonItem);
                }
                grid.add_child(row);
            }
        }
        // Let the rows determine the natural width. St adds CSS padding outside
        // a declared width, so including it here would reserve it twice.
        menu.box.set_style(`background-color: #fafcfd; color: ${theme.iconColor}; ` +
            'min-width: 0px;');
        item.set_style('min-width: 0px;');
        item.add_child(grid);
        menu.addMenuItem(item);
        Main.uiGroup.add_child(menu.actor);
        menu.actor.hide();
        this._menuManager.addMenu(menu);
        this._quickMenu = menu;
        menu.open();
    }

    _openPowerMenu(button) {
        if (this._powerMenu?.sourceActor === button) {
            this._powerMenu.toggle();
            return;
        }
        this._powerMenu?.destroy();
        const side = {
            [DockPosition.LEFT]: St.Side.RIGHT,
            [DockPosition.RIGHT]: St.Side.LEFT,
            [DockPosition.TOP]: St.Side.BOTTOM,
            [DockPosition.BOTTOM]: St.Side.TOP,
        }[this._dockPosition];
        const menu = new PopupMenu.PopupMenu(button, 0.5, side);
        const theme = THEMES.find(item => item.name === this._themeName);
        menu.actor.add_style_class_name('zhyprbola-overflow-menu');
        menu.actor.add_style_class_name('zhyprbola-power-menu');
        menu.actor.add_style_class_name(`zhyprbola-power-${this._themeName}`);
        menu.box.set_style(`background-color: #fafcfd; color: ${theme.iconColor};`);
        const addAction = (label, callback) => {
            const item = menu.addAction(label, callback);
            item.label.set_style(`color: ${theme.iconColor};`);
        };
        addAction('Log Out', () => this._sessionBusCall(
            'org.gnome.SessionManager', '/org/gnome/SessionManager',
            'org.gnome.SessionManager', 'Logout',
            new GLib.Variant('(u)', [0])));
        addAction('Restart', () => this._sessionBusCall(
            'org.gnome.SessionManager', '/org/gnome/SessionManager',
            'org.gnome.SessionManager', 'Reboot'));
        addAction('Power Off', () => this._sessionBusCall(
            'org.gnome.SessionManager', '/org/gnome/SessionManager',
            'org.gnome.SessionManager', 'Shutdown'));
        Main.uiGroup.add_child(menu.actor);
        menu.actor.hide();
        this._menuManager.addMenu(menu);
        this._powerMenu = menu;
        menu.open();
    }

    _sessionBusCall(destination, path, interfaceName, method, parameters = null) {
        Gio.DBus.session.call(destination, path, interfaceName, method, parameters,
            null, Gio.DBusCallFlags.NONE, -1, null, (connection, result) => {
                try {
                    connection.call_finish(result);
                } catch (error) {
                    logError(error, `Failed to call ${interfaceName}.${method}`);
                }
            });
    }

    _openPanel(panelName, fromSettings = false) {
        const title = PANEL_TITLES[panelName];
        const existingWindow = global.display.list_all_windows()
            .find(window => window && (window.get_title() === title ||
                (panelName === 'bluetooth' && window.get_title() === 'Zhyprbola Panel')));

        if (existingWindow) {
            if (fromSettings && !existingWindow.minimized &&
                global.display.focus_window?.get_title() === PANEL_TITLES.settings &&
                this._windowBeforeSettings === existingWindow)
                existingWindow.minimize();
            else
                this._activateWindow(existingWindow);
            return;
        }

        if (this._pendingPanels.has(panelName))
            return;

        const launcher = Gio.File.new_for_path(
            GLib.build_filenamev([this.path, 'panel-command.sh']));

        if (!launcher.query_exists(null)) {
            logError(new Error(`Missing panel launcher: ${launcher.get_path()}`));
            return;
        }

        const pendingPanels = this._pendingPanels;
        pendingPanels.add(panelName);
        try {
            const process = Gio.Subprocess.new(
                ['bash', launcher.get_path(), panelName],
                Gio.SubprocessFlags.NONE);
            if (panelName === 'settings')
                this._placeSettingsOnFirstOpen();
            process.wait_async(null, (source, result) => {
                try {
                    source.wait_finish(result);
                } catch (error) {
                    logError(error, `Failed to wait for Zhyprbola panel: ${panelName}`);
                } finally {
                    pendingPanels.delete(panelName);
                }
            });
        } catch (error) {
            pendingPanels.delete(panelName);
            logError(error, `Failed to open Zhyprbola panel: ${panelName}`);
        }
    }

    _placeSettingsOnFirstOpen() {
        if (this._settingsPlacementId)
            GLib.source_remove(this._settingsPlacementId);

        let attempts = 0;
        this._settingsPlacementId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
            const window = global.display.list_all_windows()
                .find(item => item.get_title() === PANEL_TITLES.settings);
            const frame = window?.get_frame_rect();
            const actor = window?.get_compositor_private();
            if (actor?.mapped && frame.width > 0 && frame.height > 0) {
                this._moveSettingsNearDock(window, frame);
                this._settingsPlacementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            if (++attempts >= 100) {
                this._settingsPlacementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    _moveSettingsNearDock(window, frame) {
        const monitor = Main.layoutManager.primaryMonitor;
        if (!this._dock || !monitor)
            return;

        const gap = 12;
        const margin = 12;
        const dockX = this._dock.get_x();
        const dockY = this._dock.get_y();
        const dockWidth = this._dock.get_width();
        const dockHeight = this._dock.get_height();
        let x = dockX + dockWidth + gap;
        let y = dockY + Math.round((dockHeight - frame.height) / 2);

        switch (this._dockPosition) {
        case DockPosition.RIGHT:
            x = dockX - frame.width - gap;
            break;
        case DockPosition.TOP:
            x = dockX + Math.round((dockWidth - frame.width) / 2);
            y = dockY + dockHeight + gap;
            break;
        case DockPosition.BOTTOM:
            x = dockX + Math.round((dockWidth - frame.width) / 2);
            y = dockY - frame.height - gap;
            break;
        default:
            break;
        }

        x = Math.max(monitor.x + margin,
            Math.min(x, monitor.x + monitor.width - frame.width - margin));
        y = Math.max(monitor.y + margin,
            Math.min(y, monitor.y + monitor.height - frame.height - margin));
        window.move_frame(true, x, y);
    }

    _queueLayout() {
        if (this._disabling || this._layoutIdleId)
            return;

        this._layoutIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._layoutIdleId = 0;
            this._layoutDock();
            return GLib.SOURCE_REMOVE;
        });
    }

    _layoutDock() {
        if (!this._dock || this._dockInteractions.size > 0)
            return;
        if (this._dockRebuildPending) {
            this._rebuildDock();
            return;
        }

        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;

        const vertical = [DockPosition.LEFT, DockPosition.RIGHT]
            .includes(this._dockPosition);
        const thickness = DOCK_CONFIG.buttonSize;
        const width = vertical ? thickness : monitor.width;
        const height = vertical ? monitor.height : thickness;
        const available = (vertical ? height : width) - 2 * DOCK_CONFIG.padding;
        for (const [index, name] of this._dockGroupOrder.entries()) {
            const start = Math.floor(available * index / this._dockGroupOrder.length);
            const end = Math.floor(available * (index + 1) / this._dockGroupOrder.length);
            const regionLength = Math.max(0, end - start);
            const region = this._dockRegions.get(name);
            region.set_size(vertical ? DOCK_CONFIG.buttonSize : regionLength,
                vertical ? regionLength : DOCK_CONFIG.buttonSize);
            const reserved = index === this._dockGroupOrder.length - 1
                ? SHOW_DESKTOP_SIZE : 0;
            this._renderDockRegion(name, Math.max(0, regionLength - reserved),
                vertical, index);
        }
        this._dock.set_size(width, height);

        let x = monitor.x;
        let y = monitor.y;

        switch (this._dockPosition) {
        case DockPosition.LEFT:
            break;
        case DockPosition.RIGHT:
            x = monitor.x + monitor.width - width;
            break;
        case DockPosition.TOP:
            break;
        case DockPosition.BOTTOM:
            y = monitor.y + monitor.height - height;
            break;
        default:
            break;
        }

        this._dock.set_position(x, y);
        // A separate chrome actor bypasses dock padding and reaches both screen
        // edges at the final corner, regardless of the Region 3 icon contents.
        this._showDesktopButton.set_style(vertical
            ? 'border-top-width: 1px; border-left-width: 0;'
            : 'border-left-width: 1px; border-top-width: 0;');
        this._showDesktopButton.set_size(vertical ? thickness : SHOW_DESKTOP_SIZE,
            vertical ? SHOW_DESKTOP_SIZE : thickness);
        this._showDesktopButton.set_position(
            vertical ? x : monitor.x + monitor.width - SHOW_DESKTOP_SIZE,
            vertical ? monitor.y + monitor.height - SHOW_DESKTOP_SIZE : y);
        this._layoutEdgeSpectrum();
    }
}
