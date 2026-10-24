# Development

```text
Panels
==========

Build without installing the GNOME extension, or run a focused panel directly.
```

```bash
make build
make run-panel
./scripts/run-panel bluetooth
./scripts/run-panel wifi
./scripts/run-panel clock-weather
./scripts/run-panel key-visualizer
./scripts/run-panel system-status
```

[Key Capture and Security](key-capture.md) covers keyboard access and authorization.

```text
Spectrum
==========

Edge spectrum is managed by the GNOME dock extension. Enable it and choose an
edge in Settings -> Spectrum; the original spectrum bubble remains available.

Checks
==========

QML lint currently exits successfully but may print existing qmllint warnings.
```

```bash
make check
```

```text
Panel startup
==========

The benchmark measures process launch to the first rendered frame using the
offscreen software renderer, isolated config/cache directories, one warmup,
and three samples per panel. It excludes GNOME's window animation and is not
a measurement of when remote device/weather data has finished loading.
```

```bash
./scripts/benchmark-panel-startup
./scripts/benchmark-panel-startup --runs 5 calendar settings wifi music

mkdir -p build/startup-tests
cd build/startup-tests
qmake6 ../../tests/panel-startup.pro
make
QT_QPA_PLATFORM=offscreen dbus-run-session -- ../panel-startup-test
```
