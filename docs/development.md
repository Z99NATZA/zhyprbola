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
