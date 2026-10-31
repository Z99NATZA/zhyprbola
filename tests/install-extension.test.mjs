import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';

const uuid = 'zhyprbola@znnn.local';

function run(packFails = false) {
    const dir = mkdtempSync(join(tmpdir(), 'zhyprbola-install-'));
    const root = join(dir, 'project with spaces');
    const bin = join(dir, 'bin');
    const data = join(dir, 'data');
    const target = join(data, 'gnome-shell', 'extensions', uuid);
    mkdirSync(join(root, 'scripts'), {recursive: true});
    mkdirSync(bin);
    mkdirSync(target, {recursive: true});
    writeFileSync(join(target, 'panel-command.sh'), 'existing launcher');
    cpSync(new URL('../scripts/install-extension', import.meta.url), join(root, 'scripts/install-extension'));
    const statePath = join(dir, 'calls.json');
    writeFileSync(statePath, '[]');
    writeFileSync(join(bin, 'gnome-extensions'), `#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
const calls = JSON.parse(fs.readFileSync(process.env.INSTALL_TEST_STATE));
calls.push({args, vfs: process.env.GIO_USE_VFS});
fs.writeFileSync(process.env.INSTALL_TEST_STATE, JSON.stringify(calls));
const target = path.join(process.env.XDG_DATA_HOME, 'gnome-shell/extensions', '${uuid}');
assert.equal(fs.readFileSync(path.join(target, 'panel-command.sh'), 'utf8'), 'existing launcher');
if (args[0] === 'pack') {
    if (process.env.INSTALL_TEST_FAIL === 'true') process.exit(23);
    const out = args[args.indexOf('--out-dir') + 1];
    fs.writeFileSync(path.join(out, '${uuid}.shell-extension.zip'), 'new bundle');
} else {
    assert.equal(args[0], 'install');
    assert.equal(args[1], '--force');
    assert.equal(fs.readFileSync(args[2], 'utf8'), 'new bundle');
}
`, {mode: 0o755});
    // Guard the real desktop against a regression that removes its extension.
    writeFileSync(join(bin, 'rm'), `#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const args = process.argv.slice(2);
assert.deepEqual(args, ['-rf', process.env.INSTALL_TEST_PACK]);
fs.rmSync(args[1], {recursive: true, force: true});
`, {mode: 0o755});
    try {
        const result = spawnSync('bash', [join(root, 'scripts/install-extension')], {
            encoding: 'utf8', timeout: 10000,
            env: {...process.env, PATH: `${bin}:${process.env.PATH}`,
                XDG_DATA_HOME: data, GIO_USE_VFS: 'gvfs',
                INSTALL_TEST_STATE: statePath, INSTALL_TEST_FAIL: String(packFails),
                INSTALL_TEST_PACK: join(root, 'build/extension-pack')},
        });
        assert.ifError(result.error);
        return {...result, calls: JSON.parse(readFileSync(statePath, 'utf8')),
            launcherPreserved: existsSync(join(target, 'panel-command.sh'))};
    } finally {
        rmSync(dir, {recursive: true, force: true});
    }
}

test('failed packaging preserves the installed launcher and skips installation', () => {
    const result = run(true);
    assert.equal(result.status, 23, result.stderr);
    assert.equal(result.launcherPreserved, true);
    assert.deepEqual(result.calls.map(call => call.args[0]), ['pack']);
    assert.equal(result.calls[0].vfs, 'local');
    assert.match(result.stdout, /Packing/);
    assert.doesNotMatch(result.stdout, /Installing|Installed/);
});

test('successful packaging uses local GIO and force-installs with the old launcher still available', () => {
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(result.calls.map(call => call.args[0]), ['pack', 'install']);
    assert.ok(result.calls.every(call => call.vfs === 'local'));
    assert.equal(result.launcherPreserved, true);
    assert.match(result.stdout, /Packing[\s\S]*Installing[\s\S]*Installed/);
});
