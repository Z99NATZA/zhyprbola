# Current Behavior

```text
Zhyprbola combines a GNOME Shell dock with focused Qt/QML panels.
The dock owns Shell behavior and lightweight popups; QML handles richer views.
```

## Overview

```text
GNOME dock extension
  |
  +-- Shell popups: sound, brightness, battery
  |
  +-- QML panels: Bluetooth, Wi-Fi, clock/weather, key visualizer,
  |               system status, audio spectrum, music, tasks,
  |               calendar, settings
  |
  +-- Resident QML browser: screenshots

Default dock position: bottom
Supported positions: left, right, top, bottom
```

## Dock

```text
The dock contains Apps, Running, and Zhyprbola regions.

Apps:
- configured application launchers
- can be enabled or disabled

Running:
- open applications
- one icon per window when Ungroup windows is enabled
- can be enabled or disabled

Zhyprbola:
- component buttons
- always enabled
- always keeps Settings in Show

Region order is configurable. Disabled regions keep their position.
```

## Components

```text
Settings -> Components organizes components into three locations:

Show:    visible directly on the dock
Hidden:  not shown
Quick:   available from the Components popup

Sound, Brightness, Battery, and Key Visualizer start in Quick.
Date and Time cannot move to Quick. Settings cannot leave Show.
```

## Opacity

```text
Settings -> Opacity adjusts QML component surfaces from 0-100%.
Drag items between Opacity and Default to choose which QML surfaces use that value.

Settings and Screenshots can be moved between the lists.
Screenshots appears only in the Opacity lists and defaults to using opacity.
Its setting affects the browser background and preview images.
Preview close and resize controls remain opaque.
Text, icons, controls, the dock, and Shell popups stay opaque.
```

## Sound

```text
Sound opens a Shell popup with separate microphone and speaker rows.
Each row has a 0-100% slider and an independent mute button.

Values follow GNOME mixer changes immediately.
Unavailable devices leave their controls disabled.
```

## Brightness

```text
Brightness opens a Shell popup with one slider.

Preferred backend: GNOME brightness manager
Fallback backend:  ddcutil for DDC/CI displays

Unavailable displays show a dimmed, disabled control.
```

## Battery

```text
Battery opens a Shell popup backed by UPower.

It shows:
- current percentage
- charging state
- time remaining or time until full

Systems without a battery show an unavailable state.
```

## Input Source

```text
Input Source shows the current language code, such as en or th.
Activating it opens a compact language switcher.
```

## Date and Time

```text
Date and Time appear as dock labels.
Activating either opens Settings directly to Date & Time.
This also works from the dock overflow menu.
```

## Key Visualizer

```text
Key Visualizer opens a floating bubble and clears recent keys after five seconds.

Settings control:
- font size and padding
- fit or fixed width
- minimum and maximum width
- text alignment

It supports English and Thai input through GNOME AT-SPI or readable Linux input
devices. Without either permission, it captures keys only while focused.
```

## Tasks

```text
Tasks is a local checklist with add, edit, toggle, delete, and drag-to-reorder.
Items remain until explicitly deleted and do not expire when the date changes.
```

## Screenshots

```text
The Screenshots browser opens from a handle on the primary monitor edge.
It watches Pictures/Screenshots and lists thumbnails newest first.

Selection:
- Click selects one image.
- Ctrl-click toggles one image.
- Shift-click selects a range.
- Dragging selects covered thumbnails.
- Ctrl+A selects all.
- Ctrl+C copies absolute paths.

Double-click opens a resizable image preview.
Delete moves files to .zhyprbola-trash. Ctrl+Z restores the latest deletion.
Restore never overwrites an existing file.
```

## Commands

```bash
# Build, install, and enable the dock
make dock

# Run panels directly while developing
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
Wi-Fi:       nmcli / NetworkManager
Bluetooth:   bluetoothctl / BlueZ
Media:       MPRIS, optional playerctl
Sound:       GNOME mixer
Brightness:  GNOME brightness manager, optional ddcutil
Battery:     UPower
Spectrum:    cava
Weather:     Open-Meteo
```

## Configuration

```text
Theme:               ~/.config/zhyprbola/theme
Component opacity:   ~/.config/zhyprbola/component-opacity
Opacity components:  ~/.config/zhyprbola/component-opacity-components
Dock position:       ~/.config/zhyprbola/dock-position
Dock opacity:        ~/.config/zhyprbola/dock-bg-opacity
Enabled groups:      ~/.config/zhyprbola/dock-groups
Group order:         ~/.config/zhyprbola/dock-group-order
Component layout:    ~/.config/zhyprbola/dock-components
Ungroup windows:     ~/.config/zhyprbola/dock-ungroup-windows
Pinned apps:         ~/.config/zhyprbola/pinned-apps
Wallpaper toggle:    ~/.config/zhyprbola/use-wallpaper
Tasks:               ~/.config/zhyprbola/tasks.json
Key visualizer:      ~/.config/zhyprbola/key-visualizer

Dock opacity affects only the background, accepts 0-100, and defaults to 50.
Component opacity accepts 0-100 and defaults to 100.
Ungroup windows defaults to false.
Pinned apps are desktop IDs stored one per line and appear only with Apps enabled.
```

## Detailed Notes

```text
The following sections cover behavior needed when changing lifecycle, input,
fallback, or layout code.
```

### Running Windows

```text
Running apps remain visible even when the same app exists in Apps.

In ungrouped mode, dragged order survives focus changes, title changes, and
temporary app-tracker omissions. A slot is removed only after its window closes.
New windows append to the saved order.

Right-click, the keyboard menu key, or Shift+F10 opens GNOME's app menu.
Supported actions include open windows, New Window, desktop actions, and Quit.
Pin to Dash is omitted because Zhyprbola owns its launcher configuration.
```

### Show Desktop

```text
The first activation hides visible, minimizable windows on the current workspace.
The next activation restores only windows hidden by Zhyprbola.
The dock button and Super+0 invoke the same toggle action.

Zhyprbola panels and previously minimized windows are ignored.
Hide history is stored per workspace and survives partial manual restores.
Closed windows and windows moved to another workspace are skipped during restore.
```

### Popup Lifecycle

```bash
# Dock popups open only through explicit activation.
# Hover and keyboard focus do not switch the open popup.

# Sound, Brightness, and Battery remain Shell popups when opened from Settings,
# Quick, or overflow. They never spawn fallback QML windows.

# The standalone Sound panel remains available for development:
./scripts/run-panel sound
```

### Brightness Fallback

```text
The DDC fallback uses the first detected DDC/CI display and its reported maximum.
Commands run asynchronously and combine rapid slider changes.

Opening the popup refreshes the hardware value.
Monitor changes trigger display rediscovery.

DDC/CI requires ddcutil and access to the display's I2C device.
Package udev rules normally provide this access.
```

### Key Capture

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

### Screenshots Lifecycle

```text
Settings -> Screenshots selects Left or Right and Top, Center, or Bottom.
The vertical positions are centered at 1/6, 1/2, and 5/6 of screen height.
The 5 x 100 px handle stays visible in fullscreen.

The browser opens beside the handle and remains inside the work area.
Clicking outside, pressing Escape, or activating the handle again hides it.

One resident QML process is controlled through D-Bus.
Hiding preserves its model, selection, clipboard owner, and thumbnail cache.

The preview is transparent, borderless, and resizable.
Its initial window fits the image aspect ratio within 660 x 510 px and
85% of the screen, without upscaling the original image.
Dragging the image moves the window. The resize handle is at the window's
bottom-right corner and preserves the image aspect ratio while dragging.
Double-clicking an image opens its preview and hides the browser.
The preview closes with Escape or its close icon; the browser stays hidden.
Reopening or hiding the browser through the handle keeps the preview open.
Each double-click opens a separate preview, including for the same image,
and hides the browser again. Closing one preview leaves the others open.
Its close icon stays 20 px from the image corner.
Close and resize icons appear while hovering over the preview and hide
100 ms after the pointer leaves. Returning before then cancels the hide.

Deletion has no confirmation.
Undo data remains in .zhyprbola-trash until restored and is not purged automatically.
A rapid reopen cancels an older collapse.
Disabling the extension stops only the browser and its handle.
```

### Settings Layout

```text
New Settings windows open beside the trailing end of dock region 3 in the
current region order, with a 12 px gap and 12 px work-area margin.
With the default bottom dock, Settings opens above its right-hand end.
Reopening an existing Settings window preserves its position.

Content row:          46 px
Gap within a group:    8 px
Gap between groups:   16 px

Key padding:
sm:  4 px around text
md:  default spacing
lg:  12 px around text

Key width buttons change by 20 px.
Holding starts repeat after 400 ms and accelerates to 25 steps per second.

Keep SettingsPanel sidebar sections alphabetized by displayed English label.
Keep page content and heading mappings synchronized with the sidebar.
```

### Wallpapers

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

### Weather Override

```bash
ZHYPRBOLA_LATITUDE=13.7563 \
ZHYPRBOLA_LONGITUDE=100.5018 \
ZHYPRBOLA_LOCATION=Bangkok \
make dock
```
