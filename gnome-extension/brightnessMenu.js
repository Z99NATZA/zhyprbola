import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Slider from 'resource:///org/gnome/shell/ui/slider.js';
import {DdcBrightness} from './ddcBrightness.js';

export class BrightnessMenu extends PopupMenu.PopupMenu {
    constructor(sourceActor, side, accent) {
        super(sourceActor, 0.5, side);
        this.actor.add_style_class_name('zhyprbola-sound-menu');
        this.actor.add_style_class_name('zhyprbola-brightness-menu');
        this.box.set_style(`background-color: #fafcfd; color: ${accent};`);
        this._manager = Main.brightnessManager;
        this._scale = null;
        this._ddc = null;
        this._syncing = false;
        this._dragging = false;

        this._row = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        this._row.add_style_class_name('zhyprbola-sound-row');
        this._icon = new St.Bin({
            child: new St.Icon({icon_name: 'display-brightness-symbolic', icon_size: 20}),
            style_class: 'zhyprbola-sound-mute',
            y_align: Clutter.ActorAlign.CENTER,
            style: `color: ${accent};`,
        });
        this._slider = new Slider.Slider(0);
        this._slider.accessible_name = 'Screen brightness';
        this._slider.y_align = Clutter.ActorAlign.CENTER;
        const rgb = [1, 3, 5].map(offset => parseInt(accent.slice(offset, offset + 2), 16));
        this._slider.set_style(`color: ${accent}; -barlevel-active-background-color: ${accent}; ` +
            `-barlevel-background-color: rgba(${rgb.join(', ')}, 0.25);`);
        this._row.add_child(this._icon);
        this._row.add_child(this._slider);
        this.addMenuItem(this._row);

        this._slider.connect('notify::value', () => {
            if (this._syncing)
                return;
            const value = Math.max(0, Math.min(1, this._slider.value));
            if (this._scale)
                this._scale.value = value;
            else
                this._ddc?.setValue(value);
        });
        this._slider.connect('drag-begin', () => { this._dragging = true; });
        this._slider.connect('drag-end', () => {
            this._dragging = false;
            this._syncValue();
        });
        this._manager.connectObject('changed', () => this._syncScale(), this.actor);
        this.connect('open-state-changed', (_menu, isOpen) => {
            if (isOpen && !this._scale)
                this._ddc?.refresh();
        });
        this._syncScale();
    }

    _syncScale() {
        const scale = this._manager.globalScale;
        if (this._scale !== scale) {
            this._scale?.disconnectObject(this.actor);
            this._scale = scale;
            this._dragging = false;
            scale?.connectObject('notify::value', () => this._syncValue(), this.actor);
        }
        if (scale) {
            this._ddc?.destroy();
            this._ddc = null;
        } else if (!this._ddc) {
            this._ddc = new DdcBrightness(() => {
                this._syncAvailability();
                this._syncValue();
            });
            this._ddc.refresh();
        } else {
            this._ddc.refresh(true);
        }
        this._syncAvailability();
        this._syncValue();
    }

    _syncAvailability() {
        const available = !!this._scale || !!this._ddc?.available;
        this._slider.reactive = available;
        this._slider.can_focus = available;
        this._slider.accessible_name = available
            ? 'Screen brightness' : this._ddc?.error
                ? `Screen brightness unavailable: ${this._ddc.error}`
                : 'Screen brightness unavailable';
        this._row.opacity = available ? 255 : 100;
    }

    _syncValue() {
        if (this._dragging)
            return;
        this._syncing = true;
        this._slider.value = this._scale?.value ?? this._ddc?.value ?? 0;
        this._syncing = false;
    }

    destroy() {
        this._ddc?.destroy();
        this._scale?.disconnectObject(this.actor);
        super.destroy();
    }
}
