import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Slider from 'resource:///org/gnome/shell/ui/slider.js';
import * as Volume from 'resource:///org/gnome/shell/ui/status/volume.js';

export class SoundMenu extends PopupMenu.PopupMenu {
    constructor(sourceActor, side, accent) {
        super(sourceActor, 0.5, side);
        this.actor.add_style_class_name('zhyprbola-sound-menu');
        this.box.set_style(`background-color: #fafcfd; color: ${accent};`);
        this._control = Volume.getMixerControl();
        this._rows = [this._createRow('microphone', accent), this._createRow('speaker', accent)];
        this._control.connectObject(
            'state-changed', () => this._syncStreams(),
            'default-source-changed', () => this._syncStreams(),
            'default-sink-changed', () => this._syncStreams(),
            'stream-added', () => this._syncStreams(),
            'stream-removed', () => this._syncStreams(), this.actor);
        this._syncStreams();
    }

    _createRow(channel, accent) {
        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        item.add_style_class_name('zhyprbola-sound-row');
        const icon = new St.Icon({icon_size: 20});
        const mute = new St.Button({
            child: icon,
            style_class: 'zhyprbola-sound-mute',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
            style: `color: ${accent};`,
        });
        const slider = new Slider.Slider(0);
        slider.accessible_name = channel === 'microphone' ? 'Microphone volume' : 'Speaker volume';
        slider.y_align = Clutter.ActorAlign.CENTER;
        const rgb = [1, 3, 5].map(offset => parseInt(accent.slice(offset, offset + 2), 16));
        slider.set_style(`color: ${accent}; -barlevel-active-background-color: ${accent}; ` +
            `-barlevel-background-color: rgba(${rgb.join(', ')}, 0.25);`);
        item.add_child(mute);
        item.add_child(slider);
        this.addMenuItem(item);
        const row = {channel, item, icon, mute, slider, stream: null, syncing: false, dragging: false};
        mute.connect('clicked', () => {
            if (row.stream)
                row.stream.change_is_muted(!row.stream.is_muted);
        });
        slider.connect('notify::value', () => {
            if (row.syncing || !row.stream)
                return;
            row.stream.volume = Math.round(Math.max(0, Math.min(1, slider.value))
                * this._control.get_vol_max_norm());
            row.stream.push_volume();
        });
        slider.connect('drag-begin', () => { row.dragging = true; });
        slider.connect('drag-end', () => {
            row.dragging = false;
            this._syncRow(row);
        });
        return row;
    }

    _syncStreams() {
        for (const row of this._rows) {
            const stream = row.channel === 'microphone'
                ? this._control.get_default_source() : this._control.get_default_sink();
            if (row.stream !== stream) {
                row.stream?.disconnectObject(row.item);
                row.stream = stream;
                stream?.connectObject(
                    'notify::volume', () => this._syncRow(row),
                    'notify::is-muted', () => this._syncRow(row), row.item);
            }
            this._syncRow(row);
        }
    }

    _syncRow(row) {
        const available = !!row.stream;
        const muted = row.stream?.is_muted ?? false;
        row.mute.reactive = available;
        row.mute.can_focus = available;
        row.slider.reactive = available;
        row.slider.can_focus = available;
        row.item.opacity = available ? 255 : 100;
        row.mute.accessible_name = `${muted ? 'Unmute' : 'Mute'} ${row.channel}`;
        row.icon.icon_name = row.channel === 'microphone'
            ? muted ? 'microphone-sensitivity-muted-symbolic' : 'audio-input-microphone-symbolic'
            : muted ? 'audio-volume-muted-symbolic' : 'audio-volume-high-symbolic';
        if (muted)
            row.mute.add_style_pseudo_class('checked');
        else
            row.mute.remove_style_pseudo_class('checked');
        if (!row.dragging) {
            row.syncing = true;
            row.slider.value = available ? Math.max(0, Math.min(1,
                row.stream.volume / this._control.get_vol_max_norm())) : 0;
            row.syncing = false;
        }
    }

    destroy() {
        for (const row of this._rows)
            row.stream?.disconnectObject(row.item);
        super.destroy();
    }
}
