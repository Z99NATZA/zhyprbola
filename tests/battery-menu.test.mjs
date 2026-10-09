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
    add_child(actor) { this.children.push(actor); }
    destroy() { this.emit('destroy'); for (const child of this.children) child.destroy(); }
}

class Popup extends Actor {
    constructor(sourceActor) {
        super();
        this.sourceActor = sourceActor;
        this.actor = new Actor();
        this.box = new Actor();
    }
    addMenuItem(item) { this.box.add_child(item); }
    destroy() { this.actor.destroy(); this.box.destroy(); }
}

function fixture(properties = {}) {
    let proxy;
    class Proxy extends Actor {
        constructor(_bus, _name, _path, callback) {
            super({IsPresent: true, Percentage: 73.4, State: 2,
                TimeToEmpty: 7320, TimeToFull: 0,
                IconName: 'battery-good-symbolic', ...properties});
            proxy = this;
            callback(this, null);
        }
    }
    const context = vm.createContext({
        Gio: {DBus: {system: {}}, DBusProxy: {makeProxyWrapper: () => Proxy}},
        Clutter: {ActorAlign: {CENTER: 0}},
        St: {Icon: Actor, BoxLayout: Actor, Label: Actor},
        PopupMenu: {PopupMenu: Popup, PopupBaseMenuItem: Actor},
    });
    const source = readFileSync(new URL('../gnome-extension/batteryMenu.js', import.meta.url),
        'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export class BatteryMenu', 'globalThis.BatteryMenu = class BatteryMenu'), context);
    const menu = new context.BatteryMenu(new Actor(), 0, '#c45478');
    return {menu, proxy};
}

test('popup shows percentage, discharge state and remaining time from UPower', () => {
    const {menu} = fixture();
    assert.equal(menu._title.text, '73%');
    assert.equal(menu._detail.text, 'Discharging · 2 hr 2 min remaining');
    assert.equal(menu._icon.icon_name, 'battery-good-symbolic');
});

test('charging and fully charged updates refresh the popup', () => {
    const {menu, proxy} = fixture({State: 1, TimeToFull: 3600});
    assert.equal(menu._detail.text, 'Charging · 1 hr until full');
    proxy.Percentage = 100;
    proxy.State = 4;
    proxy.IconName = 'battery-full-charged-symbolic';
    proxy.emit('g-properties-changed');
    assert.equal(menu._title.text, '100%');
    assert.equal(menu._detail.text, 'Fully charged');
    assert.equal(menu._icon.icon_name, 'battery-full-charged-symbolic');
});

test('missing battery is represented without stale charge information', () => {
    const {menu, proxy} = fixture({IsPresent: false});
    assert.equal(menu._title.text, 'No battery');
    assert.equal(menu._detail.text, 'Battery not detected');
    proxy.IsPresent = true;
    proxy.Percentage = 25;
    proxy.emit('g-properties-changed');
    assert.equal(menu._title.text, '25%');
});

test('destroy disconnects UPower updates', () => {
    const {menu, proxy} = fixture();
    menu.destroy();
    assert.equal(proxy.signals.length, 0);
});
