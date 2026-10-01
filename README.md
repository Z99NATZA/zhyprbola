# Zpola desktop

A single Qt Quick window assembled from the QML components in `../zqmlcomponents`.

Run with Qt 6 development packages and `qmake6` installed. `playerctl` enables
music integration; `cava` enables the audio spectrum:

```sh
make run
```

`Main.qml` places the bar and cards in a transparent, maximized window so the
desktop wallpaper remains visible behind them. The dock component is kept in
`components/` but is hidden from this layout. The component files are local
copies converted from standalone windows to reusable `Item` components.
Narrow windows can scroll to reach every card.

CPU, memory, and disk data come from the local system. Weather comes from
[Open-Meteo](https://open-meteo.com/en/docs) and defaults to Bangkok. Set
`ZPOLA_LATITUDE`, `ZPOLA_LONGITUDE`, and `ZPOLA_LOCATION` to change the
weather location. The music card follows the active MPRIS player through
`playerctl`; its playback, track, and seek controls work when a player is
available. Available app icons launch local programs. Todo and Calendar retain
their existing behavior. The full-width spectrum along the bottom reads live
audio levels from `cava`; when it is unavailable, it stays at a quiet baseline.
