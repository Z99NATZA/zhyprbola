# Zhyprbola

![Zhyprbola](assets/zhyprbola-logo.png)

![Zhyprbola v0.1.0](assets/zhyprbola-preview-v0_1_0.png)

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
sudo apt install qt6-base-dev qt6-declarative-dev qmake6 gnome-shell-extensions \
    libxkbcommon-dev libglib2.0-dev acl

# Optional runtime helpers
sudo apt install qml6-module-qtquick-controls playerctl cava network-manager bluez

# Optional brightness control for external monitors with DDC/CI enabled
sudo apt install ddcutil

# Optional AT-SPI support for Key Visualizer
# GNOME may deny global keyboard monitoring
sudo apt install gjs gir1.2-atspi-2.0 gir1.2-gtk-4.0
```

## Run

```text
Install
==========

Build the QML panel host, install the local GNOME extension, and enable the dock.

Reload
----------

The dock may appear immediately. If GNOME does not load the updated extension,
log out and back in. Some sessions or machines may need that after each update.
```

```bash
make dock
```

## Dock

```bash
# Run these commands from the project directory.

# Disable the dock while keeping the extension installed
make dock-disable

# Enable the installed dock again
make dock-enable

# Uninstall the local GNOME extension
make dock-remove
```

```text
Removal
==========

Removing the dock keeps the project files and settings in ~/.config/zhyprbola.
Run make dock to build, reinstall, and enable it again.
```

## Development

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

```text
Key Capture
==========

Key visualizer settings are under Settings > Keys. While its bubble is visible,
the panel shows keys typed in other applications only when GNOME grants keyboard
monitoring or keyboard-device read access. On GNOME Wayland, use the
"Allow temporarily" button in Key visualizer when prompted.

The dock's Daily Key Count uses the same global-access fallback but receives only
anonymous press markers. It stores a total for each local date in
`~/.local/state/zhyprbola/key-count.json`, starts a new total at the next local
day, and never stores key names or typed text. Clicking the dock text opens
statistics for today, 7/15 days, this month, rolling 3/6 months, this year, the
best day, and all time. Selecting a range changes the dock text, for example
`keys:7d:1,234`; hovering a range changes only its text color.

Authorization
----------

If the desktop cannot show the authorization dialog, grant temporary read access
from a terminal and reopen Key visualizer.
```

```bash
./scripts/grant-key-capture
```

```text
Security
----------

The button opens system authentication; the terminal command prompts for sudo.
Access lasts until reboot or device reconnect and allows other programs running
as your user to read those devices too. Do not use it on a shared account.
Minimize Key visualizer before entering passwords.

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

## Documentation

- [Documentation](docs/README.md)
- [v0.1.0](docs/release/v0.1.0.md)

## MIT [License](LICENSE)
