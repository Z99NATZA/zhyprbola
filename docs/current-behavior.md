# Current Behavior

```text
Flow: GNOME dock extension -> focused QML panels
Panels: bluetooth, wifi, clock-weather, system-status, audio-spectrum
Theme: ~/.config/zhyprbola/theme
Dock position: ~/.config/zhyprbola/dock-position
Dock default: bottom
Dock BG opacity: ~/.config/zhyprbola/dock-bg-opacity (0-100%, default 50%; background only)
Dock groups: ~/.config/zhyprbola/dock-groups (enabled groups)
Dock group order: ~/.config/zhyprbola/dock-group-order (drag cards in Settings; apps/running order the shared launcher region)
Pinned apps: ~/.config/zhyprbola/pinned-apps (desktop IDs, one per line)
Wallpaper toggle: ~/.config/zhyprbola/use-wallpaper
```

Dock regions:

```text
Region 1: empty
Region 2: apps + running, adjacent and ordered by dock-group-order
Region 3: Zhyprbola component buttons
```

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
