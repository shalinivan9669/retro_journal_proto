#!/usr/bin/env python3
"""Download importable Poly Haven glTF assets for the steppe landscape."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = REPO_ROOT / "assets" / "polyhaven" / "processed"
MANIFEST_PATH = REPO_ROOT / "assets" / "polyhaven" / "polyhaven_download_manifest.json"
API_URL = "https://api.polyhaven.com/files/{asset_id}"
REQUEST_HEADERS = {
	"User-Agent": "retro-journal-prototype-landscape-import/1.0 (+https://polyhaven.com)",
}

ASSET_LOD_SUFFIX = {
	"coast_land_rocks_03": "lod1",
	"coast_rocks_03": "lod1",
	"island_tree_02": "lod1",
	"island_tree_03": "lod1",
	"pine_sapling_medium": "lod1",
	"searsia_lucida": "lod1",
	"searsia_burchellii": "lod1",
	"wild_rooibos_bush": "lod1",
	"flower_empodium": "lod0",
	"flower_heliophila": "lod0",
	"periwinkle_plant": "lod0",
	"grass_medium_02": "lod1",
}

BALANCED_ASSETS = [
	"grass_medium_02",
	"flower_empodium",
	"flower_heliophila",
	"periwinkle_plant",
	"wild_rooibos_bush",
	"searsia_lucida",
	"coast_rocks_03",
	"coast_land_rocks_03",
	"island_tree_02",
]

HERO_EXTRA_ASSETS = [
	"searsia_burchellii",
	"island_tree_03",
]

VERY_HEAVY_ASSETS = {
	"pine_sapling_medium",
}


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--quality", choices=["balanced", "hero"], default="balanced")
	parser.add_argument("--resolution", choices=["1k", "2k"], default=None)
	parser.add_argument("--assets", nargs="*", help="Explicit asset ids to download.")
	parser.add_argument("--include-very-heavy", action="store_true", help="Allow pine_sapling_medium and similarly large assets.")
	parser.add_argument("--force", action="store_true", help="Redownload files that already exist.")
	args = parser.parse_args()

	resolution = args.resolution or ("1k" if args.quality == "balanced" else "1k")
	asset_ids = args.assets or list(BALANCED_ASSETS)
	if args.quality == "hero" and not args.assets:
		asset_ids += HERO_EXTRA_ASSETS
	if args.include_very_heavy and not args.assets:
		asset_ids += sorted(VERY_HEAVY_ASSETS)

	PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
	(PROCESSED_DIR / "textures").mkdir(parents=True, exist_ok=True)

	manifest: dict[str, Any] = {
		"downloaded_at": time.strftime("%Y-%m-%d %H:%M:%S"),
		"quality": args.quality,
		"resolution": resolution,
		"downloaded": [],
		"skipped": [],
	}

	for asset_id in asset_ids:
		if asset_id in VERY_HEAVY_ASSETS and not args.include_very_heavy:
			manifest["skipped"].append({"asset": asset_id, "reason": "very heavy; pass --include-very-heavy"})
			print(f"[skip] {asset_id}: very heavy; pass --include-very-heavy")
			continue
		try:
			result = download_asset(asset_id, resolution, args.force)
		except Exception as exc:  # noqa: BLE001 - command-line tool should keep going.
			manifest["skipped"].append({"asset": asset_id, "reason": str(exc)})
			print(f"[error] {asset_id}: {exc}", file=sys.stderr)
			continue
		manifest["downloaded"].append(result)

	MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
	print(f"[manifest] {MANIFEST_PATH.relative_to(REPO_ROOT)}")
	print(f"[done] downloaded={len(manifest['downloaded'])} skipped={len(manifest['skipped'])}")
	return 0


def download_asset(asset_id: str, resolution: str, force: bool) -> dict[str, Any]:
	print(f"[api] {asset_id}")
	with urllib.request.urlopen(make_request(API_URL.format(asset_id=asset_id)), timeout=30) as response:
		files = json.loads(response.read().decode("utf-8"))

	entry = files["gltf"][resolution]["gltf"]
	lod_suffix = ASSET_LOD_SUFFIX.get(asset_id, "lod1")
	main_output = PROCESSED_DIR / f"{asset_id}_{lod_suffix}.gltf"
	total_bytes = int(entry.get("size", 0))

	download_file(entry["url"], main_output, force)
	includes = entry.get("include", {})
	for relative_name, include_data in includes.items():
		total_bytes += int(include_data.get("size", 0))
		download_file(include_data["url"], PROCESSED_DIR / relative_name, force)

	print(f"[asset] {asset_id}: {total_bytes / (1024 * 1024):.2f} MB -> {main_output.relative_to(REPO_ROOT)}")
	return {
		"asset": asset_id,
		"resolution": resolution,
		"target": str(main_output.relative_to(REPO_ROOT)).replace("\\", "/"),
		"size_mb": round(total_bytes / (1024 * 1024), 2),
	}


def download_file(url: str, output_path: Path, force: bool) -> None:
	output_path.parent.mkdir(parents=True, exist_ok=True)
	if output_path.exists() and output_path.stat().st_size > 0 and not force:
		print(f"  [exists] {output_path.relative_to(REPO_ROOT)}")
		return
	print(f"  [get] {output_path.relative_to(REPO_ROOT)}")
	tmp_path = output_path.with_suffix(output_path.suffix + ".tmp")
	with urllib.request.urlopen(make_request(url), timeout=90) as response:
		tmp_path.write_bytes(response.read())
	tmp_path.replace(output_path)


def make_request(url: str) -> urllib.request.Request:
	return urllib.request.Request(url, headers=REQUEST_HEADERS)


if __name__ == "__main__":
	raise SystemExit(main())
