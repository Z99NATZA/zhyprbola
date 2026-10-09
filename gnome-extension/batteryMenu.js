import Gio from 'gi://Gio';
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
    <property name="IconName" type="s" access="read"/>
  </interface>
</node>`);

export class BatteryMenu extends PopupMenu.PopupMenu {
    constructor(sourceActor, side, accent) {
        super(sourceActor, 0.5, side);
        this.actor.add_style_class_name('zhyprbola-battery-menu');
        this.box.set_style(`background-color: #fafcfd; color: ${accent};`);
        this._destroyed = false;
        this.actor.connect('destroy', () => { this._destroyed = true; });

        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        item.add_style_class_name('zhyprbola-battery-row');
        this._icon = new St.Icon({
            icon_name: 'battery-missing-symbolic',
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

        this._proxy = new UPowerDeviceProxy(
            Gio.DBus.system, UPOWER_BUS_NAME, UPOWER_DISPLAY_DEVICE,
            (proxy, error) => {
                if (this._destroyed)
                    return;
                if (error) {
                    this._title.text = 'Battery unavailable';
                    this._detail.text = 'UPower is not available';
                    return;
                }
                this._proxy = proxy;
                proxy.connectObject('g-properties-changed', () => this._sync(), this.actor);
                this._sync();
            });
    }

    _formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return '';
        const minutes = Math.round(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const remainder = minutes % 60;
        if (hours === 0)
            return `${remainder} min`;
        return remainder === 0 ? `${hours} hr` : `${hours} hr ${remainder} min`;
    }

    _sync() {
        const proxy = this._proxy;
        if (!proxy?.IsPresent) {
            this._icon.icon_name = 'battery-missing-symbolic';
            this._title.text = 'No battery';
            this._detail.text = 'Battery not detected';
            return;
        }

        const percentage = Math.max(0, Math.min(100, Math.round(proxy.Percentage ?? 0)));
        const duration = this._formatDuration(proxy.State === 1
            ? Number(proxy.TimeToFull) : proxy.State === 2
                ? Number(proxy.TimeToEmpty) : 0);
        const status = {
            1: 'Charging',
            2: 'Discharging',
            3: 'Empty',
            4: 'Fully charged',
            5: 'Waiting to charge',
            6: 'Waiting to discharge',
        }[proxy.State] ?? 'Battery';
        const suffix = duration ? proxy.State === 1
            ? `${duration} until full` : `${duration} remaining` : '';
        this._icon.icon_name = proxy.IconName || 'battery-symbolic';
        this._title.text = `${percentage}%`;
        this._detail.text = suffix ? `${status} · ${suffix}` : status;
    }
}
