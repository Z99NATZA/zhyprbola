# Architecture

```text
GNOME Shell / GJS dock extension
  |
  +-- Native Shell popups: sound, brightness, battery
  +-- Command bridge -> focused Qt/QML panels + C++ backend
  +-- D-Bus -> resident Screenshots browser + C++ backend
```

## Ownership

```text
GJS:  dock placement, buttons, Shell behavior, popups, and panel launching
QML:  panel layout, interaction, progress feedback, and animations
C++:  system data, connection/media helpers, persisted settings, weather, and spectrum
```

## Communication

```text
The extension launches focused panels through the installed panel-command.sh.
Settings live under ~/.config/zhyprbola; file watchers notify other running hosts.
Screenshots uses D-Bus for show/hide while preserving its resident process.
Extend D-Bus to other panels only when lifecycle/state sharing needs it.

The backend owns asynchronous radio power and discovery commands.
QML reads connectionActions to display progress and block repeated requests.
RadioOrb, RadioPowerButton, and RadioDiscoveryStatus share radio visuals.
```

## Development

```bash
make dock                         # Main build/install/enable path
./scripts/run-panel bluetooth      # Run a focused panel directly
./scripts/run-panel wifi
```

```text
Add panels behind PanelHost.qml. Split the backend when it becomes hard to maintain.
Restart affected hosts after changing C++ or loaded QML; rebuilding does not reload them.
```
