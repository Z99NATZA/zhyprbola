# Zhyprbola

## Stack

```text
Shell:   GNOME Shell Extension (GJS)
Panels:  Qt Quick / QML
Backend: C++ / Qt
Build:   qmake6 + make
```

## Setup

```bash
# Debian/Ubuntu base tools
sudo apt install qt6-base-dev qt6-declarative-dev qmake6 gnome-shell-extensions

# optional runtime helpers
sudo apt install qml6-module-qtquick-controls playerctl cava network-manager bluez
```

## Run

```bash
make dock

# Builds the QML panel host, installs the local GNOME extension,
# and enables the dock.

# The dock may appear immediately. If GNOME does not load the updated extension,
# log out and back in. Some sessions or machines may need that after each update.
```

## Development

```bash
# build without installing the GNOME extension
make build

# run focused panels directly
make run-panel
./scripts/run-panel bluetooth
./scripts/run-panel wifi
./scripts/run-panel clock-weather
./scripts/run-panel system-status

# Edge spectrum is managed by the GNOME dock extension. Enable it and choose
# an edge in Settings → Spectrum; the original spectrum bubble remains available.

# QML lint checks
# make check currently exits successfully but may print existing qmllint warnings.
make check
```
