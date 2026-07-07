#!/usr/bin/env bash
set -euo pipefail

echo "[Albasty] Generating low-poly model with Blender..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
blender --background --python "$SCRIPT_DIR/blender_scripts/create_albasty_lowpoly.py"

test -f "$SCRIPT_DIR/assets/models/albasty_lowpoly.glb"
echo "[Albasty] Done: $SCRIPT_DIR/assets/models/albasty_lowpoly.glb"
