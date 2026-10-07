import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../gnome-extension/extension.js', import.meta.url), 'utf8');

test('GNOME extension publishes the active XKB source for global key capture', () => {
    const writes = [];
    const unlinks = [];
    const context = vm.createContext({
        Extension: class {},
        PopupMenu: {PopupMenuManager: class {}},
        GLib: {
            path_get_dirname: path => path.slice(0, path.lastIndexOf('/')),
            mkdir_with_parents: () => 0,
            file_set_contents: (path, value) => writes.push({path, value}),
            unlink: path => unlinks.push(path),
        },
    });
    vm.runInContext(source.replace(/^import .*;\n/gm, '')
        .replace('export default class ZhyprbolaExtension',
            'globalThis.Dock = class ZhyprbolaExtension'), context);
    const dock = new context.Dock();
    dock._inputSourcePath = '/run/user/test/zhyprbola/input-source';
    dock._publishedInputSource = null;
    dock._inputSourceManager = {currentSource: {type: 'xkb', id: 'us'}};

    dock._publishInputSource();
    dock._publishInputSource();
    dock._inputSourceManager.currentSource = {type: 'xkb', id: 'th'};
    dock._queueInputSourceRefresh();
    dock._inputSourceManager.currentSource = {type: 'ibus', id: 'other'};
    dock._queueInputSourceRefresh();

    assert.deepEqual(writes, [
        {path: dock._inputSourcePath, value: 'us\n'},
        {path: dock._inputSourcePath, value: 'th\n'},
    ]);
    assert.deepEqual(unlinks, [dock._inputSourcePath]);
});
