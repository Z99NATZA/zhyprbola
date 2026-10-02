#!/usr/bin/env bash
set -euo pipefail

EXTENSION_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$EXTENSION_DIR/.." && pwd)"
PANEL_NAME="${1:-bluetooth}"

"$ROOT_DIR/scripts/run-panel" "$PANEL_NAME"
