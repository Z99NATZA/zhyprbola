import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

class Actor {
    constructor(props = {}) { Object.assign(this, {signals: [], children: []}, props); }
    connect(name, callback) { this.signals.push({name, callback}); }
    connectObject(...args) {
        const owner = args.pop();
        for (let i = 0; i < args.length; i += 2)
            this.signals.push({name: args[i], callback: args[i + 1], owner});
        owner.connect('destroy', () => this.disconnectObject(owner));
    }
    disconnectObject(owner) { this.signals = this.signals.filter(signal => signal.owner !== owner); }
    emit(name) { for (const signal of [...this.signals]) if (signal.name === name) signal.callback(); }
    set_style(style) { this.style = style; }
    add_style_class_name() {}
    add_style_pseudo_class(name) { this.checked = name === 'checked'; }
    remove_style_pseudo_class() { this.checked = false; }
    add_child(actor) { this.children.push(actor); }
    destroy() { this.emit('destroy'); for (const child of this.children) child.destroy(); }
}

class Stream extends Actor {
    constructor(volume, muted = false) {
        super({volume, is_muted: muted, writes: 0});
    }
    push_volume() { this.writes++; this.emit('notify::volume'); }
    change_is_muted(muted) { this.is_muted = muted; this.emit('notify::is-muted'); }
}

class Slider extends Actor {
    constructor(value) { super(); this.value = value; }
    get value() { return this._value; }
    set value(value) { this._value = value; this.emit('notify::value'); }
}

class Popup extends Actor {
    constructor(sourceActor) { super(); this.sourceActor = sourceActor; this.actor = new Actor(); this.box = new Actor(); }
    addMenuItem(item) { this.box.add_child(item); }
    destroy() { this.actor.destroy(); this.box.destroy(); }
}

function fixture() {
    const control = new Actor({microphone: new Stream(65536), speaker: new Stream(26214)});
    control.get_default_source = () => control.microphone;
    control.get_default_sink = () => control.speaker;
    control.get_vol_max_norm = () => 65536;
    const context = vm.createContext({
        Clutter: {ActorAlign: {CENTER: 0}}, St: {Icon: Actor, Button: Actor},
        PopupMenu: {PopupMenu: Popup, PopupBaseMenuItem: Actor},
        Slider: {Slider}, Volume: {getMixerControl: () => control},
    });
    const source = readFileSync(new URL('../gnome-extension/soundMenu.js', import.meta.url), 'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export class SoundMenu', 'globalThis.SoundMenu = class SoundMenu'), context);
    const menu = new context.SoundMenu(new Actor(), 0, '#c45478');
    return {menu, control, microphone: menu._rows[0], speaker: menu._rows[1]};
}

test('initializing the popup reads both streams without changing volume', () => {
    const {control, microphone, speaker} = fixture();
    assert.equal(microphone.slider.value, 1);
    assert.ok(Math.abs(speaker.slider.value - 0.4) < 0.001);
    assert.equal(control.microphone.writes, 0);
    assert.equal(control.speaker.writes, 0);
});

test('moving each slider adjusts only its stream', () => {
    const {control, microphone, speaker} = fixture();
    microphone.slider.value = 0.3;
    assert.equal(control.microphone.volume, Math.round(65536 * 0.3));
    assert.equal(control.speaker.writes, 0);
    speaker.slider.value = 0.75;
    assert.equal(control.speaker.volume, 49152);
    assert.equal(control.microphone.writes, 1);
});

test('mute buttons preserve volume and update icons independently', () => {
    const {control, microphone, speaker} = fixture();
    microphone.mute.emit('clicked');
    assert.equal(control.microphone.is_muted, true);
    assert.equal(control.microphone.volume, 65536);
    assert.equal(microphone.icon.icon_name, 'microphone-sensitivity-muted-symbolic');
    assert.equal(speaker.icon.icon_name, 'audio-volume-high-symbolic');
    microphone.mute.emit('clicked');
    assert.equal(control.microphone.is_muted, false);
});

test('external volume updates do not write back or move a handle during drag', () => {
    const {control, speaker} = fixture();
    control.speaker.volume = 32768;
    control.speaker.emit('notify::volume');
    assert.equal(speaker.slider.value, 0.5);
    assert.equal(control.speaker.writes, 0);
    speaker.slider.emit('drag-begin');
    control.speaker.volume = 16384;
    control.speaker.emit('notify::volume');
    assert.equal(speaker.slider.value, 0.5);
    speaker.slider.emit('drag-end');
    assert.equal(speaker.slider.value, 0.25);
    assert.equal(control.speaker.writes, 0);
});

test('device removal disables a row and hotplug restores it', () => {
    const {control, microphone, speaker} = fixture();
    control.microphone = null;
    control.emit('default-source-changed');
    assert.equal(microphone.slider.reactive, false);
    assert.equal(microphone.mute.reactive, false);
    assert.equal(speaker.slider.reactive, true);
    control.microphone = new Stream(32768);
    control.emit('stream-added');
    assert.equal(microphone.slider.reactive, true);
    assert.equal(microphone.slider.value, 0.5);
});

test('changing the default device disconnects the previous stream', () => {
    const {control, microphone} = fixture();
    const previous = control.microphone;
    control.microphone = new Stream(32768);
    control.emit('default-source-changed');
    previous.volume = 0;
    previous.emit('notify::volume');
    assert.equal(microphone.slider.value, 0.5);
    assert.equal(previous.signals.length, 0);
});

test('destroying the popup disconnects all listeners without closing the shared mixer', () => {
    const {menu, control} = fixture();
    control.close = () => assert.fail('shared mixer must remain open');
    menu.destroy();
    assert.equal(control.signals.length, 0);
    assert.equal(control.microphone.signals.length, 0);
    assert.equal(control.speaker.signals.length, 0);
});
