import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

const shellLibrary = '/usr/lib/gnome-shell/libshell-18.so';

class Actor {
    constructor(parent = null) { this.parent = parent; this.signals = new Map(); }
    get_parent() { return this.parent; }
    contains(actor) { return actor === this; }
    connect(name, callback) { this.signals.set(name, callback); return name; }
    connectObject(...args) {
        args.pop();
        for (let i = 0; i < args.length; i += 2) this.connect(args[i], args[i + 1]);
    }
    disconnect(name) { this.signals.delete(name); }
    emit(name, ...args) { this.signals.get(name)?.(this, ...args); }
}

class Menu extends Actor {
    constructor(sourceActor) {
        super();
        this.sourceActor = sourceActor;
        this.actor = new Actor();
        this.actor._delegate = this;
        this.isOpen = false;
    }
    open() { this.isOpen = true; this.emit('open-state-changed', true); }
    close() { this.isOpen = false; this.emit('open-state-changed', false); }
}

test('real GNOME menu manager keeps hover and focus passive while clicks and Escape work',
    {skip: !existsSync(shellLibrary)}, () => {
        const stage = new Actor();
        stage.get_event_actor = event => event.target;
        stage.get_key_focus = () => stage.focus;
        const context = vm.createContext({
            Params: {parse: (value, defaults) => ({...defaults, ...value})},
            Shell: {ActionMode: {POPUP: 1}},
            Clutter: {EventType: {KEY_PRESS: 1, ENTER: 2, BUTTON_PRESS: 3, TOUCH_BEGIN: 4},
                EventFlags: {FLAG_GRAB_NOTIFY: 16}, KEY_Escape: 27, KEY_Down: 40,
                EVENT_STOP: 1, EVENT_PROPAGATE: 0},
            St: {DirectionType: {TAB_FORWARD: 0}},
            BoxPointer: {PopupAnimation: {FADE: 1, FULL: 2}},
            Main: {pushModal: () => ({}), popModal() {}}, global: {stage},
            Extension: class {},
        });
        const nativeSource = execFileSync('gresource', ['extract', shellLibrary,
            '/org/gnome/shell/ui/popupMenu.js'], {encoding: 'utf8'});
        const managerSource = nativeSource.slice(nativeSource.indexOf('export class PopupMenuManager'));
        vm.runInContext(managerSource.replace('export class PopupMenuManager',
            'globalThis.NativeManager = class PopupMenuManager'), context);
        context.PopupMenu = {PopupMenuManager: context.NativeManager};
        const dockSource = readFileSync(new URL('../gnome-extension/extension.js', import.meta.url), 'utf8');
        vm.runInContext(dockSource.replace(/^import .*;\n/gm, '')
            .replace('class ClickOnlyPopupMenuManager', 'globalThis.DockManager = class ClickOnlyPopupMenuManager')
            .replace('export default class ZhyprbolaExtension', 'class ZhyprbolaExtension'), context);
        const event = (type, target, key = 0) => ({type: () => type, target,
            get_flags: () => 0, get_key_symbol: () => key});

        // Demonstrate the upstream behavior that caused the bug.
        const native = new context.NativeManager(new Actor());
        const first = new Menu(new Actor()), second = new Menu(new Actor());
        native.addMenu(first); native.addMenu(second);
        first.open();
        native._onCapturedEvent(first.actor, event(2, second.sourceActor));
        assert.equal(second.isOpen, true);
        second.close();

        const dock = new context.DockManager(new Actor());
        const a = new Menu(new Actor()), b = new Menu(new Actor());
        dock.addMenu(a); dock.addMenu(b);
        a.open();
        dock._onCapturedEvent(a.actor, event(2, b.sourceActor));
        assert.equal(a.isOpen, true);
        assert.equal(b.isOpen, false);
        stage.focus = b.sourceActor;
        stage.emit('notify::key-focus');
        assert.equal(a.isOpen, true);
        assert.equal(b.isOpen, false);

        dock._onCapturedEvent(a.actor, event(3, b.sourceActor));
        assert.equal(a.isOpen, false);
        b.open(); // The dock's clicked handler explicitly opens the selected menu.
        assert.equal(dock.activeMenu, b);
        dock._onCapturedEvent(b.actor, event(1, b.actor, 27));
        assert.equal(b.isOpen, false);
        a.open();
        dock._onCapturedEvent(a.actor, event(3, new Actor()));
        assert.equal(a.isOpen, false);
    });
