# Zpola desktop

A single Qt Quick window assembled from the QML components in `../zqmlcomponents`.

Run with Qt 6 development packages and `qmake6` installed. Music integration
uses MPRIS over DBus and can also use `playerctl` when it is installed; `cava`
enables the audio spectrum:

```sh
make run
```

Run the focused panel host used by the GNOME sidebar dock MVP:

```sh
make run-panel
./scripts/run-panel bluetooth
./scripts/run-panel wifi
```

Build, install, and enable the local GNOME dock extension:

```sh
make dock
```

On a first install, GNOME may need a logout and login before it recognizes the
extension. `make dock` enables it for the next login automatically.

The extension creates a configurable sidebar dock with Bluetooth, Wi-Fi, and
Theme buttons. Clicking a panel button again raises its existing window instead
of opening another copy. Theme opens a GNOME Shell menu with Purple, White Mist,
White Sky, and Forest Calm palettes. Each palette uses a white surface,
a primary color, and pale secondary controls. The choice is saved in
`~/.config/zhyprbola/theme`
and updates open QML windows. The dock defaults to the right edge, but its
placement is kept as a small config in `gnome-extension/extension.js` so it can
later support left, right, top, and bottom positions.

Wi-Fi networks connect or disconnect through explicit buttons. Saved networks reuse their
NetworkManager profile; new secured networks ask for a password in the panel.
Enterprise networks open the system Wi-Fi settings for setup.

`Main.qml` places the bar and cards in a transparent, maximized window so the
desktop wallpaper remains visible behind them. The dock component is kept in
`components/` but is hidden from this layout. The component files are local
copies converted from standalone windows to reusable `Item` components.
Narrow windows can scroll to reach every card.

CPU, memory, and disk data come from the local system. Weather comes from
[Open-Meteo](https://open-meteo.com/en/docs) and defaults to Bangkok. Set
`ZPOLA_LATITUDE`, `ZPOLA_LONGITUDE`, and `ZPOLA_LOCATION` to change the
weather location. The music card follows the active MPRIS player and uses
`playerctl` when it is available; its playback, track, and seek controls work
when a player is available. The top bar reads Wi-Fi status from NetworkManager
through `nmcli` and Bluetooth status from BlueZ through `bluetoothctl`.
Available app icons launch local programs. Todo and Calendar retain their
existing behavior. The full-width spectrum along the bottom reads live audio
levels from `cava`; when it is unavailable, it stays at a quiet baseline.
