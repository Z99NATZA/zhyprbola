import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {copyFileSync, existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync,
    writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';
import {promisify} from 'node:util';

const run = promisify(execFile);
const binary = new URL('../build/zhyprbola', import.meta.url);

for (const failure of ['exits', 'stalls']) {
    test(`Key Visualizer resumes displaying keys after its helper ${failure}`,
        {skip: !existsSync(binary) && 'run make build first'}, async t => {
        const dir = mkdtempSync(join(tmpdir(), 'zhyprbola-key-visualizer-'));
        t.after(() => rmSync(dir, {recursive: true, force: true}));
        for (const folder of ['build', 'scripts', 'config', 'runtime'])
            mkdirSync(join(dir, folder), {mode: 0o700});

        // The application locates its helpers relative to the executable.
        const app = join(dir, 'build', 'zhyprbola');
        copyFileSync(binary, app);
        copyFileSync(new URL('../PanelHost.qml', import.meta.url), join(dir, 'PanelHost.qml'));
        symlinkSync(fileURLToPath(new URL('../components', import.meta.url)), join(dir, 'components'));
        writeFileSync(join(dir, 'scripts', 'key-capture.js'), '');
        writeFileSync(join(dir, 'gjs'), '#!/bin/sh\nexit 1\n', {mode: 0o700});
        writeFileSync(join(dir, 'build', 'key-capture-evdev'), `#!/bin/sh
if [ -e "$KEY_CAPTURE_TEST_MARKER" ]; then
    echo '{"type":"ready","heartbeat":true}'
    echo '{"type":"press","name":"b","text":"b"}'
    exec /bin/sleep 30
fi
: > "$KEY_CAPTURE_TEST_MARKER"
echo '{"type":"ready","heartbeat":true}'
echo '{"type":"press","name":"a","text":"a"}'
${failure === 'exits' ? 'exit 1' : 'exec /bin/sleep 30'}
`, {mode: 0o700});

        const harness = join(dir, 'Reconnect.qml');
        writeFileSync(harness, `import QtQuick

PanelHost {
    id: host
    property bool disconnected: false
    Connections {
        target: backend
        function onKeyCaptureAvailableChanged() {
            if (!backend.keyCaptureAvailable && host.panelItem?.displayText === "a")
                host.disconnected = true
        }
    }
    Connections {
        target: host.panelItem
        function onDisplayTextChanged() {
            if (host.disconnected && backend.keyCaptureAvailable && host.panelItem.displayText === "ab") {
                console.log("Key Visualizer resumed")
                Qt.quit()
            }
        }
    }
}
`);
        const {stderr} = await run(app, ['--panel', 'key-visualizer', harness], {
            timeout: 16000,
            env: {...process.env,
                PATH: dir,
                QT_QPA_PLATFORM: 'offscreen',
                QT_QUICK_BACKEND: 'software',
                XDG_CACHE_HOME: join(dir, 'cache'),
                XDG_CONFIG_HOME: join(dir, 'config'),
                XDG_RUNTIME_DIR: join(dir, 'runtime'),
                DBUS_SESSION_BUS_ADDRESS: `unix:path=${join(dir, 'unused-bus')}`,
                KEY_CAPTURE_TEST_MARKER: join(dir, 'evdev-started')},
        });
        assert.match(stderr, /Key Visualizer resumed/);
    });
}
