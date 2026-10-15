import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const TITLE = 'Zhyprbola Screenshots';
const SHARED_HANDLE_GAP = 8;

export function edgeGeometry(monitor, side, alignment, settings = {}) {
    const thickness = {sm: 5, md: 8, lg: 12}[settings.width] ?? 5;
    const length = {sm: 50, md: 75, lg: 100}[settings.height] ?? 100;
    const vertical = side === 'left' || side === 'right';
    const width = vertical ? thickness : length;
    const height = vertical ? length : thickness;
    const slot = alignment === 'top' ? 0 : alignment === 'bottom' ? 2 : 1;
    return {
        x: vertical ? (side === 'right' ? monitor.x + monitor.width - width : monitor.x)
            : monitor.x + Math.round(monitor.width * (slot + 0.5) / 3 - width / 2),
        y: vertical ? monitor.y + Math.round(monitor.height * (slot + 0.5) / 3 - height / 2)
            : (side === 'bottom' ? monitor.y + monitor.height - height : monitor.y),
        width, height,
    };
}

function insetFromDock(geometry, side, dockPosition, dockThickness) {
    if (side !== dockPosition)
        return geometry;
    if (side === 'left') geometry.x += dockThickness;
    else if (side === 'right') geometry.x -= dockThickness;
    else if (side === 'top') geometry.y += dockThickness;
    else geometry.y -= dockThickness;
    return geometry;
}

function clampGeometry(geometry, monitor) {
    geometry.x = Math.max(monitor.x, Math.min(geometry.x,
        monitor.x + monitor.width - geometry.width));
    geometry.y = Math.max(monitor.y, Math.min(geometry.y,
        monitor.y + monitor.height - geometry.height));
    return geometry;
}

export function edgeHandleGeometries(monitor, screenshots = {}, settings = {},
    dockPosition = 'bottom', dockThickness = 27) {
    const screenshotSide = ['left', 'right', 'top', 'bottom'].includes(screenshots.side)
        ? screenshots.side : 'left';
    const alignments = ['top', 'center', 'bottom'];
    const screenshotAlignment = alignments.includes(screenshots.alignment)
        ? screenshots.alignment : 'center';
    const desktopSide = ['left', 'right', 'top', 'bottom'].includes(settings.position)
        ? settings.position : screenshotSide;
    const desktopAlignment = alignments.includes(settings.alignment)
        ? settings.alignment : screenshotAlignment;
    const desktopWidth = {sm: 5, md: 8, lg: 12}[settings.width] ?? 5;
    const desktopHeight = {sm: 50, md: 75, lg: 100}[settings.height] ?? 50;
    const desktopVertical = desktopSide === 'left' || desktopSide === 'right';
    const desktopActorWidth = desktopVertical ? desktopWidth : desktopHeight;
    const desktopActorHeight = desktopVertical ? desktopHeight : desktopWidth;
    const screenshot = edgeGeometry(monitor, screenshotSide, screenshotAlignment, screenshots);
    const desktopSlot = desktopAlignment === 'top' ? 0
        : desktopAlignment === 'bottom' ? 2 : 1;
    const showDesktop = {
        x: desktopVertical
            ? (desktopSide === 'right'
                ? monitor.x + monitor.width - desktopActorWidth : monitor.x)
            : monitor.x + Math.round(
                monitor.width * (desktopSlot + 0.5) / 3 - desktopActorWidth / 2),
        y: desktopVertical
            ? monitor.y + Math.round(
                monitor.height * (desktopSlot + 0.5) / 3 - desktopActorHeight / 2)
            : (desktopSide === 'bottom'
                ? monitor.y + monitor.height - desktopActorHeight : monitor.y),
        width: desktopActorWidth,
        height: desktopActorHeight,
    };

    if (desktopSide === screenshotSide && desktopAlignment === screenshotAlignment) {
        const screenshotsFirst = settings.order !== 'show-desktop-first';
        const first = screenshotsFirst ? screenshot : showDesktop;
        const second = screenshotsFirst ? showDesktop : screenshot;
        const axis = desktopVertical ? 'y' : 'x';
        const size = desktopVertical ? 'height' : 'width';
        const segmentStart = monitor[axis] + monitor[size] * desktopSlot / 3;
        const segmentLength = monitor[size] / 3;
        const groupLength = first[size] + SHARED_HANDLE_GAP + second[size];
        first[axis] = Math.round(segmentStart + (segmentLength - groupLength) / 2);
        second[axis] = first[axis] + first[size] + SHARED_HANDLE_GAP;
    }

    insetFromDock(screenshot, screenshotSide, dockPosition, dockThickness);
    insetFromDock(showDesktop, desktopSide, dockPosition, dockThickness);
    return {
        screenshots: clampGeometry(screenshot, monitor),
        showDesktop: clampGeometry(showDesktop, monitor),
    };
}

export function showDesktopEdgeGeometry(monitor, settings = {}, screenshots = {},
    dockPosition = 'bottom', dockThickness = 27) {
    return edgeHandleGeometries(monitor, screenshots, settings,
        dockPosition, dockThickness).showDesktop;
}

export class ShowDesktopEdge {
    constructor(toggle, getAccent = () => '#875a82', getDockPosition = () => 'bottom',
        getDockThickness = () => 27) {
        this._toggle = toggle;
        this._getAccent = getAccent;
        this._getDockPosition = getDockPosition;
        this._getDockThickness = getDockThickness;
        this._checked = false;
        this._configDir = GLib.build_filenamev([GLib.get_user_config_dir(), 'zhyprbola']);
        this._configPath = GLib.build_filenamev([this._configDir, 'show-desktop-edge']);
        this._screenshotsConfigPath = GLib.build_filenamev(
            [this._configDir, 'screenshots-edge']);
        this._button = new St.Button({
            style_class: 'zhyprbola-show-desktop-edge',
            reactive: true, can_focus: true, track_hover: true,
            accessible_name: 'Show desktop / Restore windows',
        });
        this._button.connect('clicked', () => this._toggle());
        this._button.connect('notify::hover', () => this._updateOpacity());
        this._updateOpacity();
        Main.layoutManager.addTopChrome(this._button,
            {affectsStruts: false, trackFullscreen: false});
        GLib.mkdir_with_parents(this._configDir, 0o700);
        this._monitor = Gio.File.new_for_path(this._configDir)
            .monitor_directory(Gio.FileMonitorFlags.NONE, null);
        this._monitor.connect('changed', (_monitor, file, other) => {
            const names = [file?.get_basename(), other?.get_basename()];
            if (names.includes('screenshots-edge') || names.includes('show-desktop-edge'))
                this.layout();
        });
        this.layout();
    }

    _updateOpacity() {
        this._button.opacity = this._button.hover ? 255 : this._checked ? 225 : 190;
    }

    setChecked(checked) {
        this._checked = checked;
        this._updateOpacity();
    }

    layout() {
        this._button.set_style(`background-color: ${this._getAccent()};`);
        let screenshots = {};
        let settings = {};
        try {
            const [, data] = GLib.file_get_contents(this._screenshotsConfigPath);
            screenshots = JSON.parse(new TextDecoder().decode(data));
        } catch (_) { /* Follow the Screenshots handle defaults. */ }
        try {
            const [, data] = GLib.file_get_contents(this._configPath);
            settings = JSON.parse(new TextDecoder().decode(data));
        } catch (_) { /* Use the Screenshots side and the smallest size. */ }
        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;
        const geometry = showDesktopEdgeGeometry(monitor, settings, screenshots,
            this._getDockPosition(), this._getDockThickness());
        this._button.set_position(geometry.x, geometry.y);
        this._button.set_size(geometry.width, geometry.height);
    }

    destroy() {
        this._monitor.cancel();
        Main.layoutManager.removeChrome(this._button);
        this._button.destroy();
    }
}

const BUS = 'org.zhyprbola.Screenshots';
const PATH = '/org/zhyprbola/Screenshots';

export class ScreenshotEdge {
    constructor(launch, getAccent = () => '#875a82', getDockPosition = () => 'bottom',
        getDockThickness = () => 27) {
        this._launch = launch;
        this._getAccent = getAccent;
        this._getDockPosition = getDockPosition;
        this._getDockThickness = getDockThickness;
        this._placementId = 0;
        this._generation = 0;
        this._desiredOpen = false;
        this._ready = false;
        this._destroyed = false;
        this._process = null;
        this._configDir = GLib.build_filenamev([GLib.get_user_config_dir(), 'zhyprbola']);
        this._configPath = GLib.build_filenamev([this._configDir, 'screenshots-edge']);
        this._showDesktopConfigPath = GLib.build_filenamev(
            [this._configDir, 'show-desktop-edge']);
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
            const handle = monitor && this._handleGeometry;
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
            const names = [file?.get_basename(), other?.get_basename()];
            if (names.includes('screenshots-edge') || names.includes('show-desktop-edge'))
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
        let showDesktop = {};
        try {
            const [, data] = GLib.file_get_contents(this._configPath);
            saved = JSON.parse(new TextDecoder().decode(data));
        } catch (_) { /* Use defaults until Settings saves a position. */ }
        try {
            const [, data] = GLib.file_get_contents(this._showDesktopConfigPath);
            showDesktop = JSON.parse(new TextDecoder().decode(data));
        } catch (_) { /* Use the default shared center slot. */ }
        this._side = ['left', 'right', 'top', 'bottom'].includes(saved.side)
            ? saved.side : 'left';
        this._alignment = ['top', 'bottom'].includes(saved.alignment) ? saved.alignment : 'center';
        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;
        const geometry = edgeHandleGeometries(monitor, saved, showDesktop,
            this._getDockPosition(), this._getDockThickness()).screenshots;
        this._handleGeometry = geometry;
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
        const vertical = this._side === 'left' || this._side === 'right';
        const handle = this._handleGeometry ?? edgeGeometry(
            monitor, this._side, this._alignment);
        const x = vertical
            ? (this._side === 'right' ? area.x + area.width - width : area.x)
            : Math.max(area.x + 12, Math.min(area.x + area.width - width - 12,
                Math.round(handle.x + handle.width / 2 - width / 2)));
        const y = vertical
            ? Math.max(area.y + 12, Math.min(area.y + area.height - height - 12,
                Math.round(handle.y + handle.height / 2 - height / 2)))
            : (this._side === 'bottom' ? area.y + area.height - height - 12 : area.y + 12);
        window.move_resize_frame(false, x, y, width, height);
    }

    _animationOrigin(window) {
        const actor = window?.get_compositor_private();
        const monitor = Main.layoutManager.primaryMonitor;
        if (!actor || !monitor)
            return null;
        const frame = window.get_frame_rect();
        const handle = this._handleGeometry ?? edgeGeometry(
            monitor, this._side, this._alignment);
        const vertical = this._side === 'left' || this._side === 'right';
        actor.set_pivot_point(vertical ? (this._side === 'right' ? 1 : 0)
            : Math.max(0, Math.min(1, (handle.x + handle.width / 2 - frame.x) / frame.width)),
        vertical
            ? Math.max(0, Math.min(1, (handle.y + handle.height / 2 - frame.y) / frame.height))
            : (this._side === 'bottom' ? 1 : 0));
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
