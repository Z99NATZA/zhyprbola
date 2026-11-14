import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const UPOWER_BUS_NAME = 'org.freedesktop.UPower';
const UPOWER_DISPLAY_DEVICE = '/org/freedesktop/UPower/devices/DisplayDevice';
const UPowerDeviceProxy = Gio.DBusProxy.makeProxyWrapper(`
<node>
  <interface name="org.freedesktop.UPower.Device">
    <property name="IsPresent" type="b" access="read"/>
    <property name="Percentage" type="d" access="read"/>
    <property name="State" type="u" access="read"/>
    <property name="TimeToEmpty" type="x" access="read"/>
    <property name="TimeToFull" type="x" access="read"/>
  </interface>
</node>`);

// Keep the small dock icon and the detailed popup on the same interpretation
// of UPower's states. Unknown charge must never look like an empty battery.
function batteryInfo(proxy) {
    if (!proxy || proxy.g_name_owner === null)
        return {percentage: null, status: 'Battery unavailable', detail: 'UPower is not available',
            state: 0, present: false};
    if (!proxy.IsPresent)
        return {percentage: null, status: 'No battery', detail: 'Battery not detected',
            state: 0, present: false};
    const percentage = Number.isFinite(proxy.Percentage)
        ? Math.max(0, Math.min(100, Math.round(proxy.Percentage))) : null;
    const status = {
        1: 'Charging',
        2: 'Discharging',
        3: 'Empty',
        4: 'Fully charged',
        5: 'Waiting to charge',
        6: 'Waiting to discharge',
    }[proxy.State] ?? 'Status unknown';
    const seconds = Number(proxy.State === 1 ? proxy.TimeToFull
        : proxy.State === 2 ? proxy.TimeToEmpty : 0);
    let duration = '';
    if (Number.isFinite(seconds) && seconds > 0) {
        const minutes = Math.max(1, Math.round(seconds / 60));
        const hours = Math.floor(minutes / 60);
        const remainder = minutes % 60;
        duration = hours === 0 ? `${remainder} min`
            : remainder === 0 ? `${hours} hr` : `${hours} hr ${remainder} min`;
    }
    const suffix = duration ? proxy.State === 1
        ? `${duration} until full` : `${duration} remaining` : '';
    return {percentage, status, detail: suffix ? `${status} · ${suffix}` : status,
        state: proxy.State, present: true};
}

function batterySvg(info, foreground, lightBackground = false) {
    const {percentage, state, present} = info;
    // Dock/Quick use white artwork over the theme color. Popup/overflow use
    // the theme accent over a light surface, which needs darker status colors.
    const palette = lightBackground
        ? {charging: '#18794e', critical: '#c43131', low: '#9a5700'}
        : {charging: '#70e0a0', critical: '#ff6b6b', low: '#ffb454'};
    const color = !present ? foreground : state === 1 || state === 4 ? palette.charging
        : percentage !== null && percentage <= 10 ? palette.critical
        : percentage !== null && percentage <= 20 ? palette.low : foreground;
    // A transparent gap keeps the status glyph legible at every fill level.
    const glyph = !present ? '<path d="m9 9 6 6m0-6-6 6"/>'
        : state === 1 ? '<path d="m13 3-6 10h5l-1 8 7-12h-5z" fill="COLOR"/>'
        : state === 4 ? '<path d="m7 12 3 3 6-6"/>'
        : state === 5 ? '<path d="M9 9v6m5-6v6"/>'
        : percentage === null || ![1, 2, 3, 4, 5, 6].includes(state)
            ? '<path d="M9 9a3 3 0 0 1 6 0c0 2-3 2-3 4m0 3v.1"/>' : '';
    const width = percentage === null ? 0 : 16 * percentage / 100;
    return `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
        <defs><mask id="charge"><rect width="24" height="24" fill="white"/>
        <g fill="none" stroke="black" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">${glyph.replaceAll('COLOR', 'black')}</g></mask></defs>
        <g fill="none" stroke="${color}" stroke-width="2" stroke-linejoin="round" mask="url(#charge)">
        <rect x="1" y="6" width="20" height="12" rx="2"/><path d="M23 10v4"/>
        <rect x="3" y="8" width="16" height="8" rx="1" fill="${color}" opacity=".18" stroke="none"/>
        <rect x="3" y="8" width="${width}" height="8" rx="1" fill="${color}" stroke="none"/></g>
        <g fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${glyph.replaceAll('COLOR', color)}</g></svg>`;
}

export class BatteryIndicator {
    constructor(icon, sourceActor = null, foreground = '#ffffff', onChange = null,
        lightBackground = false) {
        this._icon = icon;
        this._sourceActor = sourceActor;
        this._foreground = foreground;
        this._lightBackground = lightBackground;
        this._onChange = onChange;
        this._destroyed = false;
        this._cancellable = new Gio.Cancellable();
        icon.add_style_class_name('zhyprbola-battery-indicator');
        icon.connect('destroy', () => {
            this._destroyed = true;
            this._cancellable.cancel();
        });
        this._sync(null);
        this._proxy = new UPowerDeviceProxy(
            Gio.DBus.system, UPOWER_BUS_NAME, UPOWER_DISPLAY_DEVICE,
            (proxy, error) => {
                if (this._destroyed)
                    return;
                if (error) {
                    this._sync(null);
                    return;
                }
                proxy.connectObject('g-properties-changed', () => this._sync(proxy),
                    'notify::g-name-owner', () => this._sync(proxy), icon);
                this._sync(proxy);
            }, this._cancellable);
    }

    _sync(proxy) {
        const info = batteryInfo(proxy);
        const svg = batterySvg(info, this._foreground, this._lightBackground);
        if (svg !== this._lastSvg) {
            this._lastSvg = svg;
            this._icon.gicon = Gio.BytesIcon.new(new GLib.Bytes(new TextEncoder().encode(svg)));
        }
        if (this._sourceActor)
            this._sourceActor.accessible_name = info.present
                ? `Battery: ${info.percentage === null ? 'Charge unknown' : `${info.percentage}%`}, ${info.detail}`
                : info.status;
        this._onChange?.(info);
    }
}

export class BatteryMenu extends PopupMenu.PopupMenu {
    constructor(sourceActor, side, accent, surface = '#fafcfd') {
        super(sourceActor, 0.5, side);
        this.actor.add_style_class_name('zhyprbola-battery-menu');
        this.box.set_style(`background-color: ${surface}; color: ${accent};`);

        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        item.add_style_class_name('zhyprbola-battery-row');
        this._icon = new St.Icon({
            style_class: 'zhyprbola-battery-icon',
            y_align: Clutter.ActorAlign.CENTER,
        });
        const text = new St.BoxLayout({
            vertical: true,
            style_class: 'zhyprbola-battery-text',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._title = new St.Label({
            text: 'Battery unavailable',
            style_class: 'zhyprbola-battery-title',
        });
        this._detail = new St.Label({
            text: 'Waiting for UPower',
            style_class: 'zhyprbola-battery-detail',
        });
        text.add_child(this._title);
        text.add_child(this._detail);
        item.add_child(this._icon);
        item.add_child(text);
        this.addMenuItem(item);

        this._indicator = new BatteryIndicator(this._icon, null, accent, info => {
            this._title.text = info.present
                ? info.percentage === null ? 'Charge unknown' : `${info.percentage}%`
                : info.status;
            this._detail.text = info.detail;
        }, true);
    }
}
