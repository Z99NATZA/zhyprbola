# Documentation

## Reading Order

- [Current Behavior](current-behavior.md): UI, defaults, settings, and commands.
- [Architecture](architecture.md): ownership and communication between layers.
- [Runtime Notes](runtime-notes.md): lifecycle, input, fallback, and layout details.
- [Zhyprbola Origin](zhyprbola-origin.md): original project notes in Thai.

## Updating

```text
Keep technical notes in English with short headings and text or bash blocks.
Keep the original Thai voice in Zhyprbola Origin.

Update Current Behavior for user-visible changes and Architecture for layer changes.
Keep implementation details in Runtime Notes; add new documents to this index.
Settings sidebar ordering is defined in Current Behavior -> Settings.
```

## Development

```bash
make build                        # Build without installing the extension
./scripts/run-panel settings       # Run a focused panel
make check                        # QML lint; existing warnings may be printed
```
