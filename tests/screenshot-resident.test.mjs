import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';

const binary = fileURLToPath(new URL('../build/zhyprbola', import.meta.url));

test('resident screenshots reuses one lightweight process through repeated D-Bus Show/Hide',
    {skip: !existsSync(binary)}, () => {
        const script = `
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const binary = process.argv[1];
const child = spawn(binary, ['--panel', 'screenshots', '--resident'], {
    env: {...process.env, QT_QPA_PLATFORM: 'offscreen'}, stdio: ['ignore', 'ignore', 'pipe'],
});
let errors = '';
child.stderr.on('data', data => errors += data);
const args = ['--session', '--dest', 'org.zhyprbola.Screenshots',
    '--object-path', '/org/zhyprbola/Screenshots'];
const call = method => execFileSync('gdbus', ['call', ...args,
    '--method', 'org.zhyprbola.Screenshots.' + method], {stdio: 'pipe', timeout: 3000});
try {
    let ready = false;
    for (let i = 0; i < 100; i++) {
        try { call('Hide'); ready = true; break; } catch {}
        await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(ready, errors);
    for (let i = 0; i < 20; i++) { call('Show'); call('Hide'); }
    assert.equal(child.exitCode, null);
    const children = readFileSync('/proc/' + child.pid + '/task/' + child.pid + '/children', 'utf8');
    assert.equal(children.trim(), '', 'screenshots must not launch cava or other component helpers');
    execFileSync(binary, ['--panel', 'screenshots', '--resident'], {
        env: {...process.env, QT_QPA_PLATFORM: 'offscreen'}, timeout: 3000,
    });
    assert.equal(child.exitCode, null);
    call('Quit');
    await new Promise(resolve => child.once('exit', resolve));
    assert.equal(child.exitCode, 0, errors);
    assert.equal(errors, '');
    console.log('20 Show/Hide cycles completed in one process with no component helpers');
} finally { if (child.exitCode === null) child.kill(); }
`;
        const output = execFileSync('dbus-run-session', ['--', 'node', '--input-type=module',
            '-e', script, binary], {encoding: 'utf8', timeout: 15000});
        assert.match(output, /20 Show\/Hide cycles completed/);
    });
