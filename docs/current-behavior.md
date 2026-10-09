# Current Behavior

```text
Flow: GNOME dock extension -> focused QML panels
Panels: bluetooth, wifi, clock-weather, key-visualizer, system-status, audio-spectrum
Dock popups: sound, brightness, battery
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
Key visualizer: ~/.config/zhyprbola/key-visualizer (font size, padding, width, alignment)
Padding: sm uses 4 px around the text; md keeps the original spacing; lg adds 12 px.
Width −/+ buttons change by 20 px, repeat after a 400 ms hold, and accelerate to 25 steps/s.
Evdev capture tracks held keys per device, resyncs after dropped events/disconnects, and reads Caps/Num Lock LEDs.
Evdev merges keyboard streams by event timestamp and suppresses mirrored key-downs.
Held keys repeat using GNOME delay/interval settings until released, including Backspace and shortcuts; modifier keys themselves are hidden.
Typed characters appear together; special keys and shortcuts have spaces around them (hello ␣ world Ctrl+a ⌫). Repeated letter shortcuts appear as one run (Ctrl+kkkk).
```

Dock regions:

```text
Region 1: empty
Regions are ordered by dock-group-order and may contain Apps launchers, running applications, or Zhyprbola component buttons.
```

When ungroup windows is enabled, running apps render one icon per window.
Dragged window order survives focus/title changes and temporary app-tracker omissions;
positions are removed only when the windows close. New windows append to the order.
Running apps include open windows even when the app also appears in Apps.
Right-click an Apps or Running icon to open GNOME's app menu, including open
windows, New Window, desktop actions, and Quit when supported by the app.
The keyboard menu key / Shift+F10 opens the same menu. Pin to Dash is omitted
because this dock keeps its Apps launchers in its own pinned-apps config.
The Show Desktop strip hides visible, minimizable windows on the current
workspace first, excluding Zhyprbola panels. When no such windows are visible,
it restores the windows it hid on that workspace. Hide history is retained per
workspace, including windows still hidden after a partial manual restore.
Windows minimized before Show Desktop was used remain minimized.
The Sound component appears in Quick by default and can be moved through
Settings. It opens a Shell popup like Quick Components, with microphone and
speaker icons, volume sliders (0–100%), and independent mute controls. It uses
GNOME's shared mixer and follows device and volume changes immediately.
Unavailable devices disable their controls. Dock and Settings actions never
launch a separate Sound window; the standalone development panel remains
available through `scripts/run-panel sound`.
Brightness is a Shell popup with a sun icon and a single slider row, using the
same dimensions, spacing, and colors as Sound. It uses GNOME's shared brightness
manager on supported backlights. Otherwise it uses `ddcutil` to control brightness
on the first detected DDC/CI display. DDC commands run asynchronously, combine
rapid slider changes, and use the display's reported maximum. Opening the menu
refreshes the hardware value; monitor changes trigger rediscovery. It defaults to
Quick Components and can be moved to Show or Hidden in Settings. Unavailable
displays show a dimmed, disabled row. DDC/CI requires `ddcutil` and user access to
the display's I2C device (normally granted by the package's udev rules).

Dock popups open only through explicit activation. Hovering over another dock
button or moving keyboard focus does not switch the currently open popup.
The Input Source dock component shows the current language code such as `en`
or `th` and opens a language-only switcher menu.
The Date and Time dock labels open Settings directly to Date & Time, including
when Settings is already open or the labels are in the dock overflow menu.
The Settings icon always stays in Show; it can be reordered there but cannot be
moved to Hidden or Quick. Older layouts with Settings elsewhere are restored to Show.
The Key Visualizer opens a floating bubble from Quick by default.
Settings > Keys controls font size, min/max width, fit or fixed width, and text
alignment. It shows the latest keys only and clears after five seconds. It can
read English and Thai keys typed in other applications through GNOME AT-SPI
when authorized, or directly from readable Linux keyboard input devices.
GNOME 50 on Wayland can deny AT-SPI monitoring; run
`./scripts/grant-key-capture` to grant temporary read access to keyboard
devices, then reopen the bubble. Without either permission it shows keys only
while focused. The capture helper stops when the bubble is minimized. Device
access lasts until reboot or device reconnect, and any process under the same
user can read those devices while the permission is active. Typed secrets can
appear in the bubble; minimize it before entering passwords.
The Tasks panel stores local checklist items, supports add/edit/toggle/delete
and drag reorder, and never deletes tasks automatically when the date changes.

## Commands

The Screenshots browser opens from a 5 × 100 px handle on the primary monitor's
edge. Settings → Screenshots selects Left/Right and Top/Center/Bottom; changes
apply immediately. The three positions use space-around spacing, with centers
at 1/6, 1/2, and 5/6 of the screen height. The browser opens beside the handle,
clamped vertically to the work area, expands from the small handle without
blocking other windows or staying above them, uses the same theme surface, text,
and controls as other components, and reads
`Pictures/Screenshots`, shows thumbnails newest first, and updates when files
change. Click selects one image, Ctrl-click toggles it, and Shift-click selects a
range. Dragging a rectangle from a thumbnail or the blank gutter selects the
images it covers. The Select all button toggles between selecting and clearing
all images; Ctrl+A selects all. Ctrl+C copies selected absolute paths as newline
separated text. Double-clicking a thumbnail opens a transparent, borderless,
resizable image preview with a close icon 20 px from the displayed image's
top-right edge.
The preview closes when the browser hides. The bottom-right Delete button
or Delete key moves selected files
into `.zhyprbola-trash` inside the
screenshots directory. Ctrl+Z restores the last deletion, including after reopening
the browser. Restore never overwrites an existing file. Clicking outside, Escape,
or another click on the edge hides the browser; there is no close button. The
GNOME handle stays visible even in fullscreen. Screenshots uses a single resident
QML process controlled through D-Bus, without loading other component backends.
Hiding preserves its model, selection, clipboard owner, and thumbnail cache.
Rapid reopen cancels an older collapse; disabling the extension stops only its
browser and handle. The scrollbar has reserved space and appears only when the
list overflows. Deletion does not ask for confirmation. Undo storage is retained until restored; it is not
automatically purged.

```bash
# install/update the dock
make dock

# run panels directly while developing
./scripts/run-panel bluetooth
./scripts/run-panel wifi
./scripts/run-panel clock-weather
./scripts/run-panel key-visualizer
./scripts/run-panel system-status
./scripts/run-panel audio-spectrum
./scripts/run-panel sound
./scripts/run-panel tasks
./scripts/run-panel screenshots
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

## Settings Navigation

Keep the sidebar sections in `components/SettingsPanel.qml` ordered alphabetically
by their displayed English labels (case-insensitive). Insert new entries in that
order and keep their page content and heading mappings in sync.

## Wallpapers

```text
Files: gnome-extension/wallpapers/1.png ... 8.png
Themes: Purple -> 1.png, White Mist -> 2.png, White Sky -> 3.png,
        Forest Calm -> 4.png, One Half Gray -> 5.png, Red -> 6.png,
        Mauve -> 7.png, Silver Dawn -> 8.png
Silver Dawn: silver-blue/lavender palette with the supplied morning bedroom wallpaper.
```

## Weather

```bash
ZHYPRBOLA_LATITUDE=13.7563 ZHYPRBOLA_LONGITUDE=100.5018 ZHYPRBOLA_LOCATION=Bangkok make dock
```
