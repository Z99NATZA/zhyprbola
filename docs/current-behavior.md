# Current Behavior

```text
Zhyprbola combines a GNOME Shell dock with focused Qt/QML panels.
Shell handles sound, brightness, and battery popups; Screenshots is a resident QML browser.
Other QML panels cover connections, clock/weather, keys, status, spectrum, music,
tasks, calendar, and settings.
```

For implementation details, see [Runtime Notes](runtime-notes.md).

## Dock

```text
Position: bottom by default; supports left, right, top, and bottom.
Regions: three independent areas, aligned Left/Center/Right on horizontal docks
or Top/Center/Bottom on vertical docks.
Each region accepts any component, Pinned apps, and Running apps in any order.
For example, Region 1 can contain Workspaces, Running apps, and Time together.
App blocks expand into their app/window icons; drag those icons to reorder
within their block without moving the surrounding components.
Ungroup windows shows one icon per window and defaults to false.

Existing group visibility/order and component placement are imported when
dock-layout is absent. The first layout edit saves the new format; the legacy
files remain available. Each item has exactly one region or Hidden/Quick location.
```

## Components and Opacity

```text
Settings -> Dock Layout:
Region 1/2/3: items directly on that part of the dock
Hidden:       not shown
Quick menu:   inside the Components popup

Cards show icons and names. Click a card to choose its destination, or drag to
move/reorder it. Dragging near the viewport edge scrolls the layout editor.
Settings -> Dock also links to the layout editor, alongside position, ungrouping,
and dock opacity. Pinned apps and Running apps can be hidden and restored like
other items. Settings always remains on the dock, in any region.

Sound, Brightness, Battery, and Key Visualizer start in Quick.
Pinned apps, Running apps, Workspaces, Date, Time, Daily Key Count, and the Quick
menu button cannot move to Quick.

Workspaces starts on the dock: transparent dots, with a white capsule for
the active workspace. Click a dot to switch. It follows keyboard/Overview changes,
dynamic workspace counts, and all four dock sides. Settings can reorder or hide
it; overflow exposes individual workspace actions when dock space is limited.

Settings -> Opacity: drag surfaces between Opacity and Default; range 0-100%.
Settings and Screenshots can move between these lists.
Screenshots appears only here and defaults to opacity, affecting browser and previews.
Preview controls, text, icons, other controls, the dock, and Shell popups stay opaque.
```

## Wi-Fi and Bluetooth

```text
Both panels have a radio summary, an available list, and Details.
Opening a panel uses cached results without starting discovery. Successfully
turning a radio on starts discovery; Refresh scans again, and Settings opens
system connection settings.

Hero icons show radar rings and a counterclockwise orbit, faster while working.
Turning the radio off fades and stops the animation.
Tabs slide/fade; list rows enter in sequence.
Pending actions show a spinner and disable conflicting controls.
Empty lists show an animated search icon until discovery and delayed results finish.

Wi-Fi requests a password when needed, locks input during connection, and allows
another attempt after an error.
```

## Desktop Controls

```text
Sound:        independent mic/speaker mute and 0-100% sliders; follows GNOME mixer
Brightness:   GNOME brightness manager, with ddcutil fallback
Battery:      UPower percentage, charging state, and remaining/full-charge time
Input Source: current language code; opens a compact language switcher
Date & Time:  dock labels; open Settings -> Date & Time, including from overflow
Key Count:    selected statistic, e.g. `keys:7d:1,234`; click for the range popup
Connections:  crossed-out icons when radios are off; Wi-Fi shows weak/medium/strong signal
              power changes push an immediate status refresh to the dock

Unavailable audio/brightness controls are disabled; missing batteries show unavailable.
```

## Key Visualizer

```text
Floating key bubble; recent keys clear after five seconds.
Settings: font size, Padding X/Y, fit/fixed width, min/max width, and text alignment.

Font, padding, or alignment changes show hello ␣ world for five seconds.
The next typed key replaces the preview. Legacy padding initializes both axes.
English/Thai global input requires GNOME AT-SPI or readable Linux input devices.
Without permission, keys are captured only while focused.

Daily Key Count runs with the dock and resets when the local date changes. Its
capture path emits only press markers; persisted state contains only dates and daily
counts, never key names, modifiers, or typed text. Holding a key counts once until
that key is released and pressed again. The popup summarizes today, 7/15 days,
this month, rolling 3/6 months,
this year, the best day, and all time. Its text-only rows select which total is
shown on the dock; hovering a popup row changes its text color without a
background or animation.
```

## Spectrum

```text
Settings -> Spectrum: enable the edge spectrum, choose its edge and bar length.
Bar length: sm (54 px), md (108 px), lg (161 px; original default).
Changes apply live and persist. Bar width, spacing, and the edge baseline stay fixed.
```

## Tasks

```text
Local checklist: add, edit, toggle, delete, and drag-to-reorder.
Items persist until deleted and do not expire when the date changes.
```

## Screenshots

```text
Edge handle on the primary monitor; watches Pictures/Screenshots, newest first.
A configurable Show Desktop handle toggles the same saved window snapshot as
the dock button and Super+0. It supports every screen edge and sm/md/lg width
and height. Both handles can be distributed across three position zones. Drag
either card between Top/Center/Bottom on a
vertical edge or Left/Center/Right on a horizontal edge; dragging within one
zone changes their order. The editor uses the Dock Layout card colors, icon tiles,
hover borders, and drag placeholders. Dragging near the viewport edge scrolls the
list; canceling or dropping outside it keeps the saved layout.
Items in the same zone form a centered group with an
8 px gap. On the Dock
edge both handles sit against the Dock's inner boundary.
Click: select; Ctrl-click: toggle; Shift-click: range; drag: covered thumbnails.
Ctrl+A selects all. Ctrl+C copies absolute paths.

Double-click opens a resizable preview and hides the browser.
Delete moves files to .zhyprbola-trash; Ctrl+Z restores the latest deletion.
Restore never overwrites files. Trash is not purged automatically.
```

## Settings

```text
Sidebar order: Date & Time, Dock, Dock Layout, Edge Handles, Keys, Opacity,
Spectrum, Themes, Wallpaper.

When adding or renaming a section in components/SettingsPanel.qml, sort A-Z
by displayed English label. Keep heading and page mappings synchronized.
```

## Commands

```bash
make build                        # Build without installing the extension
make dock                         # Build, install, and enable the dock
./scripts/run-panel wifi           # Run a focused panel
./scripts/run-panel bluetooth
./scripts/run-panel key-visualizer
./scripts/run-panel settings
make check                        # QML lint; existing warnings may be printed

# Other panel names: clock-weather, system-status, audio-spectrum, sound,
# tasks, calendar, music, screenshots
```

## Integrations

```text
Wi-Fi: nmcli / NetworkManager          Bluetooth: bluetoothctl / BlueZ
Media: MPRIS, optional playerctl       Sound: GNOME mixer
Brightness: GNOME, optional ddcutil    Battery: UPower
Spectrum: cava                        Weather: Open-Meteo
```

## Configuration

```text
Directory: ~/.config/zhyprbola/

Filename                      Purpose / default
----------------------------  -----------------------------------------------
theme                         theme
component-opacity             QML opacity (0-100, default 100)
component-opacity-components  surfaces using QML opacity
dock-position                 dock edge
dock-bg-opacity               dock background opacity (0-100, default 50)
dock-layout                   ordered region items, Hidden, and Quick (JSON)
dock-groups                   legacy group visibility, imported on first use
dock-group-order              legacy region order, imported on first use
dock-components               legacy Show/Hidden/Quick layout, imported on first use
dock-ungroup-windows          one icon per window (default false)
pinned-apps                   desktop IDs, used by the Pinned apps block
use-wallpaper                 wallpaper toggle
tasks.json                    checklist
key-visualizer                appearance JSON

Key JSON: fontSize, paddingX, paddingY, widthMode, minWidth, maxWidth, alignment.
Padding accepts sm/md/lg; legacy padding fills axes not saved separately.
```
