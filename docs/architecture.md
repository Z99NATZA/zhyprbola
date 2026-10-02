# Zhyprbola Architecture

This document describes the practical architecture for `zhyprbola`.

For the project story and name meaning, see `zhyprbola-origin.md`. This file is
for implementation direction and should evolve as the system becomes real.

## Goal

`zhyprbola` is a GNOME-friendly desktop layer that combines:

- a GJS GNOME Shell extension for shell integration, dock placement, and panel
  icons
- a Qt/QML panel host for rich visual components
- a small IPC bridge between both runtimes

The project should feel like one desktop experience while keeping GJS and QML as
separate runtimes.

## Runtime Boundary

GJS and QML should live in the same repository, but not the same process.

```text
GNOME Shell
  |
  | loads
  v
GJS Extension
  |
  | D-Bus / command bridge
  v
Qt/QML Panel Host
  |
  v
QML Components + C++ Backend
```

The extension owns shell-facing UI. The QML host owns rich panels. The bridge is
the contract between them.

## Repository Shape

The current `zpola` code can evolve toward this shape:

```text
zhyprbola/
  docs/
    architecture.md
    zhyprbola-origin.md

  gnome-extension/
    extension.js
    metadata.json
    stylesheet.css
    dock/
    icons/

  qml/
    Main.qml
    PanelHost.qml
    panels/
      BluetoothPanel.qml
      WifiPanel.qml
      MediaPanel.qml

  backend/
    Backend.cpp
    Backend.h

  scripts/
    run-panel
    install-extension
    dev
```

The exact folder names can change. The important rule is that shell integration,
QML panels, backend logic, and documentation have clear ownership.

## GJS Extension

The GJS extension should own anything that must behave like GNOME Shell UI:

- right dock placement
- dock icons
- click, hover, and focus behavior
- GNOME panel or Dash to Panel integration
- shell-level state and shortcuts
- deciding which panel should open

The extension should not directly embed QML. It should call the QML host through
IPC.

First target:

- show a right dock
- include a Bluetooth icon
- open the Bluetooth QML panel when clicked

## QML Panel Host

The QML side should own visual components that benefit from Qt Quick:

- Bluetooth panel
- Wi-Fi panel
- media panel
- quick settings
- component manager
- future rich desktop widgets

The QML host should be runnable independently for development.

Example commands:

```bash
zhyprbola-panel --panel bluetooth
zhyprbola-panel --panel wifi
zhyprbola-panel --panel media
```

During early development this can reuse the existing `zpola` app structure. Over
time, the desktop-widget shell and focused panel host can be separated.

## IPC Bridge

The preferred bridge is D-Bus.

Initial interface idea:

```text
Service:   org.zhyprbola.Shell
Object:    /org/zhyprbola/Shell
Interface: org.zhyprbola.Shell

Methods:
  ShowPanel(panelName: string)
  HidePanel(panelName: string)
  TogglePanel(panelName: string)
  Refresh(componentName: string)
```

Possible panel names:

- `bluetooth`
- `wifi`
- `media`
- `quickSettings`
- `components`

Fallback during early development:

```bash
zhyprbola-panel --panel bluetooth
```

The command bridge is easier to build first. D-Bus is better once the extension
and panel host need stable two-way communication.

## Process Model

There are two practical options.

### Spawn Per Panel

GJS launches the panel host only when a panel is requested.

```text
click bluetooth -> spawn zhyprbola-panel --panel bluetooth
```

Pros:

- simple
- easy to debug
- no long-running service required

Cons:

- slower first open
- harder to share state
- positioning can feel less native on Wayland

### Long-Running Panel Host

The panel host runs in the background and receives D-Bus calls.

```text
click bluetooth -> D-Bus TogglePanel("bluetooth")
```

Pros:

- faster
- cleaner state management
- better foundation for multiple panels

Cons:

- needs lifecycle handling
- needs service activation or startup integration

Recommended path: start with command spawning, then move to D-Bus once the first
GJS dock works.

## Backend Ownership

Backend code should stay close to the component that needs it.

Current examples:

- Bluetooth state can be read through BlueZ tools or D-Bus.
- Wi-Fi state can be read through NetworkManager tools or D-Bus.
- Media state can be read through MPRIS.

Early implementation can keep using the existing C++ `Backend` class. Later, the
backend can split into smaller controllers if one class becomes too broad.

## UI Ownership

The dock belongs to GJS.

The panel contents belong to QML.

This means:

- icon position, dock animation, and shell behavior are GJS concerns
- panel layout, lists, controls, and visual polish are QML concerns
- shared state crosses the boundary only through IPC

## Wayland Notes

GNOME Wayland does not allow arbitrary external apps to position windows with the
same control as GNOME Shell itself.

Because of that:

- the dock should be implemented in GJS
- QML panels may need to appear as regular or layer-like windows
- exact positioning should be treated as a design constraint
- if a panel must behave perfectly like shell UI, it may eventually need a GJS
  implementation

The first QML panels should be designed to tolerate this limitation.

## First Milestone

The first architecture milestone is:

```text
Click Bluetooth icon in a GNOME right dock
  -> open BluetoothPanel.qml
  -> show real Bluetooth power/device state
  -> allow scan/connect/disconnect where supported
```

This proves:

- GJS can own shell UI
- QML can own rich component UI
- the bridge is good enough for real interaction

## Open Questions

- Should the panel host start on login or only on demand?
- Should D-Bus be implemented in the QML app, a small helper daemon, or both?
- How much panel positioning is acceptable on GNOME Wayland?
- Should Wi-Fi and Bluetooth use command-line tools first, then native D-Bus
  APIs later?
- Should `zpola` remain as a legacy app name during transition, or should the
  binary and QML imports move to `zhyprbola` immediately?

## Near-Term Plan

1. Commit the current Bluetooth panel work.
2. Keep `zpola` runnable as the current QML development host.
3. Add a focused panel launch mode, starting with Bluetooth.
4. Create a minimal GNOME extension with a right dock and Bluetooth icon.
5. Connect the icon to the QML panel through a command bridge.
6. Replace the command bridge with D-Bus when interaction needs grow.
