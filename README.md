# Zpola desktop

A single Qt Quick window assembled from the QML components in `../zqmlcomponents`.

Run with Qt 6 and its QML runtime installed:

```sh
make run
```

`Main.qml` places the bar and cards in a transparent, maximized window so the
desktop wallpaper remains visible behind them. The dock component is kept in
`components/` but is hidden from this layout. The component files are local
copies converted from standalone windows to reusable `Item` components.
Narrow windows can scroll to reach every card.

The music, app, dock, and system data still use the demo values and placeholder
actions supplied by the source components.
