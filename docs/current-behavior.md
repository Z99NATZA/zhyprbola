# Current Behavior

```text
Flow: GNOME dock extension -> focused QML panels
Panels: bluetooth, wifi, clock-weather
Theme: ~/.config/zhyprbola/theme
```

## Commands

```bash
# install/update the dock
make dock

# run panels directly while developing
./scripts/run-panel bluetooth
./scripts/run-panel wifi
./scripts/run-panel clock-weather
```

## Integrations

```text
Wi-Fi:      nmcli / NetworkManager
Bluetooth:  bluetoothctl / BlueZ
Media:      MPRIS, optional playerctl
Spectrum:   cava
Weather:    Open-Meteo
```

## Weather

```bash
ZPOLA_LATITUDE=13.7563 ZPOLA_LONGITUDE=100.5018 ZPOLA_LOCATION=Bangkok make dock
```
