#!/usr/bin/env python3
"""Download Poly Haven assets for the yurt interior upgrade.

The script keeps downloads deterministic and safe for the Godot project:
- models are downloaded as importable glTF bundles into assets/polyhaven/props;
- standalone PBR materials are downloaded as jpg maps into either
  assets/polyhaven/textures or assets/polyhaven/interior_textiles;
- existing non-empty files are reused unless --force is passed.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
POLYHAVEN_DIR = REPO_ROOT / "assets" / "polyhaven"
PROPS_DIR = POLYHAVEN_DIR / "props"
RAW_DIR = POLYHAVEN_DIR / "raw"
PROCESSED_DIR = POLYHAVEN_DIR / "processed"
SOURCE_ZIP_DIR = POLYHAVEN_DIR / "source_zips"
TEXTURE_DIR = POLYHAVEN_DIR / "textures"
TEXTILE_DIR = POLYHAVEN_DIR / "interior_textiles"
MANIFEST_PATH = POLYHAVEN_DIR / "polyhaven_interior_download_manifest.json"
API_URL = "https://api.polyhaven.com/files/{asset_id}"
REQUEST_HEADERS = {
	"User-Agent": "retro-journal-prototype-interior-import/1.0 (+https://polyhaven.com)",
}

MODEL_ASSETS = [
	"GothicBed_01",
	"bull_head",
	"gallinera_table",
	"boombox",
	"Television_01",
	"namaqualand_boulder_02",
	"namaqualand_boulder_04",
	"chinese_screen_panels",
	"cassette_player",
	"portable_generator",
	"chinese_console_table",
]

TEXTURE_ASSETS = {
	"broken_brick_wall": TEXTURE_DIR,
	"gravel_concrete_03": TEXTURE_DIR,
	"old_linoleum_flooring_01": TEXTURE_DIR,
	"fabric_leather_02": TEXTILE_DIR,
	"velour_velvet": TEXTILE_DIR,
	"curly_teddy_checkered": TEXTILE_DIR,
	"quatrefoil_jacquard_fabric": TEXTILE_DIR,
	"wool_boucle": TEXTILE_DIR,
	"waffle_pique_cotton": TEXTILE_DIR,
}

MATERIAL_MAP_KEYS = [
	"Diffuse",
	"Rough",
	"AO",
	"nor_gl",
	"arm",
	"Displacement",
]


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--model-resolution", default="2k", help="Preferred glTF resolution for model bundles.")
	parser.add_argument("--texture-resolution", default="2k", help="Preferred resolution for standalone material maps.")
	parser.add_argument("--models", nargs="*", default=MODEL_ASSETS, help="Model asset ids to download.")
	parser.add_argument("--textures", nargs="*", default=list(TEXTURE_ASSETS.keys()), help="Texture/material asset ids to download.")
	parser.add_argument("--force", action="store_true", help="Redownload files that already exist.")
	args = parser.parse_args()

	for directory in (PROPS_DIR, RAW_DIR, PROCESSED_DIR, SOURCE_ZIP_DIR, TEXTURE_DIR, TEXTILE_DIR):
		directory.mkdir(parents=True, exist_ok=True)

	manifest: dict[str, Any] = {
		"downloaded_at": time.strftime("%Y-%m-%d %H:%M:%S"),
		"model_resolution": args.model_resolution,
		"texture_resolution": args.texture_resolution,
		"models": [],
		"textures": [],
		"skipped": [],
	}

	for asset_id in args.models:
		try:
			manifest["models"].append(download_model(asset_id, args.model_resolution, args.force))
		except Exception as exc:  # noqa: BLE001 - command line tool should keep going.
			manifest["skipped"].append({"asset": asset_id, "kind": "model", "reason": str(exc)})
			print(f"[error] model {asset_id}: {exc}", file=sys.stderr)

	for asset_id in args.textures:
		try:
			manifest["textures"].append(download_material_maps(asset_id, args.texture_resolution, args.force))
		except Exception as exc:  # noqa: BLE001 - command line tool should keep going.
			manifest["skipped"].append({"asset": asset_id, "kind": "texture", "reason": str(exc)})
			print(f"[error] texture {asset_id}: {exc}", file=sys.stderr)

	MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
	print(f"[manifest] {MANIFEST_PATH.relative_to(REPO_ROOT)}")
	print(
		f"[done] models={len(manifest['models'])} "
		f"textures={len(manifest['textures'])} skipped={len(manifest['skipped'])}"
	)
	return 0


def download_model(asset_id: str, resolution: str, force: bool) -> dict[str, Any]:
	files = fetch_files(asset_id)
	gltf_by_resolution = files.get("gltf", {})
	selected_resolution = choose_resolution(gltf_by_resolution, resolution)
	entry = gltf_by_resolution[selected_resolution]["gltf"]
	output = PROPS_DIR / f"{asset_id}_{selected_resolution}.gltf"
	raw_output = RAW_DIR / asset_id / f"{asset_id}_{selected_resolution}.gltf"
	processed_output = PROCESSED_DIR / f"{asset_id}_hero.gltf"

	total_bytes = int(entry.get("size", 0))
	download_file(entry["url"], output, force)
	download_file(entry["url"], raw_output, force)
	copy_existing(output, processed_output, force)
	for relative_name, include_data in entry.get("include", {}).items():
		total_bytes += int(include_data.get("size", 0))
		download_file(include_data["url"], PROPS_DIR / relative_name, force)
		download_file(include_data["url"], RAW_DIR / asset_id / relative_name, force)
		if relative_name.endswith(".bin"):
			copy_existing(PROPS_DIR / relative_name, PROCESSED_DIR / f"{asset_id}.bin", force)
		elif relative_name.startswith("textures/"):
			copy_existing(PROPS_DIR / relative_name, PROCESSED_DIR / relative_name, force)

	print(f"[model] {asset_id} {selected_resolution}: {total_bytes / (1024 * 1024):.2f} MB")
	return {
		"asset": asset_id,
		"resolution": selected_resolution,
		"target": rel(output),
		"raw": rel(raw_output),
		"processed": rel(processed_output),
		"size_mb": round(total_bytes / (1024 * 1024), 2),
	}


def download_material_maps(asset_id: str, resolution: str, force: bool) -> dict[str, Any]:
	files = fetch_files(asset_id)
	target_dir = TEXTURE_ASSETS.get(asset_id, TEXTURE_DIR)
	target_dir.mkdir(parents=True, exist_ok=True)

	downloaded: list[str] = []
	total_bytes = 0
	for map_key in MATERIAL_MAP_KEYS:
		if map_key not in files:
			continue
		by_resolution = files[map_key]
		selected_resolution = choose_resolution(by_resolution, resolution)
		format_entry = choose_format(by_resolution[selected_resolution])
		url = format_entry["url"]
		output = target_dir / Path(url).name
		total_bytes += int(format_entry.get("size", 0))
		download_file(url, output, force)
		downloaded.append(rel(output))

	print(f"[texture] {asset_id}: {len(downloaded)} maps, {total_bytes / (1024 * 1024):.2f} MB")
	return {
		"asset": asset_id,
		"resolution": resolution,
		"maps": downloaded,
		"size_mb": round(total_bytes / (1024 * 1024), 2),
	}


def fetch_files(asset_id: str) -> dict[str, Any]:
	print(f"[api] {asset_id}")
	request = urllib.request.Request(API_URL.format(asset_id=asset_id), headers=REQUEST_HEADERS)
	with urllib.request.urlopen(request, timeout=30) as response:
		return json.loads(response.read().decode("utf-8"))


def choose_resolution(by_resolution: dict[str, Any], preferred: str) -> str:
	if preferred in by_resolution:
		return preferred
	def score(resolution: str) -> int:
		digits = "".join(ch for ch in resolution if ch.isdigit())
		return int(digits or "0")
	available = sorted(by_resolution.keys(), key=score)
	if not available:
		raise RuntimeError("no downloadable resolutions")
	preferred_score = score(preferred)
	lower_or_equal = [item for item in available if score(item) <= preferred_score]
	return lower_or_equal[-1] if lower_or_equal else available[0]


def choose_format(by_format: dict[str, Any]) -> dict[str, Any]:
	for extension in ("jpg", "png", "gltf"):
		if extension in by_format:
			return by_format[extension]
	raise RuntimeError("no supported download format")


def download_file(url: str, output_path: Path, force: bool) -> None:
	output_path.parent.mkdir(parents=True, exist_ok=True)
	if output_path.exists() and output_path.stat().st_size > 0 and not force:
		print(f"  [exists] {rel(output_path)}")
		return
	print(f"  [get] {rel(output_path)}")
	tmp_path = output_path.with_suffix(output_path.suffix + ".tmp")
	request = urllib.request.Request(url, headers=REQUEST_HEADERS)
	with urllib.request.urlopen(request, timeout=180) as response:
		tmp_path.write_bytes(response.read())
	tmp_path.replace(output_path)


def copy_existing(source_path: Path, output_path: Path, force: bool) -> None:
	output_path.parent.mkdir(parents=True, exist_ok=True)
	if output_path.exists() and output_path.stat().st_size > 0 and not force:
		print(f"  [exists] {rel(output_path)}")
		return
	if not source_path.exists():
		return
	print(f"  [copy] {rel(output_path)}")
	output_path.write_bytes(source_path.read_bytes())


def rel(path: Path) -> str:
	return str(path.relative_to(REPO_ROOT)).replace("\\", "/")


if __name__ == "__main__":
	raise SystemExit(main())
