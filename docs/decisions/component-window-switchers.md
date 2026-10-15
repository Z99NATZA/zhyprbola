# Component Windows in Overview and Alt+Tab

## Decision

```text
Keep Zhyprbola component panels as normal minimizable windows. They remain in
GNOME Overview and Alt+Tab.

Clicking the focused component on the dock, or a panel's own close button,
minimizes the window without terminating the process. GNOME's
Super + right-click -> Close remains the explicit way to terminate it.
```

## Rejected Approach

```text
Do not call Meta.Window.hide_from_window_list() to remove Zhyprbola components
from Overview or Alt+Tab. Mutter treats that as window-list/skip-taskbar state,
not as a presentation-only filter. It disables the normal Hide/Minimize action,
so the existing dock toggle and panel close-button behavior stop working.

An attempted workaround using inhibit_mapped()/uninhibit_mapped() was reverted.
It duplicated the established minimize lifecycle and added separate hidden-window
state only to compensate for hide_from_window_list().
```

## Reconsideration

```text
Revisit this decision only when GNOME provides and tests a supported way to
filter Overview and Alt+Tab without changing the window's minimize or close
capabilities.
```
