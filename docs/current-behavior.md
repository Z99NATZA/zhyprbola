# Current Behavior

```text
Flow: GNOME dock extension -> focused QML panels
Panels: bluetooth, wifi, clock-weather, system-status, audio-spectrum
Theme: ~/.config/zhyprbola/theme
Dock position: ~/.config/zhyprbola/dock-position
Dock default: bottom
Dock BG opacity: ~/.config/zhyprbola/dock-bg-opacity (0-100%, default 50%; background only)
Dock groups: ~/.config/zhyprbola/dock-groups (enabled groups)
Dock group order: ~/.config/zhyprbola/dock-group-order (drag cards in Settings; disabled groups still keep an order slot)
Ungroup windows: ~/.config/zhyprbola/dock-ungroup-windows (true/false, default false)
Pinned apps: ~/.config/zhyprbola/pinned-apps (desktop IDs, one per line; shown only when Apps is enabled)
Wallpaper toggle: ~/.config/zhyprbola/use-wallpaper
Tasks: ~/.config/zhyprbola/tasks.json (local checklist; items remain until manually deleted)
```

Dock regions:

```text
Region 1: empty
Regions are ordered by dock-group-order and may contain Apps launchers, running applications, or Zhyprbola component buttons.
```

When ungroup windows is enabled, running apps render one icon per window.
Running apps include open windows even when the app also appears in Apps.
The Show Desktop strip hides visible, minimizable windows on the current
workspace first, excluding Zhyprbola panels. When no such windows are visible,
it restores the windows it hid on that workspace. Hide history is retained per
workspace, including windows still hidden after a partial manual restore.
Windows minimized before Show Desktop was used remain minimized.
The Input Source dock component shows the current language code such as `en`
or `th` and opens a language-only switcher menu.
The Tasks panel stores local checklist items, supports add/edit/toggle/delete
and drag reorder, and never deletes tasks automatically when the date changes.

## Commands

```bash
# install/update the dock
make dock

# run panels directly while developing
./scripts/run-panel bluetooth
./scripts/run-panel wifi
./scripts/run-panel clock-weather
./scripts/run-panel system-status
./scripts/run-panel audio-spectrum
./scripts/run-panel tasks
```

## Integrations

```text
Wi-Fi:      nmcli / NetworkManager
Bluetooth:  bluetoothctl / BlueZ
Media:      MPRIS, optional playerctl
Spectrum:   cava
Weather:    Open-Meteo
```

## Settings Spacing

```text
Content row height: 46 px
Gap within one group: 8 px (theme choices, dock group switches, spectrum edge choices)
Gap between groups: 16 px (dock position / group order / switches / BG opacity, spectrum toggle / edge choices, component Show / Hidden)
These gaps are between controls; padding inside a control is separate.
```

## Wallpapers

```text
Files: gnome-extension/wallpapers/1.png ... 6.png
Themes: 1. Purple -> 1.png, 2. White Mist -> 2.png, etc.
```

## Weather

```bash
ZHYPRBOLA_LATITUDE=13.7563 ZHYPRBOLA_LONGITUDE=100.5018 ZHYPRBOLA_LOCATION=Bangkok make dock
```
