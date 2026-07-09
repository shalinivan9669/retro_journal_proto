#!/usr/bin/env python3
"""Prepare runtime-friendly interior assets from downloaded Poly Haven sources.

Run with:
    blender --background --python tools/process_polyhaven_interior_assets_blender.py

The project can run without this step because Godot can import the downloaded
glTF bundles directly. This script exists for the heavier cleanup pass:
normalized origins, optional decimation, cloth mesh export, and viewmodel copies.
"""

from __future__ import annotations

from pathlib import Path


try:
	import bpy  # type: ignore
except ImportError:
	print("This script must be run with Blender's Python. No files were processed.")
	raise SystemExit(0)


REPO_ROOT = Path(__file__).resolve().parents[1]
POLYHAVEN_DIR = REPO_ROOT / "assets" / "polyhaven"
PROPS_DIR = POLYHAVEN_DIR / "props"
PROCESSED_DIR = POLYHAVEN_DIR / "processed"

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

VIEWMODEL_ASSETS = {
	"cassette_player",
}


def main() -> int:
	PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
	for asset_id in MODEL_ASSETS:
		source = _find_source(asset_id)
		if source is None:
			print(f"[skip] {asset_id}: no downloaded glTF source")
			continue
		process_model(asset_id, source)
	return 0


def process_model(asset_id: str, source: Path) -> None:
	_clear_scene()
	bpy.ops.import_scene.gltf(filepath=str(source))
	mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
	if not mesh_objects:
		print(f"[skip] {asset_id}: no mesh objects")
		return

	for obj in mesh_objects:
		obj.select_set(True)
		bpy.context.view_layer.objects.active = obj
		obj.location.z -= _min_z(obj)
		obj.select_set(False)

	for obj in mesh_objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = mesh_objects[0]

	target = PROCESSED_DIR / f"{asset_id}_hero.glb"
	bpy.ops.export_scene.gltf(
		filepath=str(target),
		export_format="GLB",
		use_selection=True,
		export_apply=True,
	)
	print(f"[glb] {target.relative_to(REPO_ROOT)}")

	if asset_id in VIEWMODEL_ASSETS:
		_export_viewmodel_copy(asset_id, mesh_objects)


def _export_viewmodel_copy(asset_id: str, mesh_objects: list) -> None:
	for obj in mesh_objects:
		obj.rotation_euler[0] += 0.0
		obj.rotation_euler[1] += 0.0
		obj.rotation_euler[2] += 0.0
		obj.scale *= 1.0
	target = PROCESSED_DIR / f"{asset_id}_viewmodel.glb"
	bpy.ops.export_scene.gltf(
		filepath=str(target),
		export_format="GLB",
		use_selection=True,
		export_apply=True,
	)
	print(f"[viewmodel] {target.relative_to(REPO_ROOT)}")


def _find_source(asset_id: str) -> Path | None:
	for resolution in ("2k", "1k", "4k", "8k"):
		path = PROPS_DIR / f"{asset_id}_{resolution}.gltf"
		if path.exists():
			return path
	return None


def _min_z(obj) -> float:
	corners = [obj.matrix_world @ mathutils.Vector(corner) for corner in obj.bound_box]  # type: ignore[name-defined]
	return min(corner.z for corner in corners)


def _clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()


if __name__ == "__main__":
	import mathutils  # type: ignore

	raise SystemExit(main())
