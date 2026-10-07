import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../gnome-extension/ddcBrightness.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(source.replace(/^import .*;\n/gm, '')
    .replace('export function runDdcCommand', 'function runDdcCommand')
    .replace('export class DdcBrightness', 'globalThis.DdcBrightness = class DdcBrightness'), context);
const detect = 'Invalid display\n   I2C bus: /dev/i2c-1\n\nDisplay 1\n   I2C bus: /dev/i2c-3\n   Monitor: MSI\n';
const tick = async () => { for (let i = 0; i < 8; i++) await Promise.resolve(); };

function fixture() {
    const calls = [], timers = new Map();
    let nextTimer = 0, changes = 0;
    const cancellable = {cancelled: false, cancel() { this.cancelled = true; }};
    const backend = new context.DdcBrightness(() => changes++, {
        run: args => new Promise((resolve, reject) => calls.push({args: [...args], resolve, reject})),
        schedule: callback => { const id = ++nextTimer; timers.set(id, callback); return id; },
        unschedule: id => timers.delete(id), cancellable,
    });
    const flush = () => { for (const [id, callback] of timers) { timers.delete(id); callback(); } };
    const ready = async (value = 'VCP 10 C 1 100\n') => {
        const reading = backend.refresh();
        calls.at(-1).resolve(detect);
        await tick();
        calls.at(-1).resolve(value);
        await reading;
    };
    return {backend, calls, timers, cancellable, flush, ready, changes: () => changes};
}

test('discovery skips invalid displays and reads the reported brightness without writing', async () => {
    const {backend, calls, ready} = fixture();
    await ready('VCP 10 C 20 200\n');
    assert.equal(backend.available, true);
    assert.equal(backend.value, 0.1);
    assert.deepEqual(calls.map(call => call.args), [
        ['detect', '--brief'], ['getvcp', '10', '--brief', '--bus', '3'],
    ]);
});

test('slider writes are scaled, clamped, debounced and serialized to the latest value', async () => {
    const {backend, calls, ready, flush} = fixture();
    await ready('VCP 10 C 20 200\n');
    backend.setValue(0.2);
    backend.setValue(0.4);
    flush();
    assert.deepEqual(calls[2].args, ['setvcp', '10', '80', '--bus', '3']);
    backend.setValue(0.6);
    backend.setValue(0.7);
    flush();
    assert.equal(calls.length, 3);
    calls[2].resolve('');
    await tick();
    assert.deepEqual(calls[3].args, ['setvcp', '10', '140', '--bus', '3']);
    calls[3].resolve('');
    await tick();
    backend.setValue(1.2);
    flush();
    assert.equal(calls[4].args[2], '200');
    calls[4].resolve('');
    await tick();
    backend.setValue(-0.2);
    flush();
    assert.equal(calls[5].args[2], '0');
    calls[5].resolve('');
    await tick();
    assert.equal(backend.value, 0);
});

test('refresh during writes waits and reads back the final hardware value', async () => {
    const {backend, calls, ready, flush} = fixture();
    await ready();
    backend.setValue(0.3);
    flush();
    await backend.refresh();
    assert.equal(calls.length, 3);
    calls[2].resolve('');
    await tick();
    assert.deepEqual(calls[3].args, ['getvcp', '10', '--brief', '--bus', '3']);
    calls[3].resolve('VCP 10 C 29 100\n');
    await tick();
    assert.equal(backend.value, 0.29);
});

test('write failure disables controls and next refresh rediscovers the monitor', async () => {
    const {backend, calls, ready, flush} = fixture();
    await ready();
    backend.setValue(0.3);
    flush();
    calls[2].reject(new Error('Permission denied'));
    await tick();
    assert.equal(backend.available, false);
    assert.equal(backend.error, 'Permission denied');
    await ready();
    assert.deepEqual(calls[3].args, ['detect', '--brief']);
    assert.equal(backend.available, true);
});

test('unsupported features and invalid maximum values leave controls disabled', async () => {
    for (const output of ['VCP 10 ERR\n', 'VCP 10 C 0 0\n', 'VCP 10 C 101 100\n']) {
        const {backend, ready} = fixture();
        await ready(output);
        assert.equal(backend.available, false);
    }
});

test('monitor changes rediscover the bus instead of keeping a stale display', async () => {
    const {backend, calls, ready} = fixture();
    await ready();
    const reading = backend.refresh(true);
    assert.deepEqual(calls[2].args, ['detect', '--brief']);
    calls[2].resolve(detect.replace('i2c-3', 'i2c-5'));
    await tick();
    assert.equal(calls[3].args.at(-1), '5');
    calls[3].resolve('VCP 10 C 50 100\n');
    await reading;
    assert.equal(backend.value, 0.5);
});

test('destroy cancels pending commands and suppresses late callbacks', async () => {
    const {backend, calls, ready, cancellable, changes} = fixture();
    await ready();
    const reading = backend.refresh();
    const count = changes();
    backend.destroy();
    calls[2].resolve('VCP 10 C 90 100\n');
    await reading;
    assert.equal(cancellable.cancelled, true);
    assert.equal(changes(), count);
    assert.equal(backend.value, 0.01);
});
