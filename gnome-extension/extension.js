import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const DockPosition = Object.freeze({
    LEFT: 'left',
    RIGHT: 'right',
    TOP: 'top',
    BOTTOM: 'bottom',
});

const DEFAULT_DOCK_POSITION = DockPosition.BOTTOM;

const DOCK_CONFIG = Object.freeze({
    buttonSize: 32,
    groupSpacing: 4,
    padding: 4,
    thickness: 40,
});

const DEFAULT_DOCK_GROUPS = ['zhyprbola', 'apps', 'running'];
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
        this._themePath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'theme']);
        this._dockPositionPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-position']);
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
        this._pinnedAppsPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'pinned-apps']);
        this._themeName = this._readTheme();
        this._dockPosition = this._readDockPosition();
        this._useWallpaper = this._readUseWallpaper();
        this._edgeEnabled = this._readEdgeEnabled();
        this._edgePosition = this._readEdgePosition();
        this._dockGroups = this._readDockGroups();
        this._dockGroupOrder = this._readDockGroupOrder();
        this._pinnedApps = this._readPinnedApps();
        this._appSystem = Shell.AppSystem.get_default();
        this._windowTracker = Shell.WindowTracker.get_default();
        this._backgroundSettings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.background',
        });

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
    }

    disable() {
        global.display.disconnectObject(this);
        Main.layoutManager.disconnectObject(this);
        this._appSystem.disconnectObject(this);
        this._windowTracker.disconnectObject(this);

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
        this._panelIconSources = null;
    }

    _createDock() {
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT].includes(this._dockPosition);
        this._dock = new St.BoxLayout({
            style_class: 'zhyprbola-dock',
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

        const panels = [
            ['settings', 'Zhyprbola settings'],
            ['bluetooth', 'Bluetooth'],
            ['wifi', 'Wi-Fi'],
            ['clock-weather', 'Clock and Weather'],
            ['system-status', 'System Status'],
            ['audio-spectrum', 'Audio Spectrum'],
            ['music', 'Music Player'],
            ['todo', 'Today'],
            ['calendar', 'Calendar'],
        ];
        this._dockItems.set('zhyprbola', panels.map(([name, label]) => ({
            kind: 'panel', name, label,
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

    _createAppButton(app, running) {
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT]
            .includes(this._dockPosition);
        const focused = app.get_windows().some(window => window.has_focus());
        const content = new St.Widget({
            width: DOCK_CONFIG.buttonSize,
            height: DOCK_CONFIG.buttonSize,
            layout_manager: new Clutter.FixedLayout(),
        });
        const icon = new St.Icon({
            gicon: app.get_icon(),
            icon_size: 21,
            style_class: 'zhyprbola-dock-app-icon',
            x: this._dockPosition === DockPosition.LEFT ? 8
                : this._dockPosition === DockPosition.RIGHT ? 3 : 6,
            y: this._dockPosition === DockPosition.TOP ? 8
                : this._dockPosition === DockPosition.BOTTOM ? 3 : 6,
        });
        content.add_child(icon);
        if (running) {
            const indicator = new St.Widget({
                style_class: 'zhyprbola-dock-app-indicator',
                width: vertical ? (focused ? 3 : 4) : (focused ? 14 : 4),
                height: vertical ? (focused ? 14 : 4) : (focused ? 3 : 4),
                x: this._dockPosition === DockPosition.LEFT ? 1
                    : this._dockPosition === DockPosition.RIGHT ? 28
                        : (focused ? 9 : 14),
                y: this._dockPosition === DockPosition.TOP ? 1
                    : this._dockPosition === DockPosition.BOTTOM ? 28
                        : (focused ? 9 : 14),
            });
            content.add_child(indicator);
        }
        const button = new St.Button({
            style_class: 'zhyprbola-dock-app-button',
            child: content,
            can_focus: true,
            reactive: true,
            track_hover: true,
            accessible_name: app.get_name(),
        });
        button.connect('clicked', () => this._activateApp(app));
        return button;
    }

    _activateApp(app) {
        const focused = app.get_windows().find(window => window.has_focus());
        if (focused)
            focused.minimize();
        else
            app.activate();
    }

    _refreshAppGroups() {
        if (!this._dockGroupsByName)
            return;
        const pinned = this._pinnedShellApps();
        this._dockItems.set('apps', pinned.map(app => ({
            kind: 'app', app, label: app.get_name(), running: app.get_n_windows() > 0,
        })));

        const pinnedIds = new Set(pinned.map(app => app.get_id()));
        const running = [];
        for (const app of this._appSystem.get_running()) {
            const windows = app.get_windows();
            if (pinnedIds.has(app.get_id()) || windows.length === 0 ||
                windows.every(window => window.get_title()?.startsWith('Zhyprbola ')))
                continue;
            running.push({kind: 'app', app, label: app.get_name(), running: true});
        }
        this._dockItems.set('running', running);
        this._dockRenderState.delete('apps');
        this._dockRenderState.delete('running');
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
        const useWallpaper = this._readUseWallpaper();
        const edgeEnabled = this._readEdgeEnabled();
        const edgePosition = this._readEdgePosition();
        const dockGroups = this._readDockGroups();
        const dockGroupOrder = this._readDockGroupOrder();
        const pinnedApps = this._readPinnedApps();
        const themeChanged = theme !== this._themeName;
        const positionChanged = position !== this._dockPosition;
        const wallpaperChanged = useWallpaper !== this._useWallpaper;
        const edgeChanged = edgeEnabled !== this._edgeEnabled ||
            edgePosition !== this._edgePosition;
        const groupsChanged = dockGroups.join(',') !== this._dockGroups.join(',') ||
            dockGroupOrder.join(',') !== this._dockGroupOrder.join(',') ||
            JSON.stringify(pinnedApps) !== JSON.stringify(this._pinnedApps);

        this._themeName = theme;
        this._dockPosition = position;
        this._useWallpaper = useWallpaper;
        this._edgeEnabled = edgeEnabled;
        this._edgePosition = edgePosition;
        this._dockGroups = dockGroups;
        this._dockGroupOrder = dockGroupOrder;
        this._pinnedApps = pinnedApps;

        if (positionChanged || groupsChanged)
            this._rebuildDock();
        else if (themeChanged)
            this._applyTheme();
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
        for (const [name, icon] of this._panelIcons)
            icon.gicon = this._panelGicon(name);
        this._overflowMenu?.destroy();
        this._overflowMenu = null;
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

        button.connect('clicked', () => this._openPanel(panelName));
        return button;
    }

    _panelGicon(name) {
        const path = GLib.build_filenamev([this.path, 'icons', `${name}.svg`]);
        try {
            let source = this._panelIconSources.get(name);
            if (!source) {
                const [, contents] = GLib.file_get_contents(path);
                source = new TextDecoder().decode(contents);
                this._panelIconSources.set(name, source);
            }
            const theme = THEMES.find(item => item.name === this._themeName);
            const svg = source.replace(/#fff(?:fff)?\b/gi, theme.iconColor);
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
        const state = `${length}:${items.length}:${vertical}:${slot}`;
        if (this._dockRenderState.get(name) === state)
            return;

        this._overflowMenu?.destroy();
        this._overflowMenu = null;
        if (name === 'zhyprbola')
            this._panelIcons.clear();
        for (const child of group.get_children())
            child.destroy();

        const maxSlots = Math.max(0, Math.floor((length + DOCK_CONFIG.groupSpacing) /
            (DOCK_CONFIG.buttonSize + DOCK_CONFIG.groupSpacing)));
        const overflow = items.length > maxSlots;
        const visibleCount = overflow ? Math.max(0, maxSlots - 1) : items.length;
        for (const item of items.slice(0, visibleCount)) {
            group.add_child(item.kind === 'panel'
                ? this._createPanelButton({iconName: item.name,
                    accessibleName: item.label, panelName: item.name})
                : this._createAppButton(item.app, item.running));
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
                ? this._panelGicon(item.name) : item.app.get_icon();
            menu.addAction(item.label, () => {
                if (item.kind === 'panel')
                    this._openPanel(item.name);
                else
                    this._activateApp(item.app);
            }, icon);
        }
        Main.uiGroup.add_child(menu.actor);
        menu.actor.hide();
        this._menuManager.addMenu(menu);
        this._overflowMenu = menu;
        menu.open();
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
        const thickness = DOCK_CONFIG.thickness;
        const width = vertical ? thickness : monitor.width;
        const height = vertical ? monitor.height : thickness;
        const available = (vertical ? height : width) - 2 * DOCK_CONFIG.padding;
        for (const [index, name] of this._dockGroupOrder.entries()) {
            const start = Math.floor(available * index / 3);
            const end = Math.floor(available * (index + 1) / 3);
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
