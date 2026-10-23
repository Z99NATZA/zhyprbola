import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {test} from 'node:test';

const uuid = 'zhyprbola@znnn.local';
const script = new URL('../scripts/enable-dock', import.meta.url);

function run(initial = {}) {
    const dir = mkdtempSync(join(tmpdir(), 'zhyprbola-enable-'));
    const statePath = join(dir, 'state.json');
    writeFileSync(statePath, JSON.stringify({
        globalDisabled: false, registered: true, state: 'INITIALIZED',
        enabled: "['other@example.local']", calls: [], ...initial,
    }));
    const mock = `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const statePath = process.env.DOCK_TEST_STATE;
const state = JSON.parse(fs.readFileSync(statePath));
const command = path.basename(process.argv[1]);
const args = process.argv.slice(2);
state.calls.push([command, ...args]);
state.locale = process.env.LC_ALL;
let status = 0;
if (command === 'gsettings') {
    const key = args[2];
    if (args[0] === 'get')
        console.log(key === 'disable-user-extensions' ? state.globalDisabled : state.enabled);
    else if (key === 'disable-user-extensions')
        state.globalDisabled = args[3] === 'true';
    else if (key === 'enabled-extensions')
        state.enabled = args[3];
} else if (command === 'gnome-extensions') {
    if (args[0] === 'info') {
        if (!state.registered) status = 1;
        else console.log('State: ' + state.state);
    } else if (args[0] === 'disable') {
        state.state = 'INACTIVE';
    } else if (args[0] === 'enable') {
        state.state = state.globalDisabled ? 'INITIALIZED' : (state.activationState ?? 'ACTIVE');
    }
}
fs.writeFileSync(statePath, JSON.stringify(state));
process.exit(status);
`;
    for (const command of ['gnome-extensions', 'gsettings', 'sleep'])
        writeFileSync(join(dir, command), mock, {mode: 0o755});
    try {
        const result = spawnSync('bash', [script.pathname], {
            encoding: 'utf8', timeout: 10000,
            env: {...process.env, LC_ALL: 'th_TH.UTF-8',
                PATH: `${dir}:${process.env.PATH}`, DOCK_TEST_STATE: statePath},
        });
        assert.ifError(result.error);
        return {...result, state: JSON.parse(readFileSync(statePath, 'utf8'))};
    } finally {
        rmSync(dir, {recursive: true, force: true});
    }
}

test('dock activation recovers from GNOME globally disabling user extensions', () => {
    const result = run({globalDisabled: true});
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.state.globalDisabled, false);
    assert.equal(result.state.state, 'ACTIVE');
    assert.match(result.stdout, /Re-enabled GNOME user extensions/);
    const recover = result.state.calls.findIndex(call =>
        call.join(' ') === 'gsettings set org.gnome.shell disable-user-extensions false');
    const enable = result.state.calls.findIndex(call => call[1] === 'enable');
    assert.ok(recover >= 0 && recover < enable);
    assert.equal(result.state.locale, 'C');
});

test('normal activation leaves the global switch and other extensions untouched', () => {
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.state.state, 'ACTIVE');
    assert.equal(result.state.enabled, "['other@example.local']");
    assert.equal(result.state.calls.some(call => call[0] === 'gsettings' && call[1] === 'set'), false);
});

for (const activationState of ['ERROR', 'OUT OF DATE']) {
    test(`activation reports ${activationState} without claiming logout will fix it`, () => {
        const result = run({activationState});
        assert.equal(result.status, 1);
        assert.match(result.stderr, new RegExp(`State: ${activationState}`));
        assert.match(result.stderr, /journalctl/);
        assert.doesNotMatch(result.stderr, /Log out/);
        assert.equal(result.state.calls.filter(call => call[0] === 'sleep').length, 1);
    });
}

test('an undiscovered extension is scheduled for next login without losing enabled extensions', () => {
    const result = run({registered: false, globalDisabled: true});
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.state.globalDisabled, false);
    assert.equal(result.state.enabled, `['other@example.local', '${uuid}']`);
    assert.match(result.stdout, /Log out and back in/);
});

test('an undiscovered extension already enabled is not duplicated', () => {
    const result = run({registered: false, enabled: `['${uuid}']`});
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.state.enabled, `['${uuid}']`);
    assert.equal(result.state.calls.some(call => call[0] === 'gsettings' && call[1] === 'set'), false);
});
