# Current Behavior

```text
Flow: GNOME dock extension -> focused QML panels
Panels: bluetooth, wifi, clock-weather, system-status
Theme: ~/.config/zhyprbola/theme
Dock position: ~/.config/zhyprbola/dock-position
Dock default: left
Wallpaper toggle: ~/.config/zhyprbola/use-wallpaper
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
```

## Integrations

```text
Wi-Fi:      nmcli / NetworkManager
Bluetooth:  bluetoothctl / BlueZ
Media:      MPRIS, optional playerctl
Spectrum:   cava
Weather:    Open-Meteo
```

## Wallpapers

```text
Files: gnome-extension/wallpapers/1.png ... 5.png
Themes: 1. Purple -> 1.png, 2. White Mist -> 2.png, etc.
```

## Weather

```bash
ZPOLA_LATITUDE=13.7563 ZPOLA_LONGITUDE=100.5018 ZPOLA_LOCATION=Bangkok make dock
```
