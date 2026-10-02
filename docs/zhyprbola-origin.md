# Zhyprbola Origin

This note is not an implementation document.

It exists only to preserve the story, meaning, and emotional direction of the
project name. Technical documents in this directory, such as `architecture.md`,
`ipc.md`, or component-specific notes, should be treated as the real project
documentation for implementation decisions.

## Name

`zhyprbola` is built from three parts:

- `z` comes from `znnn`, a personal mark used across projects.
- `hypr` comes from Hyprland, a desktop direction that once felt compelling and
  still carries some of the project's visual and workflow inspiration.
- `bola` comes from `pola`, reshaped so the combined name becomes close to
  `hyprbola`, echoing `hyperbola`.

The display name may be written as `Hyprbola`, while the repository or technical
project name can remain `zhyprbola` to keep the personal `z` signature.

## Meaning

A hyperbola is made of curves that move toward their asymptotes forever. They
approach, but never truly meet.

That image fits the direction of this project: GJS and QML are two different
worlds. GJS belongs naturally to GNOME Shell, panel integration, dock behavior,
and desktop-level control. QML belongs naturally to rich, expressive components,
fluid panels, and carefully designed visual surfaces.

The goal is not to force them into one runtime. The goal is to let them move
close enough to feel unified while allowing each side to remain itself.

```text
GJS / GNOME Shell  <---- approaches ---->  QML / zpola panels
```

This is the heart of `zhyprbola`: two interfaces approaching one another,
beautifully close, never collapsed into the same thing.

## Direction

`zhyprbola` is the next shape of the desktop experiment that began with `zpola`.
It keeps the visual language and component work from `zpola`, but moves toward a
new architecture:

- GNOME/GJS owns the shell-facing layer, such as the dock, panel icons, and
  integration with the desktop session.
- QML owns rich components such as Bluetooth, Wi-Fi, media, and other panels.
- IPC, likely through D-Bus or a small command bridge, lets both sides talk
  without pretending they are the same system.

The project is therefore not a Hyprland shell clone and not a full replacement
desktop environment. It is a bridge: a personal desktop layer that can live with
GNOME while gradually introducing custom shell experiences.

## Documentation Boundary

This file should stay narrative.

Use the rest of `docs/` for practical documents:

- `architecture.md` for the GJS/QML process model and IPC design.
- `components.md` for component ownership and lifecycle.
- `gnome-extension.md` for shell integration details.
- `qml-panels.md` for QML panel behavior and visual conventions.

Implementation should not depend on this file. This file only explains why the
project has this name and what feeling it is trying to preserve.
