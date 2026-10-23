# App icon

`zhyprbola-icon.svg` is the editable source, drawn to match the emblem in the
README banner. It contains a rounded green square and two opposing round-capped
curves. The exterior is transparent; every shape is fully opaque.

- Canvas: 512 × 512; equal 36 px margins.
- Tile: 440 × 440; 80 px corner radius; forest green `#477f6d`.
- Curves: 36 px strokes; white `#ffffff` and mint `#d9ede3`.

The desktop installer supplies the SVG for scalable icons and the PNG for raster
icons. Qt embeds the PNG, so the application does not need an SVG icon plugin.
The PNG is committed; ordinary builds do not require the SVG exporter.

After editing the SVG, export the PNG with librsvg/Cairo:

```bash
# Optional development dependencies for the exporter (Debian/Ubuntu)
sudo apt install python3-gi python3-cairo gir1.2-rsvg-2.0
./scripts/render-app-icon
make install-app
```

Cairo renders smooth alpha edges directly from the vector geometry. No color-key
background removal is used. The README banner remains unchanged.
