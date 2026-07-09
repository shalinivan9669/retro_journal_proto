#!/usr/bin/env python3
"""Create simplified GLB LOD files from downloaded Poly Haven glTF sources.

Run with:
    blender --background --python tools/process_polyhaven_assets_blender.py
"""

from __future__ import annotations

from pathlib import Path


try:
	import bpy  # type: ignore
except ImportError:
	print("This script must be run with Blender's Python. No files were processed.")
	raise SystemExit(0)


REPO_ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = REPO_ROOT / "assets" / "polyhaven" / "processed"

ASSET_TARGETS = {
	"coast_land_rocks_03": ["lod0", "lod1"],
	"coast_rocks_03": ["lod0", "lod1"],
	"island_tree_02": ["lod0", "lod1", "lod2"],
	"island_tree_03": ["lod1", "lod2"],
	"pine_sapling_medium": ["lod1", "lod2"],
	"searsia_lucida": ["lod1"],
	"searsia_burchellii": ["lod1"],
	"wild_rooibos_bush": ["lod1"],
	"flower_empodium": ["lod0"],
	"flower_heliophila": ["lod0"],
	"periwinkle_plant": ["lod0"],
	"grass_medium_02": ["lod1"],
}

DECIMATE_RATIO = {
	"lod0": 1.0,
	"lod1": 0.55,
	"lod2": 0.28,
}


def main() -> int:
	for asset_id, lods in ASSET_TARGETS.items():
		source = _source_for(asset_id)
		if source is None:
			print(f"[skip] {asset_id}: no downloaded glTF source")
			continue
		for lod in lods:
			process_lod(asset_id, source, lod)
	return 0


def _source_for(asset_id: str) -> Path | None:
	for suffix in ("lod1", "lod0"):
		path = PROCESSED_DIR / f"{asset_id}_{suffix}.gltf"
		if path.exists():
			return path
	return None


def process_lod(asset_id: str, source: Path, lod: str) -> None:
	_clear_scene()
	bpy.ops.import_scene.gltf(filepath=str(source))
	mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
	if not mesh_objects:
		print(f"[skip] {asset_id} {lod}: no meshes")
		return

	ratio = DECIMATE_RATIO.get(lod, 0.55)
	if ratio < 0.999:
		for obj in mesh_objects:
			bpy.context.view_layer.objects.active = obj
			obj.select_set(True)
			modifier = obj.modifiers.new(name=f"Decimate_{lod}", type="DECIMATE")
			modifier.ratio = ratio
			bpy.ops.object.modifier_apply(modifier=modifier.name)
			obj.select_set(False)

	for obj in mesh_objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = mesh_objects[0]

	target_name = f"{asset_id}_{lod}.glb"
	if asset_id == "grass_medium_02":
		target_name = "grass_medium_02_clump_lod1.glb"
	target = PROCESSED_DIR / target_name
	bpy.ops.export_scene.gltf(
		filepath=str(target),
		export_format="GLB",
		use_selection=True,
		export_apply=True,
	)
	print(f"[glb] {target.relative_to(REPO_ROOT)}")


def _clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()


if __name__ == "__main__":
	raise SystemExit(main())
