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

const DOCK_CONFIG = Object.freeze({
    position: DockPosition.RIGHT,
    edgeMargin: 18,
    centerOffset: 0,
    spacing: 8,
});

export default class ZhyprbolaExtension extends Extension {
    enable() {
        this._dock = null;
        this._layoutIdleId = 0;

        this._createDock();
        this._queueLayout();

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

        Main.layoutManager.addTopChrome(this._dock, {trackFullscreen: true});
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
        const launcher = Gio.File.new_for_path(
            GLib.build_filenamev([this.path, 'panel-command.sh']));

        if (!launcher.query_exists(null)) {
            logError(new Error(`Missing panel launcher: ${launcher.get_path()}`));
            return;
        }

        try {
            GLib.spawn_async(
                null,
                ['bash', launcher.get_path(), panelName],
                null,
                GLib.SpawnFlags.SEARCH_PATH,
                null);
        } catch (error) {
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
