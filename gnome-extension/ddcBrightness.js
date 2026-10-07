import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

export function runDdcCommand(args, cancellable) {
    return new Promise((resolve, reject) => {
        let process;
        try {
            process = Gio.Subprocess.new(['ddcutil', ...args],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
        } catch (error) {
            reject(error);
            return;
        }
        const cancelId = cancellable.connect(() => process.force_exit());
        let timedOut = false;
        const timeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 15, () => {
            timedOut = true;
            process.force_exit();
            return GLib.SOURCE_REMOVE;
        });
        process.communicate_utf8_async(null, cancellable, (subprocess, result) => {
            if (!timedOut)
                GLib.source_remove(timeout);
            cancellable.disconnect(cancelId);
            try {
                const [, stdout, stderr] = subprocess.communicate_utf8_finish(result);
                if (!subprocess.get_successful())
                    throw new Error(stderr.trim() || 'DDC/CI command failed');
                resolve(stdout);
            } catch (error) {
                reject(error);
            }
        });
    });
}

// DDC traffic is slow: serialize requests and coalesce slider changes.
export class DdcBrightness {
    constructor(onChanged, {
        run = runDdcCommand,
        schedule = callback => GLib.timeout_add(GLib.PRIORITY_DEFAULT, 120, () => {
            callback();
            return GLib.SOURCE_REMOVE;
        }),
        unschedule = id => GLib.source_remove(id),
        cancellable = new Gio.Cancellable(),
    } = {}) {
        this._onChanged = onChanged;
        this._run = args => run(args, cancellable);
        this._schedule = schedule;
        this._unschedule = unschedule;
        this._cancellable = cancellable;
        this.available = false;
        this.value = 0;
        this.error = '';
        this._bus = null;
        this._max = 100;
        this._busy = false;
        this._destroyed = false;
        this._pending = null;
        this._timer = 0;
        this._refreshPending = false;
    }

    async refresh(rediscover = false) {
        if (this._destroyed)
            return;
        this._rediscoverPending ||= rediscover;
        if (this._busy || this._pending !== null) {
            this._refreshPending = true;
            return;
        }
        this._busy = true;
        if (this._rediscoverPending) {
            this._bus = null;
            this._rediscoverPending = false;
        }
        try {
            if (this._bus === null) {
                const output = await this._run(['detect', '--brief']);
                if (this._destroyed)
                    return;
                const display = output.match(/^Display\s+\d+\s*\n\s*I2C bus:\s*\/dev\/i2c-(\d+)/m);
                if (!display)
                    throw new Error('No DDC/CI display found');
                this._bus = display[1];
            }
            const output = await this._run(['getvcp', '10', '--brief', '--bus', this._bus]);
            if (this._destroyed)
                return;
            const match = output.match(/^VCP 10 C (\d+) (\d+)\s*$/m);
            if (!match || Number(match[2]) <= 0 || Number(match[1]) > Number(match[2]))
                throw new Error('Display does not report brightness');
            this._max = Number(match[2]);
            // Preserve a slider change made while the read was in flight.
            if (this._pending === null)
                this.value = Number(match[1]) / this._max;
            this.available = true;
            this.error = '';
            this._onChanged();
        } catch (error) {
            this._fail(error);
        } finally {
            this._busy = false;
            this._drain();
        }
    }

    setValue(value) {
        if (!this.available || this._destroyed || !Number.isFinite(value))
            return;
        this.value = Math.max(0, Math.min(1, value));
        this._pending = Math.round(this.value * this._max);
        if (!this._timer) {
            this._timer = this._schedule(() => {
                this._timer = 0;
                this._drain();
            });
        }
    }

    async _drain() {
        if (this._destroyed || this._busy || this._timer)
            return;
        if (this._pending === null) {
            if (this._refreshPending) {
                this._refreshPending = false;
                this.refresh();
            }
            return;
        }
        const value = this._pending;
        this._pending = null;
        this._busy = true;
        try {
            await this._run(['setvcp', '10', String(value), '--bus', this._bus]);
            if (!this._destroyed && this._pending === null) {
                this.value = value / this._max;
                this._onChanged();
            }
        } catch (error) {
            this._fail(error);
        } finally {
            this._busy = false;
            this._drain();
        }
    }

    _fail(error) {
        if (this._destroyed)
            return;
        this.available = false;
        this.error = error.message;
        this._bus = null;
        this._pending = null;
        this._refreshPending = false;
        this._onChanged();
    }

    destroy() {
        this._destroyed = true;
        if (this._timer)
            this._unschedule(this._timer);
        this._timer = 0;
        this._pending = null;
        this._cancellable.cancel();
    }
}
