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


test('evdev recovers modifiers across duplicate events, devices, layouts and lost releases',
    {skip: !existsSync(helper) && 'run make build first'}, () => {
    const result = spawnSync(helper.pathname, ['--self-test-state-recovery'],
        {encoding: 'utf8'});
    assert.equal(result.status, 0, result.stderr);
    const scenarios = new Map();
    let current;
    for (const event of result.stdout.trim().split('\n').map(JSON.parse)) {
        if (event.type === 'scenario') {
            current = [];
            scenarios.set(event.name, current);
        } else if (event.type === 'press') {
            current.push(event);
        }
    }
    const letters = name => scenarios.get(name).filter(event => event.text);
    const plain = event => {
        assert.equal(event.text, 'a');
        for (const modifier of ['shift', 'ctrl', 'alt', 'super'])
            assert.equal(event[modifier], false, `${modifier} must not stay pressed`);
    };
    plain(letters('duplicate-super')[0]);
    assert.equal(scenarios.get('duplicate-super').length, 2,
        'duplicate presses must not reach XKB or the visualizer');
    assert.equal(letters('two-keyboards')[0].super, true,
        'a modifier held on another keyboard stays active');
    plain(letters('two-keyboards')[1]);
    const switched = letters('layout-switch-with-shift');
    assert.equal(switched[0].text, 'A');
    assert.equal(switched[0].shift, true);
    assert.match(switched[1].text, /[ก-๙]/);
    assert.equal(switched[1].shift, true);
    plain(switched[2]);
    plain(letters('missed-release')[0]);
    plain(letters('disconnect')[0]);
    assert.equal(letters('startup-held-key')[0].text, 'A');
    plain(letters('startup-held-key')[1]);
    assert.equal(letters('caps-led')[0].text, 'A');
    assert.equal(letters('caps-led')[0].shift, false);
    plain(letters('caps-led')[1]);
    assert.equal(scenarios.get('dropped-events').length, 1,
        'events inside a dropped packet must be ignored');
    plain(letters('dropped-events')[0]);
});
