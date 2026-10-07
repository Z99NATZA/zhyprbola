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

class Scale extends Actor {
    constructor(value) { super(); this._value = value; this.writes = 0; }
    get value() { return this._value; }
    set value(value) { this._value = value; this.writes++; this.emit('notify::value'); }
}

function fixture(scale = new Scale(0.5)) {
    const manager = new Actor({globalScale: scale});
    const context = vm.createContext({
        Clutter: {ActorAlign: {CENTER: 0}}, St: {Icon: Actor, Bin: Actor},
        PopupMenu: {PopupMenu: Popup, PopupBaseMenuItem: Actor, PopupMenuItem: Actor},
        Slider: {Slider}, Main: {brightnessManager: manager},
    });
    const source = readFileSync(new URL('../gnome-extension/brightnessMenu.js', import.meta.url), 'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export class BrightnessMenu', 'globalThis.BrightnessMenu = class BrightnessMenu'), context);
    const menu = new context.BrightnessMenu(new Actor(), 0, '#c45478');
    return {menu, manager, scale};
}

test('initialization reads brightness without writing and controls adjust the shared scale', () => {
    const {menu, scale} = fixture();
    assert.equal(menu._slider.value, 0.5);
    assert.equal(scale.writes, 0);
    menu._slider.value = 0.7;
    assert.equal(scale.value, 0.7);
    menu._slider.value = 1.2;
    assert.equal(scale.value, 1);
    menu._slider.value = -0.2;
    assert.equal(scale.value, 0);
});

test('external changes sync without feedback and preserve the handle while dragging', () => {
    const {menu, scale} = fixture();
    scale.value = 0.3;
    assert.equal(menu._slider.value, 0.3);
    assert.equal(scale.writes, 1);
    menu._slider.emit('drag-begin');
    scale.value = 0.2;
    assert.equal(menu._slider.value, 0.3);
    menu._slider.emit('drag-end');
    assert.equal(menu._slider.value, 0.2);
    assert.equal(scale.writes, 2);
});

test('unavailable hardware disables controls, hotplug restores them, and removal disconnects', () => {
    const {menu, manager} = fixture(null);
    assert.equal(menu._slider.reactive, false);
    assert.equal(menu._slider.can_focus, false);
    menu._slider.value = 0.4;
    const scale = new Scale(0.8);
    manager.globalScale = scale;
    manager.emit('changed');
    assert.equal(menu._slider.value, 0.8);
    assert.equal(menu._slider.reactive, true);
    assert.equal(menu._slider.can_focus, true);
    manager.globalScale = null;
    manager.emit('changed');
    assert.equal(scale.signals.length, 0);
    assert.equal(menu._slider.reactive, false);
});

test('destroy disconnects listeners without destroying the shared brightness manager', () => {
    const {menu, manager, scale} = fixture();
    manager.destroy = () => assert.fail('shared manager must remain alive');
    menu.destroy();
    assert.equal(manager.signals.length, 0);
    assert.equal(scale.signals.length, 0);
});
