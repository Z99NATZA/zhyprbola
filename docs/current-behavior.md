# Current Behavior

```text
Flow: GNOME dock extension -> focused QML panels
Panels: bluetooth, wifi, clock-weather, system-status, audio-spectrum
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

## Wallpapers

```text
Files: gnome-extension/wallpapers/1.png ... 6.png
Themes: 1. Purple -> 1.png, 2. White Mist -> 2.png, etc.
```

## Weather

```bash
ZHYPRBOLA_LATITUDE=13.7563 ZHYPRBOLA_LONGITUDE=100.5018 ZHYPRBOLA_LOCATION=Bangkok make dock
```
