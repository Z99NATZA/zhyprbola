import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const TITLE = 'Zhyprbola Screenshots';

export function edgeGeometry(monitor, side, alignment) {
    const width = 5;
    const height = 100;
    const slot = alignment === 'top' ? 0 : alignment === 'bottom' ? 2 : 1;
    return {
        x: side === 'right' ? monitor.x + monitor.width - width : monitor.x,
        y: monitor.y + Math.round(monitor.height * (slot + 0.5) / 3 - height / 2),
        width, height,
    };
}

const BUS = 'org.zhyprbola.Screenshots';
const PATH = '/org/zhyprbola/Screenshots';

export class ScreenshotEdge {
    constructor(launch, getAccent = () => '#875a82') {
        this._launch = launch;
        this._getAccent = getAccent;
        this._placementId = 0;
        this._generation = 0;
        this._desiredOpen = false;
        this._ready = false;
        this._destroyed = false;
        this._process = null;
        this._configDir = GLib.build_filenamev([GLib.get_user_config_dir(), 'zhyprbola']);
        this._configPath = GLib.build_filenamev([this._configDir, 'screenshots-edge']);
        this._button = new St.Button({
            style_class: 'zhyprbola-screenshot-edge',
            reactive: true, can_focus: true, track_hover: true,
            accessible_name: 'Screenshots',
        });
        this._button.connect('clicked', () => this.toggle());
        this._button.connect('notify::hover', () => {
            this._button.opacity = this._button.hover ? 255 : 190;
        });
        this._button.opacity = 190;
        // The handle stays available on fullscreen windows and in overview.
        Main.layoutManager.addTopChrome(this._button, {affectsStruts: false, trackFullscreen: false});
        this._stageId = global.stage.connect('captured-event', (_stage, event) => {
            if (!this._desiredOpen || ![Clutter.EventType.BUTTON_PRESS, Clutter.EventType.TOUCH_BEGIN]
                .includes(event.type()))
                return Clutter.EVENT_PROPAGATE;
            const [x, y] = event.get_coords();
            const inside = rect => x >= rect.x && x < rect.x + rect.width
                && y >= rect.y && y < rect.y + rect.height;
            const monitor = Main.layoutManager.primaryMonitor;
            const handle = monitor && edgeGeometry(monitor, this._side, this._alignment);
            const window = this._window();
            if (handle && !inside(handle) && (!window || !inside(window.get_frame_rect())))
                this.hide();
            // Let the clicked application receive the same click.
            return Clutter.EVENT_PROPAGATE;
        });
        this._focusId = global.display.connect('notify::focus-window', () => {
            if (!this._desiredOpen)
                return;
            const window = this._window();
            if (window && global.display.focus_window === window)
                this._focusedOnce = true;
            else if (this._focusedOnce)
                this.hide();
        });
        GLib.mkdir_with_parents(this._configDir, 0o700);
        this._monitor = Gio.File.new_for_path(this._configDir)
            .monitor_directory(Gio.FileMonitorFlags.NONE, null);
        this._monitor.connect('changed', (_monitor, file, other) => {
            if ([file?.get_basename(), other?.get_basename()].includes('screenshots-edge'))
                this.layout();
        });
        this._dismissId = Gio.DBus.session.signal_subscribe(BUS, BUS, 'dismissRequested', PATH,
            null, Gio.DBusSignalFlags.NONE, () => {
                this._desiredOpen = false;
                this._generation++;
                this._stopPlacement();
            });
        this._watchId = Gio.bus_watch_name(Gio.BusType.SESSION, BUS, Gio.BusNameWatcherFlags.NONE,
            () => {
                if (this._destroyed)
                    return;
                this._ready = true;
                if (this._desiredOpen)
                    this._show();
            }, () => {
                if (this._ready) {
                    this._desiredOpen = false;
                    this._generation++;
                    this._stopPlacement();
                }
                this._ready = false;
            });
        this.layout();
        this._ensureProcess();
    }

    _ensureProcess() {
        if (this._ready || this._process || this._destroyed)
            return;
        try {
            this._process = this._launch();
            this._process.wait_async(null, (process, result) => {
                try { process.wait_finish(result); } catch (error) {
                    if (!this._destroyed)
                        logError(error, 'Screenshots browser exited');
                }
                if (this._process === process) {
                    this._process = null;
                    if (!this._destroyed && !this._ready) {
                        this._desiredOpen = false;
                        this._stopPlacement();
                    }
                }
            });
        } catch (error) {
            this._process = null;
            this._desiredOpen = false;
            logError(error, 'Could not start screenshots browser');
        }
    }

    _send(method) {
        if (method === 'Hide' || method === 'Quit') {
            const actor = this._window()?.get_compositor_private();
            if (actor)
                Main.wm.skipNextEffect(actor);
        }
        Gio.DBus.session.call(BUS, PATH, BUS, method, null, null,
            Gio.DBusCallFlags.NONE, 3000, null, (connection, result) => {
                try { connection.call_finish(result); } catch (error) {
                    if (!this._destroyed)
                        logError(error, `Screenshots ${method} failed`);
                }
            });
    }

    _window() {
        return global.display.list_all_windows().find(window => window.get_title() === TITLE);
    }

    layout() {
        this._button.set_style(`background-color: ${this._getAccent()};`);
        let saved = {};
        try {
            const [, data] = GLib.file_get_contents(this._configPath);
            saved = JSON.parse(new TextDecoder().decode(data));
        } catch (_) { /* Use defaults until Settings saves a position. */ }
        this._side = saved.side === 'right' ? 'right' : 'left';
        this._alignment = ['top', 'bottom'].includes(saved.alignment) ? saved.alignment : 'center';
        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;
        const geometry = edgeGeometry(monitor, this._side, this._alignment);
        this._button.set_position(geometry.x, geometry.y);
        this._button.set_size(geometry.width, geometry.height);
        const window = this._window();
        if (window && this._desiredOpen)
            this._place(window);
    }

    toggle() {
        if (this._destroyed)
            return;
        if (this._desiredOpen) {
            this.hide();
            return;
        }
        this._desiredOpen = true;
        this._generation++;
        this._ensureProcess();
        if (this._ready)
            this._show();
    }

    _stopPlacement() {
        if (this._placementId)
            GLib.source_remove(this._placementId);
        this._placementId = 0;
    }

    _show() {
        this._stopPlacement();
        this._focusedOnce = false;
        this._send('Show');
        const generation = this._generation;
        let attempts = 0;
        this._placementId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 16, () => {
            if (this._destroyed || !this._desiredOpen || generation !== this._generation) {
                this._placementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            const window = this._window();
            if (window?.get_compositor_private()?.mapped) {
                this._place(window);
                this._expand(window);
                Main.activateWindow(window);
                this._placementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            if (++attempts >= 125) {
                this._desiredOpen = false;
                this._send('Hide');
                this._placementId = 0;
                return GLib.SOURCE_REMOVE;
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    hide() {
        this._desiredOpen = false;
        const generation = ++this._generation;
        this._stopPlacement();
        const origin = this._animationOrigin(this._window());
        if (!origin) {
            if (this._ready)
                this._send('Hide');
            return;
        }
        origin.actor.remove_all_transitions();
        origin.actor.ease({scale_x: origin.scaleX, scale_y: origin.scaleY, duration: 100,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD, onComplete: () => {
                if (!this._destroyed && !this._desiredOpen && generation === this._generation)
                    this._send('Hide');
            }});
    }

    _place(window) {
        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;
        const area = Main.layoutManager.getWorkAreaForMonitor(monitor.index);
        const frame = window.get_frame_rect();
        const width = Math.min(frame.width, area.width - 24);
        const height = Math.min(frame.height, area.height - 24);
        const x = this._side === 'right' ? monitor.x + monitor.width - width : monitor.x;
        const handle = edgeGeometry(monitor, this._side, this._alignment);
        const y = Math.max(area.y + 12, Math.min(area.y + area.height - height - 12,
            Math.round(handle.y + handle.height / 2 - height / 2)));
        window.move_resize_frame(false, x, y, width, height);
    }

    _animationOrigin(window) {
        const actor = window?.get_compositor_private();
        const monitor = Main.layoutManager.primaryMonitor;
        if (!actor || !monitor)
            return null;
        const frame = window.get_frame_rect();
        const handle = edgeGeometry(monitor, this._side, this._alignment);
        actor.set_pivot_point(this._side === 'right' ? 1 : 0,
            Math.max(0, Math.min(1, (handle.y + handle.height / 2 - frame.y) / frame.height)));
        return {actor, scaleX: handle.width / frame.width, scaleY: handle.height / frame.height};
    }

    _expand(window) {
        const origin = this._animationOrigin(window);
        if (!origin)
            return;
        origin.actor.remove_all_transitions();
        // QML can also hide directly on Escape. Reserve the next native
        // effect for this actor so GNOME never animates its unmap a second time.
        Main.wm.skipNextEffect(origin.actor);
        origin.actor.scale_x = origin.scaleX;
        origin.actor.scale_y = origin.scaleY;
        origin.actor.ease({scale_x: 1, scale_y: 1, duration: 140,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD});
    }

    destroy() {
        this._destroyed = true;
        this._generation++;
        this._stopPlacement();
        Gio.bus_unwatch_name(this._watchId);
        Gio.DBus.session.signal_unsubscribe(this._dismissId);
        global.stage.disconnect(this._stageId);
        global.display.disconnect(this._focusId);
        this._monitor.cancel();
        Main.layoutManager.removeChrome(this._button);
        this._button.destroy();
        if (this._ready)
            this._send('Quit');
        else
            this._process?.force_exit();
    }
}
