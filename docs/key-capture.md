# Key Capture

```text
Key Capture
==========

Key visualizer settings are under Settings > Keys. While its bubble is visible,
the panel shows keys typed in other applications only when GNOME grants keyboard
monitoring or keyboard-device read access. On GNOME Wayland, use the
"Allow temporarily" button in Key visualizer when prompted.

The dock's Daily Key Count uses the same global-access fallback but receives only
anonymous press markers. When global access is unavailable it falls back to
GNOME Shell captured events, like KeyVizz; this may only count Shell interactions
on Wayland. The statistics menu shows whether counting is global or limited.
When access is missing, choose **Allow keyboard access…** to authorize directly
without opening Key Visualizer. The action hides once global counting is ready,
shows progress while authorization is pending, and allows retry after cancellation
or failure. Successful authorization immediately reconnects the counter. The counter retries global access every
30 seconds and stops counting Shell events once the global helper is ready, so
presses are not counted twice. It stores a total for each local date in
`~/.local/state/zhyprbola/key-count.json`, starts a new total at the next local
day, and never stores key names or typed text. Clicking the dock text opens
statistics for today, 7/15 days, this month, rolling 3/6 months, this year, the
best day, and all time. Selecting a range changes the dock text, for example
`keys:7d:1,234`; hovering a range changes only its text color.

Authorization
----------

If the desktop cannot show the authorization dialog, grant temporary read access
from a terminal and reopen Key visualizer.
```

```bash
./scripts/grant-key-capture
```

```text
Security
----------

The button opens system authentication; the terminal command prompts for sudo.
Access lasts until reboot or device reconnect and allows other programs running
as your user to read those devices too. Do not use it on a shared account.
Minimize Key visualizer before entering passwords.
```
