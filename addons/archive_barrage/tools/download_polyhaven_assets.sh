#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PH="$ROOT/assets/polyhaven"

mkdir -p "$PH/dark_rock_4k" "$PH/plastered_stone_wall_4k" "$PH/rogland_clear_night_4k"

download() {
  local url="$1"
  local output="$2"
  if [[ -s "$output" ]]; then
    return
  fi
  curl -L --fail --retry 4 --retry-delay 2 --continue-at - --output "$output" "$url"
}

download "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/dark_rock/dark_rock_diff_4k.jpg" \
  "$PH/dark_rock_4k/dark_rock_diff_4k.jpg" &
download "https://dl.polyhaven.org/file/ph-assets/Textures/png/4k/dark_rock/dark_rock_nor_gl_4k.png" \
  "$PH/dark_rock_4k/dark_rock_nor_gl_4k.png" &
download "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/dark_rock/dark_rock_rough_4k.jpg" \
  "$PH/dark_rock_4k/dark_rock_rough_4k.jpg" &
download "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/dark_rock/dark_rock_disp_4k.jpg" \
  "$PH/dark_rock_4k/dark_rock_disp_4k.jpg" &

download "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/plastered_stone_wall/plastered_stone_wall_diff_4k.jpg" \
  "$PH/plastered_stone_wall_4k/plastered_stone_wall_diff_4k.jpg" &
download "https://dl.polyhaven.org/file/ph-assets/Textures/png/4k/plastered_stone_wall/plastered_stone_wall_nor_gl_4k.png" \
  "$PH/plastered_stone_wall_4k/plastered_stone_wall_nor_gl_4k.png" &
download "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/plastered_stone_wall/plastered_stone_wall_rough_4k.jpg" \
  "$PH/plastered_stone_wall_4k/plastered_stone_wall_rough_4k.jpg" &
download "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/plastered_stone_wall/plastered_stone_wall_disp_4k.jpg" \
  "$PH/plastered_stone_wall_4k/plastered_stone_wall_disp_4k.jpg" &

download "https://dl.polyhaven.org/file/ph-assets/HDRIs/exr/4k/rogland_clear_night_4k.exr" \
  "$PH/rogland_clear_night_4k/rogland_clear_night_4k.exr" &

wait

find "$PH" -type f -size 0 -delete
echo "Poly Haven assets are present in: $PH"
