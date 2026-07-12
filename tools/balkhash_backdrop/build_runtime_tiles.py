#!/usr/bin/env python3
"""Build GPU-safe Balkhash panorama tiles from the immutable source images.

The supplied source art contains a grey checkerboard baked into RGB.  Sources
remain untouched; runtime tiles receive an alpha channel reconstructed from
the saturated/dark-red painted pixels.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/environment/balkhash_left/source"
RUNTIME = ROOT / "assets/environment/balkhash_left/runtime"
MAX_TILE = 4096
LAYERS = [
    "balkhash_left_00_far_horizon.png",
    "balkhash_left_01_lake_water.png",
    "balkhash_left_02_distant_treeline.png",
    "balkhash_left_03_side_dead_trees.png",
    "balkhash_left_04_foreground_reeds_bushes.png",
]


def alpha_cleaned(image: Image.Image, water: bool) -> Image.Image:
    """Turn the neutral checkerboard into alpha without altering painted RGB."""
    rgb = image.convert("RGB")
    out = Image.new("RGBA", rgb.size)
    src = rgb.load()
    dst = out.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = src[x, y]
            spread = max(r, g, b) - min(r, g, b)
            # Artwork is red/black; the generated checkerboard is neutral grey.
            painted = spread > 10 or (r > g * 1.35 + 7 and r > b * 1.35 + 7)
            if water:
                # Water is intentionally an opaque band, including its black lows.
                painted = painted or (125 < y < rgb.height - 105 and r < 38 and g < 38 and b < 38)
            dst[x, y] = (r, g, b, 255 if painted else 0)
    return out


def main() -> None:
    manifest = {"tile_size_limit": MAX_TILE, "layers": []}
    for layer_index, filename in enumerate(LAYERS):
        source = SOURCE / filename
        if not source.exists():
            raise FileNotFoundError(source)
        with Image.open(source) as original:
            had_alpha = "A" in original.getbands()
            cleaned = alpha_cleaned(original, layer_index == 1)
        layer_name = filename.removesuffix(".png").replace("balkhash_left_", "")
        output = RUNTIME / layer_name
        output.mkdir(parents=True, exist_ok=True)
        tiles = []
        for index, left in enumerate(range(0, cleaned.width, MAX_TILE)):
            box = (left, 0, min(left + MAX_TILE, cleaned.width), cleaned.height)
            tile = cleaned.crop(box)
            tile_path = output / f"tile_{index:02d}.png"
            tile.save(tile_path, optimize=True)
            tiles.append({"file": tile_path.name, "crop": list(box), "size": list(tile.size)})
        # Exact crop reconstruction check (the alpha-cleaned runtime image).
        rebuilt = Image.new("RGBA", cleaned.size)
        for tile in tiles:
            with Image.open(output / tile["file"]) as part:
                rebuilt.paste(part, (tile["crop"][0], 0))
        if rebuilt.tobytes() != cleaned.tobytes():
            raise RuntimeError(f"pixel reconstruction failed: {filename}")
        manifest["layers"].append({
            "name": layer_name, "source": f"source/{filename}", "source_size": list(cleaned.size),
            "source_had_alpha": had_alpha, "alpha_reconstructed": not had_alpha, "tiles": tiles,
        })
        print(f"[Balkhash] {filename}: {cleaned.width}x{cleaned.height}, alpha={'source' if had_alpha else 'reconstructed'}, {len(tiles)} tile(s), verified")
    manifest_path = RUNTIME / "balkhash_left_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"[Balkhash] manifest: {manifest_path}")


if __name__ == "__main__":
    main()
