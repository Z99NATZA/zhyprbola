import Atspi from 'gi://Atspi?version=2.0';
import Gdk from 'gi://Gdk?version=4.0';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

Atspi.init();
const device = Atspi.Device.new();
if (!(device.get_capabilities() & Atspi.DeviceCapability.KEYBOARD_MONITOR))
    throw new Error('Global keyboard monitoring is unavailable');

// Device.new() ignores WatchKeyboard errors, so capabilities alone do not
// establish that the compositor has authorized this listener.
try {
    Gio.DBus.session.call_sync(
        'org.gnome.Shell',
        '/org/freedesktop/a11y/Manager',
        'org.freedesktop.a11y.KeyboardMonitor',
        'WatchKeyboard',
        null, null, Gio.DBusCallFlags.NONE, -1, null);
} catch (error) {
    throw new Error(`Global keyboard monitoring was denied: ${error.message}`);
}

// The compositor emits repeated presses for held keys. Forward them with
// the current symbol and modifiers, just like the initial press.
function send(type, _device, _keycode, keysym, state, keystring) {
    const name = Gdk.keyval_name(keysym) ?? '';
    const codepoint = Gdk.keyval_to_unicode(keysym);
    const fallback = codepoint > 31 && codepoint !== 127
        ? String.fromCodePoint(codepoint) : '';
    const text = keystring && !/[\x00-\x1f\x7f]/.test(keystring)
        ? keystring : fallback;
    const active = modifier => (state & (1 << modifier)) !== 0;
    print(JSON.stringify({
        type, name, text,
        shift: active(Atspi.ModifierType.SHIFT),
        ctrl: active(Atspi.ModifierType.CONTROL),
        alt: active(Atspi.ModifierType.ALT),
        super: active(Atspi.ModifierType.SUPER),
    }));
}

device.connect('key-pressed', (...args) => send('press', ...args));
device.connect('key-released', (...args) => send('release', ...args));
const loop = new GLib.MainLoop(null, false);
const parentInput = GLib.IOChannel.unix_new(0);
GLib.io_add_watch(parentInput, GLib.PRIORITY_DEFAULT,
    GLib.IOCondition.HUP | GLib.IOCondition.ERR, () => {
        loop.quit();
        return GLib.SOURCE_REMOVE;
    });
print(JSON.stringify({type: 'ready'}));
loop.run();
