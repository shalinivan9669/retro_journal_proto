#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /absolute/path/to/godot-project"
  exit 2
fi

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="$(cd "$1" && pwd)"
TARGET="$TARGET_ROOT/addons/archive_barrage"

if [[ ! -f "$TARGET_ROOT/project.godot" ]]; then
  echo "Target does not contain project.godot: $TARGET_ROOT"
  exit 3
fi

mkdir -p "$TARGET"
cp -a "$SOURCE/assets" "$TARGET/"
cp -a "$SOURCE/scenes" "$TARGET/"
cp -a "$SOURCE/scripts" "$TARGET/"
cp -a "$SOURCE/shaders" "$TARGET/"
cp -a "$SOURCE/ASSET_MANIFEST.md" "$TARGET/"
cp -a "$SOURCE/VISUAL_ACCEPTANCE.md" "$TARGET/"

find "$TARGET" -type f \( -name '*.gd' -o -name '*.gdshader' -o -name '*.tscn' \) -print0 |
  xargs -0 sed -i 's#res://#res://addons/archive_barrage/#g'

echo "Installed to: $TARGET"
echo "Demo scene: res://addons/archive_barrage/scenes/BarrageDemo.tscn"
