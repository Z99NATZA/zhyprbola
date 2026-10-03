import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const DockPosition = Object.freeze({
    LEFT: 'left',
    RIGHT: 'right',
    TOP: 'top',
    BOTTOM: 'bottom',
});

const DEFAULT_DOCK_POSITION = DockPosition.LEFT;

const DOCK_CONFIG = Object.freeze({
    edgeMargin: 18,
    centerOffset: 0,
    spacing: 8,
});

const THEMES = [
    {name: 'current', wallpaper: '1.png'},
    {name: 'white', wallpaper: '2.png'},
    {name: 'white-sky', wallpaper: '3.png'},
    {name: 'forest', wallpaper: '4.png'},
    {name: 'one-half-gray', wallpaper: '5.png'},
    {name: 'red', wallpaper: '6.png'},
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
        this._wallpaperRefreshId = 0;
        this._settingsPlacementId = 0;
        this._settingsSyncId = 0;
        this._settingsMonitor = null;
        this._pendingPanels = new Set();
        this._themePath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'theme']);
        this._dockPositionPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'dock-position']);
        this._useWallpaperPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'use-wallpaper']);
        this._themeName = this._readTheme();
        this._dockPosition = this._readDockPosition();
        this._useWallpaper = this._readUseWallpaper();
        this._backgroundSettings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.background',
        });

        this._createDock();
        this._applyDockPosition();
        this._applyTheme();
        this._applyWallpaper(true);
        this._watchSettings();

        global.display.connectObject('workareas-changed', () => this._queueLayout(), this);
        Main.layoutManager.connectObject('monitors-changed', () => this._queueLayout(), this);
    }

    disable() {
        global.display.disconnectObject(this);
        Main.layoutManager.disconnectObject(this);

        if (this._layoutIdleId) {
            GLib.source_remove(this._layoutIdleId);
            this._layoutIdleId = 0;
        }

        this._cancelWallpaperRefresh();
        if (this._settingsPlacementId) {
            GLib.source_remove(this._settingsPlacementId);
            this._settingsPlacementId = 0;
        }
        if (this._settingsSyncId) {
            GLib.source_remove(this._settingsSyncId);
            this._settingsSyncId = 0;
        }
        this._settingsMonitor?.cancel();
        this._settingsMonitor = null;
        this._destroyDock();
        this._backgroundSettings = null;
    }

    _createDock() {
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT].includes(this._dockPosition);
        this._dock = new St.BoxLayout({
            style_class: 'zhyprbola-dock',
            style: `spacing: ${DOCK_CONFIG.spacing}px;`,
            vertical,
            reactive: true,
            track_hover: true,
        });

        this._dock.add_child(this._createPanelButton({
            iconName: 'bluetooth',
            accessibleName: 'Bluetooth',
            panelName: 'bluetooth',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'wifi',
            accessibleName: 'Wi-Fi',
            panelName: 'wifi',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'clock-weather',
            accessibleName: 'Clock and Weather',
            panelName: 'clock-weather',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'system-status',
            accessibleName: 'System Status',
            panelName: 'system-status',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'audio-spectrum',
            accessibleName: 'Audio Spectrum',
            panelName: 'audio-spectrum',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'music',
            accessibleName: 'Music Player',
            panelName: 'music',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'todo',
            accessibleName: 'Today',
            panelName: 'todo',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'calendar',
            accessibleName: 'Calendar',
            panelName: 'calendar',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'settings',
            accessibleName: 'Zhyprbola settings',
            panelName: 'settings',
        }));

        this._layoutDock();
        Main.layoutManager.addTopChrome(this._dock, {trackFullscreen: true});
        this._layoutDock();
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
        const themeChanged = theme !== this._themeName;
        const positionChanged = position !== this._dockPosition;
        const wallpaperChanged = useWallpaper !== this._useWallpaper;

        this._themeName = theme;
        this._dockPosition = position;
        this._useWallpaper = useWallpaper;

        if (positionChanged)
            this._rebuildDock();
        else if (themeChanged)
            this._applyTheme();
        if (themeChanged || wallpaperChanged)
            this._applyWallpaper(wallpaperChanged && useWallpaper);
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

        Main.layoutManager.removeChrome(this._dock);
        this._dock.destroy();
        this._dock = null;
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
        const iconPath = GLib.build_filenamev([this.path, 'icons', `${iconName}.svg`]);
        const icon = new St.Icon({
            gicon: new Gio.FileIcon({file: Gio.File.new_for_path(iconPath)}),
            style_class: 'zhyprbola-dock-icon',
        });

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

        const [, naturalWidth] = this._dock.get_preferred_width(-1);
        const [, naturalHeight] = this._dock.get_preferred_height(-1);
        const margin = DOCK_CONFIG.edgeMargin;
        const offset = DOCK_CONFIG.centerOffset;

        let x = monitor.x + Math.round((monitor.width - naturalWidth) / 2);
        let y = monitor.y + Math.round((monitor.height - naturalHeight) / 2);

        switch (this._dockPosition) {
        case DockPosition.LEFT:
            x = monitor.x + margin;
            y += offset;
            break;
        case DockPosition.RIGHT:
            x = monitor.x + monitor.width - naturalWidth - margin;
            y += offset;
            break;
        case DockPosition.TOP:
            y = monitor.y + margin;
            x += offset;
            break;
        case DockPosition.BOTTOM:
            y = monitor.y + monitor.height - naturalHeight - margin;
            x += offset;
            break;
        default:
            break;
        }

        this._dock.set_position(x, y);
    }
}
