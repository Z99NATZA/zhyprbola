import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
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

const DOCK_CONFIG = Object.freeze({
    position: DockPosition.RIGHT,
    edgeMargin: 18,
    centerOffset: 0,
    spacing: 8,
});

const THEMES = [
    {name: 'current', label: '1. Purple', wallpaper: '1.png'},
    {name: 'white', label: '2. White Mist', wallpaper: '2.png'},
    {name: 'white-sky', label: '3. White Sky', wallpaper: '3.png'},
    {name: 'forest', label: '4. Forest Calm', wallpaper: '4.png'},
];

const PANEL_TITLES = Object.freeze({
    bluetooth: 'Zhyprbola Bluetooth',
    wifi: 'Zhyprbola Wi-Fi',
    'clock-weather': 'Zhyprbola Clock & Weather',
    'system-status': 'Zhyprbola System Status',
});

export default class ZhyprbolaExtension extends Extension {
    enable() {
        this._dock = null;
        this._layoutIdleId = 0;
        this._pendingPanels = new Set();
        this._themePath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'theme']);
        this._useWallpaperPath = GLib.build_filenamev([
            GLib.get_user_config_dir(), 'zhyprbola', 'use-wallpaper']);
        this._themeName = this._readTheme();
        this._useWallpaper = this._readUseWallpaper();
        this._backgroundSettings = new Gio.Settings({
            schema_id: 'org.gnome.desktop.background',
        });

        this._createDock();
        this._applyTheme();
        this._applyWallpaper();
        this._queueLayout();

        global.display.connectObject('workareas-changed', () => this._queueLayout(), this);
        Main.layoutManager.connectObject('monitors-changed', () => this._queueLayout(), this);
    }

    disable() {
        global.display.disconnectObject(this);
        Main.layoutManager.disconnectObject(this);

        if (this._themeMenu) {
            this._menuManager.removeMenu(this._themeMenu);
            this._themeMenu.destroy();
            this._themeMenu = null;
        }
        this._themeItems = null;
        this._useWallpaperItem = null;
        this._menuManager = null;
        this._backgroundSettings = null;

        if (this._layoutIdleId) {
            GLib.source_remove(this._layoutIdleId);
            this._layoutIdleId = 0;
        }

        if (this._dock) {
            Main.layoutManager.removeChrome(this._dock);
            this._dock.destroy();
            this._dock = null;
        }
    }

    _createDock() {
        const vertical = [DockPosition.LEFT, DockPosition.RIGHT].includes(DOCK_CONFIG.position);
        this._dock = new St.BoxLayout({
            style_class: 'zhyprbola-dock',
            style: `spacing: ${DOCK_CONFIG.spacing}px;`,
            vertical,
            reactive: true,
            track_hover: true,
        });

        this._dock.add_child(this._createPanelButton({
            iconName: 'bluetooth-active-symbolic',
            accessibleName: 'Bluetooth',
            panelName: 'bluetooth',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'network-wireless-symbolic',
            accessibleName: 'Wi-Fi',
            panelName: 'wifi',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'weather-clear-symbolic',
            accessibleName: 'Clock and Weather',
            panelName: 'clock-weather',
        }));
        this._dock.add_child(this._createPanelButton({
            iconName: 'utilities-system-monitor-symbolic',
            accessibleName: 'System Status',
            panelName: 'system-status',
        }));
        this._dock.add_child(this._createThemeButton());

        Main.layoutManager.addTopChrome(this._dock, {trackFullscreen: true});
    }

    _createThemeButton() {
        const icon = new St.Icon({
            icon_name: 'preferences-desktop-theme-symbolic',
            style_class: 'zhyprbola-dock-icon',
        });
        const button = new St.Button({
            style_class: 'zhyprbola-dock-button',
            child: icon,
            can_focus: true,
            reactive: true,
            track_hover: true,
            accessible_name: 'Choose theme',
        });

        const side = {
            [DockPosition.LEFT]: St.Side.RIGHT,
            [DockPosition.RIGHT]: St.Side.LEFT,
            [DockPosition.TOP]: St.Side.BOTTOM,
            [DockPosition.BOTTOM]: St.Side.TOP,
        }[DOCK_CONFIG.position];
        this._themeMenu = new PopupMenu.PopupMenu(button, 0.5, side);
        this._themeMenu.actor.add_style_class_name('zhyprbola-theme-menu');
        this._themeMenu.actor.hide();
        Main.uiGroup.add_child(this._themeMenu.actor);
        this._menuManager = new PopupMenu.PopupMenuManager(button);
        this._menuManager.addMenu(this._themeMenu);
        this._themeItems = new Map();

        for (const theme of THEMES) {
            const item = new PopupMenu.PopupMenuItem(theme.label);
            item.connect('activate', () => this._setTheme(theme.name));
            this._themeMenu.addMenuItem(item);
            this._themeItems.set(theme.name, item);
        }
        this._themeMenu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._useWallpaperItem = new PopupMenu.PopupSwitchMenuItem(
            'Use wallpaper', this._useWallpaper);
        this._useWallpaperItem.connect('toggled', (_item, state) => {
            this._setUseWallpaper(state);
        });
        this._themeMenu.addMenuItem(this._useWallpaperItem);

        button.connect('clicked', () => this._themeMenu.toggle());
        return button;
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

    _readUseWallpaper() {
        try {
            const [, contents] = GLib.file_get_contents(this._useWallpaperPath);
            return new TextDecoder().decode(contents).trim() === 'true';
        } catch (_) {
            return false;
        }
    }

    _setTheme(name) {
        if (!THEMES.some(theme => theme.name === name))
            return;

        try {
            GLib.mkdir_with_parents(GLib.path_get_dirname(this._themePath), 0o700);
            GLib.file_set_contents(this._themePath, `${name}\n`);
            this._themeName = name;
            this._applyTheme();
            this._applyWallpaper();
        } catch (error) {
            logError(error, 'Failed to save Zhyprbola theme');
        }
    }

    _setUseWallpaper(enabled) {
        try {
            GLib.mkdir_with_parents(GLib.path_get_dirname(this._useWallpaperPath), 0o700);
            GLib.file_set_contents(this._useWallpaperPath, enabled ? 'true\n' : 'false\n');
            this._useWallpaper = enabled;
            this._applyWallpaper();
        } catch (error) {
            logError(error, 'Failed to save Zhyprbola wallpaper setting');
        }
    }

    _applyTheme() {
        if (this._themeName === 'white' || this._themeName === 'white-sky') {
            this._dock.add_style_class_name('zhyprbola-dock-white');
            this._themeMenu.actor.add_style_class_name('zhyprbola-theme-menu-white');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-white');
            this._themeMenu.actor.remove_style_class_name('zhyprbola-theme-menu-white');
        }
        if (this._themeName === 'white-sky') {
            this._dock.add_style_class_name('zhyprbola-dock-white-sky');
            this._themeMenu.actor.add_style_class_name('zhyprbola-theme-menu-white-sky');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-white-sky');
            this._themeMenu.actor.remove_style_class_name('zhyprbola-theme-menu-white-sky');
        }
        if (this._themeName === 'forest') {
            this._dock.add_style_class_name('zhyprbola-dock-forest');
            this._themeMenu.actor.add_style_class_name('zhyprbola-theme-menu-forest');
        } else {
            this._dock.remove_style_class_name('zhyprbola-dock-forest');
            this._themeMenu.actor.remove_style_class_name('zhyprbola-theme-menu-forest');
        }

        for (const [name, item] of this._themeItems)
            item.setOrnament(name === this._themeName
                ? PopupMenu.Ornament.CHECK
                : PopupMenu.Ornament.NONE);
    }

    _applyWallpaper() {
        if (!this._useWallpaper || !this._backgroundSettings)
            return;

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
        this._backgroundSettings.set_string('picture-uri', uri);
        this._backgroundSettings.set_string('picture-uri-dark', uri);
        this._backgroundSettings.set_string('picture-options', 'zoom');
    }

    _createPanelButton({iconName, accessibleName, panelName}) {
        const icon = new St.Icon({
            icon_name: iconName,
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
        const existingWindow = global.get_window_actors()
            .map(actor => actor.meta_window)
            .find(window => window && (window.get_title() === title ||
                (panelName === 'bluetooth' && window.get_title() === 'Zhyprbola Panel')));

        if (existingWindow) {
            existingWindow.activate(global.get_current_time());
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

        switch (DOCK_CONFIG.position) {
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
