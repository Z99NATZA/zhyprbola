# Runtime Notes

```text
Read this when changing lifecycle, input, fallback, or layout code.
```

## Dock Activation

```text
GNOME can set org.gnome.shell disable-user-extensions=true after a Shell failure.
The dock then stays INITIALIZED even when its UUID is in enabled-extensions;
logging in again or enabling the individual extension does not clear this switch.
make dock and make dock-enable re-enable user extensions before activating the dock.
This also restores the user's other enabled extensions.

Activation checks use the C locale. ERROR and OUT OF DATE states fail immediately
and print the extension state with the command for inspecting Shell logs.
```

## Running Windows

```text
Focused QML hosts use one Loader for the requested component. Other component
trees are not constructed. The host becomes visible when that Loader is ready.
Radio hosts pass standalone/opened as initial Loader.setSource properties,
before anchors are evaluated. Changing standalone after creation can leave
the card outside the window when its original overlay anchors are removed.
Backend profiles start only the requested panel's services: system metrics,
Wi-Fi, Bluetooth, weather, music, or spectrum. Calendar, Tasks, Settings, and
Keys do not start those background services. Sound and screenshot backends
are constructed only by hosts that use them; Settings also needs screenshot
settings for its edge editor. The desktop host retains all services.

Radio and playerctl reads use asynchronous, bounded-time QProcess queries.
MPRIS fallback uses asynchronous ListNames and GetAll calls. Polling does not
overlap a previous refresh; explicit post-action refreshes wait for a fresh
snapshot before reporting power/scan/connect results. Failed reads retain the
last usable data. Opening a radio panel still does not start discovery.

Hiding or minimizing a focused host pauses its polling timers and cava;
restoring resumes them and refreshes data. The loaded component remains alive
so tasks, tabs, selection, and window state survive. Key capture follows the
same visibility lifecycle. Screenshots keeps its separate resident lifecycle.

The icon source is assets/zhyprbola-icon.svg, with a transparent exterior and
solid green/white/mint shapes. assets/zhyprbola-icon.md documents PNG export.
The Qt host embeds the 512 px PNG and uses app ID
org.zhyprbola.Zhyprbola. make install-app installs the matching user desktop
entry and both SVG/PNG icons; make dock, make run, and make run-panel include this step.
GNOME uses the desktop entry for the Overview, app switcher, and running app icon.

Running apps remain visible even when the same app exists in Apps.
Pinned apps and Running apps are movable blocks. Their ordered source items
expand into whichever region contains the block, alongside normal components.
Pinned and running instances of the same app retain separate buttons and menus.

In ungrouped mode, dragged order survives focus changes, title changes, and
temporary app-tracker omissions. A slot is removed only after its window closes.
New windows append to the saved order.

Right-click, the keyboard menu key, or Shift+F10 opens GNOME's app menu.
Supported actions include open windows, New Window, and desktop actions. Apps
and grouped Running items expose GNOME's app-scoped Quit action. An ungrouped
Running item replaces it with Close Window scoped to that item's window. Pin to
Dash is omitted because Zhyprbola owns its launcher configuration.
```

## Dock Region Sizing

```text
Regions start with equal shares of the monitor's logical width or height.
An overfull region borrows unused space from its closest neighbors, retaining
each donor's measured contents, inter-region spacing, and Show Desktop reserve.
This applies to app-only regions as well as inline text and mixed regions.
There is no fixed percentage cap; More appears only if the combined contents
and reserves exceed the dock's available length.

The middle group's offset targets the screen center and is clamped inside its
allocated region when neighboring groups need the space. Dock edges retain
their start/end alignment. Geometry changes also invalidate cached centering.

Overflow action labels set the theme color explicitly, as Input Source does,
because the GNOME theme may specify a contrasting popup-item foreground.
Overflow and Power share Input Source's row spacing and interaction colors.
All overflow component rows use their existing SVG icons and a fixed icon
column. A row releases pointer-acquired focus to the menu actor when hover
ends, preventing GNOME's :focus style from retaining the highlight. Keyboard
navigation can still focus rows without hovering.

Dock, Quick, and overflow share SVG sources by icon name and immutable GIcons
by icon name/color. Caches survive dock rebuilds and theme switches, and are
released when the extension is disabled. Each visible location owns its own
St.Icon actor; only the underlying icon data is shared. The wifi-strong state
uses wifi.svg rather than a second copy of the same artwork. QML Settings
already loads the same SVG assets directly.
```

## Component Minimize Animation

```text
Component panels use normal frameless windows so GNOME animates minimize and
restore using its standard animation and the system's motion preferences.
The animation targets the component's current dock button. Overflowed components
target More; Quick/hidden components target Components, then Settings. If those
buttons are unavailable, the dock center is used.

Targets update after dock layout and before dock/Settings toggles, including
after moving the dock to another edge or moving the component to another region.
Overflow targets More in the component's own region; popup sources are resolved
across all regions. Panel close buttons use the same target
through the native minimize lifecycle. Screenshots keeps its resident lifecycle.
```

## Show Desktop

```text
The first activation hides visible, minimizable windows on the current workspace.
The next activation restores only windows hidden by Zhyprbola.
The dock button, Show Desktop edge handle, and Super+0 invoke the same toggle action.
Minimize and restore animations target the current dock's center, including after
the dock moves to another screen edge.

Zhyprbola panels and previously minimized windows are ignored.
Hide state is stored per workspace. Each hide replaces that workspace's restore
snapshot, so windows already minimized at that moment stay minimized on restore.
Closed windows and windows moved to another workspace are skipped during restore.
```

## Popup Lifecycle

```bash
# Dock popups open only through explicit activation.
# Hover and keyboard focus do not switch the open popup.

# Sound, Brightness, and Battery remain Shell popups when opened from Settings,
# Quick, or overflow. They never spawn fallback QML windows.

# The standalone Sound panel remains available for development:
./scripts/run-panel sound
```

## Brightness Fallback

```text
The DDC fallback uses the first detected DDC/CI display and its reported maximum.
Commands run asynchronously and combine rapid slider changes.

Opening the popup refreshes the hardware value.
Monitor changes trigger display rediscovery.

DDC/CI requires ddcutil and access to the display's I2C device.
Package udev rules normally provide this access.
```

## Connection Discovery

```text
connectionActions publishes busy, action, message, and success for each radio.
Repeated power/scan requests are ignored while busy. Failed power-on does not scan.
Bluetooth power-on clears a soft rfkill block before asking BlueZ to enable the
controller. The observed controller state wins over a transient BlueZ Busy error.

Wi-Fi discovery requests a fresh list with nmcli dev wifi list --rescan yes.
Bluetooth discovery uses bluetoothctl --timeout 5 scan on.
Empty results are re-read every 500 ms for up to five seconds while powered.
Loading continues until results arrive or checks finish, then publishes the count.
Failed commands report an error.

QML shares RadioOrb, RadioPowerButton, and RadioDiscoveryStatus between panels.
Network and device connection buttons lock conflicting actions while pending.
```

## Key Capture

```bash
# Typed characters are grouped. Special keys and shortcuts receive spacing.
# Repeated letter shortcuts stay in one run.

# Held keys use GNOME's repeat delay and interval.
# Modifier keys are not displayed by themselves.

# Evdev capture:
# - tracks held keys per device
# - merges events by timestamp
# - suppresses mirrored key-downs
# - reads Caps Lock and Num Lock LEDs
# - resyncs after dropped events or disconnects
# - stops when the visualizer is minimized

# GNOME 50 on Wayland may deny AT-SPI monitoring.
# Grant temporary read access, then reopen the visualizer:

./scripts/grant-key-capture

# Access ends after reboot or device reconnect.

# Keyboard access is sensitive. Other processes running as the same user may read
# the granted devices, and typed secrets can appear in the bubble. Minimize the
# visualizer before entering passwords.
```

## Screenshots Lifecycle

```text
Settings -> Screenshots selects Left or Right; its draggable layout zones choose
Top, Center, or Bottom. Single handles center at 1/6, 1/2, or 5/6 of the edge.
The 5 x 100 px handle stays visible in fullscreen.
A Show Desktop handle also stays visible in fullscreen. Its width presets are
5/8/12 px and height presets are 50/75/100 px; horizontal edges rotate those
dimensions. It can use any screen edge. On the Dock edge it is inset by the
Dock thickness so it sits against the Dock's inner boundary. When both handles
share an edge and position zone, they form a centered group with an 8 px gap. Settings
provides draggable Top/Center/Bottom zones for vertical edges and
Left/Center/Right zones for horizontal edges; card order is also persisted.
Before a setting is saved, both handles share the Center zone, with Screenshots
first and Show Desktop at 5 x 50 px.

The browser opens beside the handle and remains inside the work area.
Clicking outside, pressing Escape, or activating the handle again hides it.

One resident QML process is controlled through D-Bus.
Hiding preserves its model, selection, clipboard owner, and thumbnail cache.

The preview is transparent, borderless, and resizable.
Its initial window fits the image aspect ratio within 660 x 510 px and
85% of the screen, without upscaling the original image.
Dragging the image moves the window. The resize handle is at the window's
bottom-right corner and preserves the image aspect ratio while dragging.
Each double-click opens a separate preview, including for the same image,
and hides the browser. Closing one preview leaves the others open.
Escape or the close icon closes a preview; the browser stays hidden.
Browser show/hide does not close previews.
Close and resize icons appear on hover and hide after 100 ms outside.
Returning cancels the hide. The close icon stays 20 px from the image corner.

Deletion has no confirmation.
Undo data remains in .zhyprbola-trash until restored and is not purged automatically.
A rapid reopen cancels an older collapse.
Disabling the extension stops only the browser and its handle.
```

## Settings Layout

See [Settings ordering](current-behavior.md#settings) when adding or renaming sections.

```text
New Settings windows open beside the trailing end of the region containing
Settings, with a 12 px gap and 12 px work-area margin. Legacy layouts use region 3.
With the default bottom dock, Settings opens above its right-hand end.
Reopening an existing Settings window preserves its position.

Content row:          46 px
Gap within a group:    8 px
Gap between groups:   16 px

Key font sizes: sm 23 px, md 30 px, lg 38 px.

Padding X changes left/right spacing without changing height:
sm:   4 px per side
md:  20 px per side, or 24 px with lg font
lg:  md spacing + 12 px per side

Padding Y changes top/bottom spacing without changing width:
sm:  text height + 4 px per side
md:  default key-area height: sm font 64 px, md 78 px, lg 96 px
lg:  default key-area height + 24 px

Key width buttons change by 20 px.
Holding starts repeat after 400 ms and accelerates to 25 steps per second.

```

## Wallpapers

```text
Purple          -> wallpapers/1.png
White Mist      -> wallpapers/2.png
White Sky       -> wallpapers/3.png
Forest Calm     -> wallpapers/4.png
One Half Gray   -> wallpapers/5.png
Red             -> wallpapers/6.png
Sakura          -> wallpapers/7.png
Silver Dawn     -> wallpapers/8.png

Silver Dawn uses a silver-blue and lavender palette with the supplied morning
bedroom wallpaper.
```

## Weather Override

```bash
ZHYPRBOLA_LATITUDE=13.7563 \
ZHYPRBOLA_LONGITUDE=100.5018 \
ZHYPRBOLA_LOCATION=Bangkok \
make dock
```
