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

function fixture(properties = {}, options = {}) {
    let complete;
    let proxy;
    class Proxy extends Actor {
        constructor(_bus, _name, _path, callback) {
            super({IsPresent: true, Percentage: 73.4, State: 2,
                TimeToEmpty: 7320, TimeToFull: 0,
                IconName: 'battery-good-symbolic', ...properties});
            proxy = this;
            complete = () => callback(this, options.error ? Error('unavailable') : null);
            if (!options.deferred) complete();
        }
    }
    const context = vm.createContext({
        Gio: {DBus: {system: {}}, DBusProxy: {makeProxyWrapper: () => Proxy},
            Cancellable: class { cancel() { this.cancelled = true; } },
            BytesIcon: {new: bytes => ({svg: new TextDecoder().decode(bytes.data)})}},
        GLib: {Bytes: class { constructor(data) { this.data = data; } }},
        TextEncoder,
        Clutter: {ActorAlign: {CENTER: 0}},
        St: {Icon: Actor, BoxLayout: Actor, Label: Actor},
        PopupMenu: {PopupMenu: Popup, PopupBaseMenuItem: Actor},
    });
    const source = readFileSync(new URL('../gnome-extension/batteryMenu.js', import.meta.url),
        'utf8');
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace(/export class (\w+)/g, 'globalThis.$1 = class $1'), context);
    const icon = new Actor();
    const button = new Actor();
    const menu = options.indicator ? null : new context.BatteryMenu(new Actor(), 0, options.foreground ?? '#c45478');
    const indicator = options.indicator ? new context.BatteryIndicator(icon, button) : menu._indicator;
    return {menu, proxy, indicator, icon: options.indicator ? icon : menu._icon, button,
        complete: () => complete()};
}

test('popup shows percentage, discharge state and remaining time from UPower', () => {
    const {menu} = fixture();
    assert.equal(menu._title.text, '73%');
    assert.equal(menu._detail.text, 'Discharging · 2 hr 2 min remaining');
    assert.match(menu._icon.gicon.svg, /width="11.68"/);
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
    assert.match(menu._icon.gicon.svg, /#18794e/);
    assert.match(menu._icon.gicon.svg, /m7 12 3 3 6-6/);
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


test('dock fill tracks charge and warns at low and critical levels', () => {
    const {icon, button, proxy} = fixture({Percentage: 80}, {indicator: true});
    assert.match(icon.gicon.svg, /width="12.8"/);
    assert.match(button.accessible_name, /80%, Discharging/);
    for (const [percentage, color] of [[21, '#ffffff'], [20, '#ffb454'], [10, '#ff6b6b'], [0, '#ff6b6b']]) {
        proxy.Percentage = percentage;
        proxy.emit('g-properties-changed');
        assert.match(icon.gicon.svg, new RegExp(color));
        assert.match(button.accessible_name, new RegExp(`${percentage}%`));
    }
});

test('charging, full, waiting and discharging have distinct artwork and labels', () => {
    const {icon, button, proxy} = fixture({}, {indicator: true});
    const artwork = new Set();
    for (const [state, label] of [[1, 'Charging'], [2, 'Discharging'], [4, 'Fully charged'], [5, 'Waiting to charge']]) {
        proxy.State = state;
        proxy.emit('g-properties-changed');
        artwork.add(icon.gicon.svg);
        assert.ok(button.accessible_name.includes(label));
    }
    assert.equal(artwork.size, 4);
    proxy.State = 6;
    proxy.emit('g-properties-changed');
    assert.match(button.accessible_name, /Waiting to discharge/);
});

test('invalid and out of range charge values never imply a false empty or full battery', () => {
    const {menu, proxy} = fixture();
    for (const value of [undefined, NaN, Infinity]) {
        proxy.Percentage = value;
        proxy.emit('g-properties-changed');
        assert.equal(menu._title.text, 'Charge unknown');
        assert.match(menu._icon.gicon.svg, /M9 9a3/);
    }
    proxy.Percentage = -5;
    proxy.emit('g-properties-changed');
    assert.equal(menu._title.text, '0%');
    proxy.Percentage = 150;
    proxy.emit('g-properties-changed');
    assert.equal(menu._title.text, '100%');
});

test('UPower errors and service loss clear stale information and service return recovers', () => {
    const failed = fixture({}, {error: true});
    assert.equal(failed.menu._title.text, 'Battery unavailable');
    const {menu, proxy} = fixture();
    proxy.g_name_owner = null;
    proxy.emit('notify::g-name-owner');
    assert.equal(menu._title.text, 'Battery unavailable');
    proxy.g_name_owner = ':1.99';
    proxy.emit('notify::g-name-owner');
    assert.equal(menu._title.text, '73%');
});

test('destroy cancels initialization and ignores late replies', () => {
    const {icon, indicator, proxy, complete} = fixture({}, {indicator: true, deferred: true});
    const previous = icon.gicon;
    icon.destroy();
    complete();
    assert.equal(indicator._cancellable.cancelled, true);
    assert.equal(proxy.signals.length, 0);
    assert.equal(icon.gicon, previous);
});

test('time-only changes update the detail without recreating identical icon artwork', () => {
    const {menu, proxy} = fixture();
    const previous = menu._icon.gicon;
    proxy.TimeToEmpty = 60;
    proxy.emit('g-properties-changed');
    assert.equal(menu._detail.text, 'Discharging · 1 min remaining');
    assert.equal(menu._icon.gicon, previous);
});


test('normal popup artwork and text retain the accent of every dock theme', () => {
    const extension = readFileSync(new URL('../gnome-extension/extension.js', import.meta.url), 'utf8');
    const themeColors = [...extension.matchAll(/iconColor: '(#[0-9a-f]{6})'/g)].map(match => match[1]);
    assert.equal(themeColors.length, 8);
    for (const foreground of themeColors) {
        const {menu} = fixture({Percentage: 80, State: 2}, {foreground});
        assert.ok(menu._icon.gicon.svg.includes(`stroke="${foreground}"`));
        assert.ok(menu.box.style.includes(`color: ${foreground}`));
    }
});

test('status colors stay readable on light popup surfaces and distinct on Dock and Quick', () => {
    const light = fixture();
    const dock = fixture({}, {indicator: true});
    const luminance = hex => {
        const channels = hex.slice(1).match(/../g).map(value => parseInt(value, 16) / 255)
            .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
    };
    for (const [state, percentage, lightColor, dockColor] of [
        [1, 50, '#18794e', '#70e0a0'],
        [4, 100, '#18794e', '#70e0a0'],
        [2, 20, '#9a5700', '#ffb454'],
        [2, 10, '#c43131', '#ff6b6b'],
    ]) {
        for (const item of [light, dock]) {
            item.proxy.State = state;
            item.proxy.Percentage = percentage;
            item.proxy.emit('g-properties-changed');
        }
        assert.ok(light.icon.gicon.svg.includes(`stroke="${lightColor}"`));
        assert.ok(dock.icon.gicon.svg.includes(`stroke="${dockColor}"`));
        const contrast = (luminance('#fafcfd') + 0.05) / (luminance(lightColor) + 0.05);
        assert.ok(contrast >= 3, `${lightColor} contrast is ${contrast}`);
    }
});
