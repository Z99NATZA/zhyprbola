# Current Behavior

```text
Zhyprbola combines a GNOME Shell dock with focused Qt/QML panels.
Shell handles sound, brightness, and battery popups; Screenshots is a resident QML browser.
Other QML panels cover connections, clock, weather, keys, status, spectrum, music,
tasks, notes, calendar, and settings.
Each focused host loads only its requested component and starts only its needed
data services. Data refreshes asynchronously; hiding/minimizing pauses polling
and spectrum while retaining the component for a quick restore.
```

For implementation details, see [Runtime Notes](runtime-notes.md).

## Dock

```text
Position: bottom by default; supports left, right, top, and bottom.
Regions: three independent areas, aligned Left/Center/Right on horizontal docks
or Top/Center/Bottom on vertical docks.
Each region accepts any component, Pinned apps, and Running apps in any order.
Regions borrow unused space from neighbors before moving items into More (⋮).
Overflow remains when the dock cannot fit all items. The middle group stays
centered on the screen while neighboring groups leave enough room.
For example, Region 1 can contain Workspaces, Running apps, and Time together.
App blocks expand into their app/window icons; drag those icons to reorder
within their block without moving the surrounding components.
Ungroup windows shows one icon per window and defaults to false.

Existing group visibility/order and component placement are imported when
dock-layout is absent. The first layout edit saves the new format; the legacy
files remain available. Each item has exactly one region or Hidden/Quick location.
```

## Clock and Weather

```text
Clock and Weather are independent cards and dock launchers, with separate
visibility, placement, and opacity settings. Clock displays time with seconds
and the date; Weather displays current conditions, high/low, and location.
Only the Weather host starts weather polling. Existing clock-weather placement
and opacity preferences apply to both new cards. The legacy clock-weather
panel command remains available as a side-by-side compatibility view.
```

## Components and Opacity

```text
Settings -> Dock Layout:
Region 1/2/3: items directly on that part of the dock
Hidden:       not shown
Quick menu:   inside the Components popup

Cards show icons and names. Click a card to choose its destination, or drag to
move/reorder it. Dragging near the viewport edge scrolls the layout editor.
Settings -> Dock also links to the layout editor, alongside position, ungrouping,
and dock opacity. Pinned apps and Running apps can be hidden and restored like
other items. Settings always remains on the dock, in any region.

Sound, Brightness, Battery, and Key Visualizer start in Quick.
Pinned apps, Running apps, Workspaces, Date, Time, Daily Key Count, and the Quick
menu button cannot move to Quick.

Workspaces starts on the dock: transparent dots, with a white capsule for
the active workspace. Click a dot to switch. It follows keyboard/Overview changes,
dynamic workspace counts, and all four dock sides. Settings can reorder or hide
it; overflow exposes individual workspace actions when dock space is limited.
More and Power use the same light surface, theme-colored text, rounded rows,
and hover/keyboard-focus colors as Input Source.
More shows each component's icon, including inline date/time, key count,
workspaces, and input source, with aligned labels. Pointer highlights clear
when the pointer leaves a row; keyboard navigation still highlights its focus.

Settings -> Opacity: drag surfaces between Opacity and Default; range 0-100%.
Settings and Screenshots can move between these lists.
Screenshots appears only here and defaults to opacity, affecting browser and previews.
Preview controls, text, icons, other controls, the dock, and Shell popups stay opaque.
```

## Wi-Fi and Bluetooth

```text
Both panels have a radio summary, an available list, and Details.
Opening a panel uses cached results without starting discovery. Successfully
turning a radio on starts discovery; Refresh scans again, and Settings opens
system connection settings.

Hero icons show radar rings and a counterclockwise orbit, faster while working.
Turning the radio off fades and stops the animation.
Tabs slide/fade; list rows enter in sequence.
Pending actions show a spinner and disable conflicting controls.
Empty lists show an animated search icon until discovery and delayed results finish.

Wi-Fi requests a password when needed, locks input during connection, and allows
another attempt after an error.
```

## Desktop Controls

```text
Sound:        independent mic/speaker mute and 0-100% sliders; follows GNOME mixer
Brightness:   GNOME brightness manager, with ddcutil fallback
Battery:      UPower percentage, charging state, and remaining/full-charge time
Input Source: current language code; opens a compact language switcher
Date & Time:  dock labels; open Settings -> Date & Time, including from overflow
Key Count:    selected statistic, e.g. `keys:7d:1,234`; click for the range popup
Connections:  crossed-out icons when radios are off; Wi-Fi shows weak/medium/strong signal
              power changes push an immediate status refresh to the dock

Unavailable audio/brightness controls are disabled; missing batteries show unavailable.
```

## Key Visualizer

```text
Floating key bubble shown on every workspace; typed keys stay until newer keys push them out.
Settings: font size, Padding X/Y, and text alignment.
Drag the bubble's left or right edge to set its width (minimum 200 px); the
cursor changes near an edge, with no visible handle. The width persists.

Font, padding, or alignment changes show hello ␣ world for five seconds, then
the earlier keys return. Typing ends the preview and continues the earlier keys. Legacy padding initializes both axes.
English/Thai global input requires GNOME AT-SPI or readable Linux input devices.
Without permission, keys are captured only while focused.

Daily Key Count runs with the dock and resets when the local date changes. Its
capture path emits only press markers; persisted state contains only dates and daily
counts, never key names, modifiers, or typed text. Holding a key counts once until
that key is released and pressed again. The popup summarizes today, 7/15 days,
this month, rolling 3/6 months,
this year, the best day, and all time. Its text-only rows select which total is
shown on the dock; hovering a popup row changes its text color without a
background or animation.
```

## Spectrum

```text
Settings -> Spectrum: enable the edge spectrum, choose its edge and bar length.
Bar length: sm (54 px), md (108 px), lg (161 px; original default).
Style: bars (default) or wave (one gap-free filled shape; neighbouring bars merge
about every 48 px and join with smooth curves). Saved as edge-spectrum-style.
Changes apply live and persist. Bar width, spacing, and the edge baseline stay fixed.
Bars move only where a bin rises above the recent average (~200 ms running
mean), so the strip bounces at a few points. The music player and spectrum
bubble bars work the same way (sensitivity 2.6 and 1.8). Every spectrum runs
cava with noise_reduction 30 (cava's default is 77) and quick rise/fall
(30/70 ms) so it follows the beat.
```

## Tasks

```text
Local checklist: add, edit, toggle, delete, and drag-to-reorder.
Items persist until deleted and do not expire when the date changes.

The Vim switch before the task counter is off by default and remembers its state.
Normal mode highlights the selected task and shows a block cursor. j/k select
tasks, and Alt+j/Alt+k (or Alt+Down/Up) move the selected task down/up; h/l, 0/$, and b/w move through its text. i inserts before the cursor,
a inserts after it, and A appends at the end of the text. ciw changes the word
under the cursor, C changes through the end, r replaces one character, and R
replaces continuously (Backspace restores replaced characters). Escape saves
the edit and returns to normal mode. x deletes the character under the cursor
(the last character of a task is kept). dd immediately deletes the selected task;
Space or Enter toggles completion. Mouse editing and reordering remain available.
Clicking away or switching windows saves the draft and clears the row highlight
and cursor; clicking a task resumes Vim navigation.
With Vim off, text fields keep their standard typing and Escape behavior.
Undo/redo shares one history for list and text changes (add, edit, toggle,
reorder, delete): u or Ctrl+Z undoes, Ctrl+R (Vim), Ctrl+Shift+Z, or Ctrl+Y
redoes. An undone delete restores the same task with its done state and
position; in Vim mode the step selects its task and puts the cursor on the
changed text. A Vim insert or replace counts as one step when it ends. While
typing in a text field, Ctrl+Z undoes that field instead. The history lasts
until the panel restarts.
```

## Note

```text
Plain-text editor for .txt and .md files, laid out like a terminal window. The
tab strip shows one tab per file (a dot marks unsaved edits) with a close × on
each, a + after the last tab, and minimize, maximize, and close buttons on the
right. Tabs scroll sideways when they outgrow the bar. Drag the empty strip to
move the window; double-click it to maximize.

Tabs: click to switch, middle-click or × to close. Closing a tab with unsaved
edits asks Save, Discard, or Cancel (Esc cancels). Closing the last tab clears
it; on an empty Untitled tab it closes the panel. The window × walks the unsaved
tabs one at a time: it focuses each and asks; Save or Discard closes that tab and
moves to the next unsaved one, Cancel stops, and the panel closes once nothing
unsaved is left. Open reuses an empty Untitled tab, switches to a file that is
already open, and otherwise opens a new tab. Open tabs (note-open-files) and the
active one (note-last-file) are restored when the panel starts.
Keys: Ctrl+N/Ctrl+T new tab, Ctrl+W close tab, Ctrl+Tab/Ctrl+PgDown next,
Ctrl+Shift+Tab/Ctrl+PgUp previous, Ctrl+O open, Ctrl+S save, Ctrl+Shift+S save as.

Right-click opens the menu: New, Open, Save, Save as, Rename, and Preview markdown
(always listed, disabled unless the file is Markdown); "Vim: on off" comes last (the inactive choice is faded) and
clicking it toggles Vim without closing the menu. Rename (disabled for Untitled)
keeps the menu open and shows an underline-only name field right below it; Enter
renames the file in its folder (existing names are refused). With Vim on the field
starts in Normal mode (h l 0 ^ $ w b e, i a I A, x X D C s S, r R, dw cw diw ciw
dd cc, u) and Esc in Normal closes the menu. Open and Save use GNOME's own
file chooser through xdg-desktop-portal (D-Bus, no extra package); Qt's dialog
is only a fallback when the portal is unavailable. Untitled notes open the save
chooser (Markdown or Text; a name without an extension gets the selected
filter's). Writes are atomic (QSaveFile); files over 8 MB are refused.

The Vim setting is separate from Tasks and remembers its state (note-vim-enabled).
With Vim on, a status line shows the mode in color (-- NORMAL -- blue, -- INSERT --
green, -- REPLACE -- red, -- COMMAND -- orange), messages or path, and line:column.
Normal: h j k l, w b e, 0 ^ $, gg G {n}G, counts, i a I A o O, x X s S C D J ~,
r R (r Enter splits the line), dd cc yy, d/c/y with w e b $ 0 j k G iw aw, p P,
u, Ctrl+R, >> << (a tab if the indent starts with one, else four spaces),
Alt+j/Alt+k (or Alt+Down/Up) move the line down/up, / ? n N (n keeps the last
search's direction), * # (whole word under or after the cursor), . (repeats the
last change, including the text typed in insert or replace mode; a count
replaces the original one), gt gT {n}gt. A bare Shift press does not cancel a
pending command, so rA, d$, dG, and gT work as typed.
Visual: v (characters) and V (whole lines) highlight the selection with the
theme's selection color and show -- VISUAL -- or -- VISUAL LINE -- in purple;
the block cursor marks the moving end. Normal-mode motions and counts extend it.
o swaps ends, v/V switch kind (or leave when repeated), Escape leaves with the
cursor on the moving end, gv reselects the last area. Operators: d x Delete,
X D (lines), c s, C S R (lines), y, Y (lines), > <, ~ u U, J, r{char}, p (puts
the register and keeps the replaced text) and P (keeps the register). A mouse
drag or double-click selection in normal mode enters Visual mode.
Ex: :w [path], :q, :q!, :wq, :x, :e [path], :e!, :enew, :{line}, :tabnew [path],
:tabn, :tabp, :tabc. :q and :wq close the tab, or the panel on the last tab.
Normal mode is read-only, so input methods cannot insert text by accident.
```

## Screenshots

```text
Edge handle on the primary monitor; watches Pictures/Screenshots, newest first.
A configurable Show Desktop handle toggles the same saved window snapshot as
the dock button and Super+0. It supports every screen edge and sm/md/lg width
and height. Both handles can be distributed across three position zones. Drag
either card between Top/Center/Bottom on a
vertical edge or Left/Center/Right on a horizontal edge; dragging within one
zone changes their order. The editor uses the Dock Layout card colors, icon tiles,
hover borders, and drag placeholders. Dragging near the viewport edge scrolls the
list; canceling or dropping outside it keeps the saved layout.
Items in the same zone form a centered group with an
8 px gap. On the Dock
edge both handles sit against the Dock's inner boundary.
Click: select; Ctrl-click: toggle; Shift-click: range; drag: covered thumbnails.
Ctrl+A selects all. Ctrl+C copies absolute paths.

Double-click opens a resizable preview and hides the browser.
Delete moves files to .zhyprbola-trash; Ctrl+Z restores the latest deletion.
Restore never overwrites files. Trash is not purged automatically.
```

## Settings

```text
Sidebar order: Date & Time, Dock, Dock Layout, Edge Handles, Keys, Opacity,
Spectrum, Themes, Wallpaper.

When adding or renaming a section in components/SettingsPanel.qml, sort A-Z
by displayed English label. Keep heading and page mappings synchronized.
```

## Commands

```bash
make build                        # Build without installing the extension
make dock                         # Build, install, and enable the dock
./scripts/run-panel wifi           # Run a focused panel
./scripts/run-panel bluetooth
./scripts/run-panel key-visualizer
./scripts/run-panel settings
make check                        # QML lint; existing warnings may be printed

# Other panel names: clock, weather, system-status, audio-spectrum, sound,
# tasks, note, calendar, music, screenshots
```

## Integrations

```text
Wi-Fi: nmcli / NetworkManager          Bluetooth: bluetoothctl / BlueZ
Media: MPRIS, optional playerctl       Sound: GNOME mixer
Brightness: GNOME, optional ddcutil    Battery: UPower
Spectrum: cava                        Weather: Open-Meteo
```

## Configuration

```text
Directory: ~/.config/zhyprbola/

Filename                      Purpose / default
----------------------------  -----------------------------------------------
theme                         theme
component-opacity             QML opacity (0-100, default 100)
component-opacity-components  surfaces using QML opacity
dock-position                 dock edge
dock-bg-opacity               dock background opacity (0-100, default 50)
dock-layout                   ordered region items, Hidden, and Quick (JSON)
dock-groups                   legacy group visibility, imported on first use
dock-group-order              legacy region order, imported on first use
dock-components               legacy Show/Hidden/Quick layout, imported on first use
dock-ungroup-windows          one icon per window (default false)
pinned-apps                   desktop IDs, used by the Pinned apps block
use-wallpaper                 wallpaper toggle
tasks.json                    checklist
task-vim-enabled              task Vim keyboard mode (default false)
key-visualizer                appearance JSON

Key JSON: fontSize, paddingX, paddingY, width, alignment (old maxWidth migrates to width).
Padding accepts sm/md/lg; legacy padding fills axes not saved separately.
```
