import Atspi from 'gi://Atspi?version=2.0';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

Atspi.init();
const device = Atspi.Device.new();
if (!(device.get_capabilities() & Atspi.DeviceCapability.KEYBOARD_MONITOR))
    throw new Error('Global keyboard monitoring is unavailable');

// Device.new() does not surface WatchKeyboard failures, so verify that GNOME
// has actually authorized this listener before claiming it is ready.
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

// Keep key identity only in memory long enough to suppress auto-repeat. The
// counter output still contains no key code, symbol, modifier, or text.
const pressed = new Set();
device.connect('key-pressed', (_device, hwCode) => {
    if (pressed.has(hwCode))
        return;
    pressed.add(hwCode);
    print('{"type":"press"}');
});
device.connect('key-released', (_device, hwCode) => pressed.delete(hwCode));

const loop = new GLib.MainLoop(null, false);
const parentInput = GLib.IOChannel.unix_new(0);
GLib.io_add_watch(parentInput, GLib.PRIORITY_DEFAULT,
    GLib.IOCondition.HUP | GLib.IOCondition.ERR, () => {
        loop.quit();
        return GLib.SOURCE_REMOVE;
    });
print('{"type":"ready"}');
loop.run();
