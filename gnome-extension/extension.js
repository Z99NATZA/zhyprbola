import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
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

const DOCK_CONFIG = Object.freeze({
    iconSize: 16,
    buttonSize: 27,
    groupSpacing: 4,
    padding: 4,
});

const DEFAULT_DOCK_GROUPS = ['zhyprbola', 'apps', 'running'];
const DOCK_REGIONS = ['empty', 'launchers', 'zhyprbola'];
const LAUNCHER_GROUPS = ['apps', 'running'];
const DOCK_COMPONENTS = [
    ['settings', 'Zhyprbola settings'],
    ['bluetooth', 'Bluetooth'],
    ['wifi', 'Wi-Fi'],
    ['clock-weather', 'Clock and Weather'],
    ['system-status', 'System Status'],
    ['audio-spectrum', 'Audio Spectrum'],
    ['music', 'Music Player'],
    ['todo', 'Today'],
    ['calendar', 'Calendar'],
    ['input-source', 'Input Source'],
    ['power', 'Power'],
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
];

const PANEL_TITLES = Object.freeze({
    bluetooth: 'Zhyprbola Bluetooth',
    wifi: 'Zhyprbola Wi-Fi',
    'clock-weather': 'Zhyprbola Clock & Weather',
    'system-status': 'Zhyprbola System Status',
    'audio-spectrum': 'Zhyprbola Audio Spectrum',
    music: 'Zhyprbola Music Player',
    todo: 'Zhyprbola Today',
    calendar: 'Zhyprbola Calendar',
    settings: 'Zhyprbola Settings',
});

export default class ZhyprbolaExtension extends Extension {
    enable() {
        this._dock = null;
        this._layoutIdleId = 0;
        this._appRefreshId = 0;
        this._wallpaperRefreshId = 0;
        this._settingsPlacementId = 0;
        this._edgePlacementId = 0;
        this._edgeProcess = null;
        this._settingsSyncId = 0;
        this._settingsMonitor = null;
        this._pendingPanels = new Set();
        this._panelIconSources = new Map();
        this._inputSourceMenu = null;
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
        this._startEdgeSpectrum();

        this._appSystem.connectObject('app-state-changed',
            () => this._queueAppRefresh(), this);
        this._windowTracker.connectObject('tracked-windows-changed',
            () => this._queueAppRefresh(), this);

        global.display.connectObject(
            'workareas-changed', () => this._queueLayout(),
            'notify::focus-window', () => this._queueAppRefresh(), this);
        Main.layoutManager.connectObject('monitors-changed', () => {
            this._queueLayout();
            this._restartEdgeSpectrum();
        }, this);
        this._inputSourceSettings.connectObject(
            'changed::current', () => this._queueInputSourceRefresh(),
            'changed::sources', () => this._queueInputSourceRefresh(), this);
    }

    disable() {
        global.display.disconnectObject(this);
        Main.layoutManager.disconnectObject(this);
        this._appSystem.disconnectObject(this);
        this._windowTracker.disconnectObject(this);
        this._inputSourceSettings.disconnectObject(this);

        if (this._layoutIdleId) {
            GLib.source_remove(this._layoutIdleId);
            this._layoutIdleId = 0;
        }
        if (this._appRefreshId) {
            GLib.source_remove(this._appRefreshId);
            this._appRefreshId = 0;
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
        this._destroyDock();
        this._appSystem = null;
        this._windowTracker = null;
        this._backgroundSettings = null;
        this._inputSourceSettings = null;
        this._inputSourceManager = null;
        this._panelIconSources = null;
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
        for (const name of DOCK_REGIONS) {
            const region = new St.Widget({
                style_class: `zhyprbola-dock-region zhyprbola-dock-region-${name}`,
            });
            this._dock.add_child(region);
            this._dockRegions.set(name, region);
            if (name === 'empty')
                continue;
            if (name === 'launchers' &&
                !LAUNCHER_GROUPS.some(group => this._dockGroups.includes(group)))
                continue;

            const group = new St.BoxLayout({
                style_class: `zhyprbola-dock-group zhyprbola-dock-group-${name}`,
                vertical,
            });
            region.add_child(group);
            this._dockGroupsByName.set(name, group);
        }

        this._createComponentButtons();
        this._refreshAppGroups();

        Main.layoutManager.addChrome(this._dock, {
            affectsStruts: true,
            trackFullscreen: true,
        });
        this._layoutDock();
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

    _createAppButton(app, running, window = null) {
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT]
            .includes(this._dockPosition);
        const focused = window
            ? window.has_focus()
            : app.get_windows().some(appWindow => appWindow.has_focus());
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
        if (running) {
            const indicatorWidth = vertical ? 4 : (focused ? 14 : 4);
            const indicatorHeight = vertical ? (focused ? 14 : 4) : 4;
            const indicator = new St.Widget({
                style_class: 'zhyprbola-dock-app-indicator',
                width: indicatorWidth,
                height: indicatorHeight,
                x: this._dockPosition === DockPosition.LEFT ? 0
                    : this._dockPosition === DockPosition.RIGHT
                        ? DOCK_CONFIG.buttonSize - indicatorWidth
                        : iconX + (DOCK_CONFIG.iconSize - indicatorWidth) / 2,
                y: this._dockPosition === DockPosition.TOP ? 0
                    : this._dockPosition === DockPosition.BOTTOM
                        ? DOCK_CONFIG.buttonSize - indicatorHeight
                        : iconY + (DOCK_CONFIG.iconSize - indicatorHeight) / 2,
            });
            content.add_child(indicator);
        }
        const button = new St.Button({
            style_class: 'zhyprbola-dock-app-button',
            child: content,
            can_focus: true,
            reactive: true,
            track_hover: true,
            accessible_name: window?.get_title() ?? app.get_name(),
        });
        button.connect('clicked', () => window
            ? this._activateWindow(window) : this._activateApp(app));
        return button;
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

    _refreshAppGroups() {
        if (!this._dockGroupsByName)
            return;
        const pinned = this._pinnedShellApps();
        const pinnedItems = [];
        for (const app of pinned) {
            const windows = this._windowItemsForApp(app);
            if (this._dockUngroupWindows && windows.length > 0)
                pinnedItems.push(...windows);
            else
                pinnedItems.push({
                    kind: 'app', app, label: app.get_name(), running: windows.length > 0,
                });
        }
        this._dockItems.set('apps', pinnedItems);

        const pinnedIds = new Set(pinned.map(app => app.get_id()));
        const running = [];
        for (const app of this._appSystem.get_running()) {
            const windows = app.get_windows();
            if (pinnedIds.has(app.get_id()) || windows.length === 0 ||
                windows.every(window => window.get_title()?.startsWith('Zhyprbola ')))
                continue;
            if (this._dockUngroupWindows)
                running.push(...this._windowItemsForApp(app));
            else
                running.push({kind: 'app', app, label: app.get_name(), running: true});
        }
        this._dockItems.set('running', running);
        this._dockRenderState.delete('apps');
        this._dockRenderState.delete('running');
        this._dockRenderState.delete('launchers');
        this._queueLayout();
    }

    _launcherItems() {
        const items = [];
        for (const name of this._dockGroupOrder) {
            if (LAUNCHER_GROUPS.includes(name) && this._dockGroups.includes(name))
                items.push(...(this._dockItems.get(name) ?? []));
        }
        return items;
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
        if (!this._dockRenderState)
            return;
        this._inputSourceMenu?.destroy();
        this._inputSourceMenu = null;
        this._dockRenderState.delete('zhyprbola');
        this._queueLayout();
    }

    _readTheme() {
        try {
            const [, contents] = GLib.file_get_contents(this._themePath);
            const name = new TextDecoder().decode(contents).trim();
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
            const names = new TextDecoder().decode(contents).trim()
                .split(/[\s,]+/).filter(name => DEFAULT_DOCK_GROUPS.includes(name));
            const groups = [...new Set(names)];
            if (!groups.includes('zhyprbola'))
                groups.push('zhyprbola');
            return groups;
        } catch (_) {
            return [...DEFAULT_DOCK_GROUPS];
        }
    }

    _readDockGroupOrder() {
        try {
            const [, contents] = GLib.file_get_contents(this._dockGroupOrderPath);
            const names = new TextDecoder().decode(contents).trim()
                .split(/[\s,]+/).filter(name => DEFAULT_DOCK_GROUPS.includes(name));
            return [...new Set(names),
                ...DEFAULT_DOCK_GROUPS.filter(name => !names.includes(name))];
        } catch (_) {
            return [...DEFAULT_DOCK_GROUPS];
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
            for (const name of defaults) {
                if (!visible.includes(name) && !hidden.includes(name))
                    visible.push(name);
            }
            return {visible, hidden};
        } catch (_) {
            return {visible: defaults, hidden: []};
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
        } catch (error) {
            logError(error, 'Failed to watch Zhyprbola settings');
        }
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
            this._dockComponents.hidden.join(',');

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
            const process = Gio.Subprocess.new(
                ['bash', launcher, 'edge-spectrum'], Gio.SubprocessFlags.NONE);
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
                let x = monitor.x;
                let y = monitor.y;
                if (this._edgePosition === DockPosition.RIGHT)
                    x += monitor.width - frame.width;
                else if (this._edgePosition === DockPosition.BOTTOM)
                    y += monitor.height - frame.height;
                window.move_frame(true, x, y);
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
        this._applyDockBackground();
        for (const [name, icon] of this._panelIcons)
            icon.gicon = this._panelGicon(name);
        this._overflowMenu?.destroy();
        this._overflowMenu = null;
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
        this._destroyDock();
        this._createDock();
        this._applyTheme();
        this._applyDockPosition();
    }

    _destroyDock() {
        if (!this._dock)
            return;

        this._inputSourceMenu?.destroy();
        this._inputSourceMenu = null;
        this._powerMenu?.destroy();
        this._powerMenu = null;
        this._overflowMenu?.destroy();
        this._overflowMenu = null;
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

    _currentInputSourceIndex(sources = this._inputSources()) {
        if (sources.length === 0)
            return -1;
        const currentSource = this._inputSourceManager?.currentSource ??
            this._inputSourceManager?._currentSource;
        if (currentSource) {
            const current = sources.findIndex(source =>
                source.managerSource === currentSource ||
                source.index === currentSource.index ||
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
        return this._inputSourceCode(sources[index]);
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
            accessible_name: 'Input Source',
        });
        button.connect('clicked', () => this._openInputSourceMenu(button));
        return button;
    }

    _openInputSourceMenu(button) {
        if (this._inputSourceMenu?.sourceActor === button) {
            this._inputSourceMenu.toggle();
            return;
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
        menu.actor.add_style_class_name('zhyprbola-overflow-menu');
        menu.box.set_style(`background-color: #fafcfd; color: ${theme.iconColor};`);
        for (const [index, source] of sources.entries()) {
            const item = menu.addAction(this._inputSourceName(source), () => {
                if (source.managerSource?.activate)
                    source.managerSource.activate(true);
                else
                    this._inputSourceSettings.set_uint('current', index);
                this._queueInputSourceRefresh();
            });
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
            `${items.map(item => item.kind === 'input-source'
                ? this._currentInputSourceCode() : item.label).join('|')}`;
        if (this._dockRenderState.get(name) === state)
            return;

        this._overflowMenu?.destroy();
        this._overflowMenu = null;
        if (name === 'zhyprbola') {
            this._inputSourceMenu?.destroy();
            this._inputSourceMenu = null;
            this._powerMenu?.destroy();
            this._powerMenu = null;
            this._panelIcons.clear();
        }
        for (const child of group.get_children())
            child.destroy();

        const maxSlots = Math.max(0, Math.floor((length + DOCK_CONFIG.groupSpacing) /
            (DOCK_CONFIG.buttonSize + DOCK_CONFIG.groupSpacing)));
        const overflow = items.length > maxSlots;
        const visibleCount = overflow ? Math.max(0, maxSlots - 1) : items.length;
        for (const item of items.slice(0, visibleCount)) {
            group.add_child(item.kind === 'input-source'
                ? this._createInputSourceButton()
                : item.kind === 'panel'
                ? this._createPanelButton({iconName: item.name,
                    accessibleName: item.label, panelName: item.name})
                : this._createAppButton(item.app, item.running, item.window));
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
                this._showOverflow(more, items.slice(visibleCount)));
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

    _openPanel(panelName) {
        const title = PANEL_TITLES[panelName];
        const existingWindow = global.display.list_all_windows()
            .find(window => window && (window.get_title() === title ||
                (panelName === 'bluetooth' && window.get_title() === 'Zhyprbola Panel')));

        if (existingWindow) {
            if (existingWindow.minimized) {
                existingWindow.unminimize();
                existingWindow.activate(global.get_current_time());
            } else {
                existingWindow.minimize();
            }
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
        if (this._layoutIdleId)
            return;

        this._layoutIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._layoutIdleId = 0;
            this._layoutDock();
            return GLib.SOURCE_REMOVE;
        });
    }

    _layoutDock() {
        if (!this._dock)
            return;

        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;

        const vertical = [DockPosition.LEFT, DockPosition.RIGHT]
            .includes(this._dockPosition);
        const thickness = DOCK_CONFIG.buttonSize;
        const width = vertical ? thickness : monitor.width;
        const height = vertical ? monitor.height : thickness;
        const available = (vertical ? height : width) - 2 * DOCK_CONFIG.padding;
        this._dockItems.set('launchers', this._launcherItems());
        for (const [index, name] of DOCK_REGIONS.entries()) {
            const start = Math.floor(available * index / DOCK_REGIONS.length);
            const end = Math.floor(available * (index + 1) / DOCK_REGIONS.length);
            const regionLength = Math.max(0, end - start);
            const region = this._dockRegions.get(name);
            region.set_size(vertical ? DOCK_CONFIG.buttonSize : regionLength,
                vertical ? regionLength : DOCK_CONFIG.buttonSize);
            this._renderDockRegion(name, regionLength, vertical, index);
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
    }
}
