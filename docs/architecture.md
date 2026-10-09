# Architecture

```text
GNOME Shell
  |
  v
GJS dock extension
  |
  | command bridge now
  | D-Bus later if needed
  v
Qt/QML panel host
  |
  v
QML panels + C++ backend
```

## Ownership

```text
GJS:
- dock placement
- dock buttons
- shell behavior
- panel launching

QML:
- panel UI
- panel interaction
- rich visual surfaces

C++ backend:
- system data
- Wi-Fi / Bluetooth / media helpers
- weather and spectrum plumbing
```

## Current Bridge

```bash
./scripts/run-panel bluetooth
./scripts/run-panel wifi

# The extension spawns focused QML panels through the installed panel-command.sh.
# Move to D-Bus only when panel lifecycle/state sharing needs it.
```

## Next

```bash
# 1. Keep this as the main run path:
make dock

# 2. Add panels behind PanelHost.qml as needed.
# 3. Split the backend only when the shared class becomes hard to maintain.
```
