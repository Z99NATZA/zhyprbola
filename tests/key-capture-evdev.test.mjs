import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {test} from 'node:test';

const helper = new URL('../build/key-capture-evdev', import.meta.url);
test('evdev helper maps English, modifiers, Thai and special keys',
    {skip: !existsSync(helper) && 'run make build first'}, () => {
    const result = spawnSync(helper.pathname, ['--self-test'], {encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    const presses = result.stdout.trim().split('\n').map(JSON.parse)
        .filter(event => event.type === 'press');

    assert.equal(presses[0].text, 'a');
    assert.equal(presses[2].ctrl, true);
    assert.equal(presses[4].shift, true);
    assert.equal(presses[4].text, 'A');
    assert.match(presses[5].text, /[ก-๙]/);
    assert.deepEqual(presses.slice(-3).map(event => event.name),
        ['space', 'BackSpace', 'Return']);
});

test('evdev helper follows GNOME input-source changes across windows',
    {skip: !existsSync(helper) && 'run make build first'}, () => {
    const result = spawnSync(helper.pathname, ['--self-test-source-switch'],
        {encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    const presses = result.stdout.trim().split('\n').map(JSON.parse)
        .filter(event => event.type === 'press');
    assert.equal(presses.length, 3);
    assert.equal(presses[0].text, 'd');
    assert.match(presses[1].text, /[ก-๙]/);
    assert.equal(presses[2].text, 'd');
});
