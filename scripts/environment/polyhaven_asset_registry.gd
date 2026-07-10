extends Resource
class_name PolyhavenAssetRegistry

const ASSETS := {
	"coast_land_rocks_03": {
		"path_lod0": "res://assets/polyhaven/processed/coast_land_rocks_03_lod0.glb",
		"path_lod1": "res://assets/polyhaven/processed/coast_land_rocks_03_lod1.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/coast_land_rocks_03_lod1.gltf",
		"role": "hero_rocks",
		"max_count": 3,
		"min_distance": 22.0,
		"max_distance": 74.0,
		"scale_min": 0.75,
		"scale_max": 1.45,
		"casts_shadow": true
	},
	"coast_rocks_03": {
		"path_lod0": "res://assets/polyhaven/processed/coast_rocks_03_lod0.glb",
		"path_lod1": "res://assets/polyhaven/processed/coast_rocks_03_lod1.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/coast_rocks_03_lod1.gltf",
		"role": "distant_rocks",
		"max_count": 4,
		"min_distance": 46.0,
		"max_distance": 118.0,
		"scale_min": 0.65,
		"scale_max": 1.25,
		"casts_shadow": true
	},
	"island_tree_02": {
		"path_lod0": "res://assets/polyhaven/processed/island_tree_02_lod0.glb",
		"path_lod1": "res://assets/polyhaven/processed/island_tree_02_lod1.glb",
		"path_lod2": "res://assets/polyhaven/processed/island_tree_02_lod2.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/island_tree_02_lod1.gltf",
		"role": "hero_tree",
		"max_count": 2,
		"min_distance": 48.0,
		"max_distance": 96.0,
		"scale_min": 0.85,
		"scale_max": 1.2,
		"casts_shadow": true
	},
	"island_tree_03": {
		"path_lod1": "res://assets/polyhaven/processed/island_tree_03_lod1.glb",
		"path_lod2": "res://assets/polyhaven/processed/island_tree_03_lod2.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/island_tree_03_lod1.gltf",
		"role": "hero_tree",
		"max_count": 1,
		"min_distance": 62.0,
		"max_distance": 120.0,
		"scale_min": 0.8,
		"scale_max": 1.05,
		"casts_shadow": true
	},
	"pine_sapling_medium": {
		"path_lod1": "res://assets/polyhaven/processed/pine_sapling_medium_lod1.glb",
		"path_lod2": "res://assets/polyhaven/processed/pine_sapling_medium_lod2.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/pine_sapling_medium_lod1.gltf",
		"role": "distant_tree",
		"max_count": 1,
		"min_distance": 70.0,
		"max_distance": 132.0,
		"scale_min": 0.75,
		"scale_max": 1.05,
		"casts_shadow": false
	},
	"searsia_lucida": {
		"path_lod1": "res://assets/polyhaven/processed/searsia_lucida_lod1.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/searsia_lucida_lod1.gltf",
		"role": "dry_shrub",
		"max_count": 18,
		"scale_min": 0.55,
		"scale_max": 1.15,
		"casts_shadow": true
	},
	"searsia_burchellii": {
		"path_lod1": "res://assets/polyhaven/processed/searsia_burchellii_lod1.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/searsia_burchellii_lod1.gltf",
		"role": "dry_shrub",
		"max_count": 14,
		"scale_min": 0.55,
		"scale_max": 1.1,
		"casts_shadow": true
	},
	"wild_rooibos_bush": {
		"path_lod1": "res://assets/polyhaven/processed/wild_rooibos_bush_lod1.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/wild_rooibos_bush_lod1.gltf",
		"role": "dry_shrub",
		"max_count": 24,
		"scale_min": 0.45,
		"scale_max": 1.05,
		"casts_shadow": false
	},
	"flower_empodium": {
		"path_lod0": "res://assets/polyhaven/processed/flower_empodium_lod0.glb",
		"fallback_lod0": "res://assets/polyhaven/processed/flower_empodium_lod0.gltf",
		"role": "flower",
		"max_count": 120,
		"scale_min": 0.55,
		"scale_max": 1.25,
		"casts_shadow": false
	},
	"flower_heliophila": {
		"path_lod0": "res://assets/polyhaven/processed/flower_heliophila_lod0.glb",
		"fallback_lod0": "res://assets/polyhaven/processed/flower_heliophila_lod0.gltf",
		"role": "flower",
		"max_count": 90,
		"scale_min": 0.55,
		"scale_max": 1.15,
		"casts_shadow": false
	},
	"dandelion_01": {
		"path_lod0": "res://assets/polyhaven/processed/dandelion_01_lod0.glb",
		"fallback_lod0": "res://assets/polyhaven/processed/dandelion_01_lod0.gltf",
		"role": "flower",
		"max_count": 120,
		"scale_min": 0.55,
		"scale_max": 1.15,
		"casts_shadow": false
	},
	"periwinkle_plant": {
		"path_lod0": "res://assets/polyhaven/processed/periwinkle_plant_lod0.glb",
		"fallback_lod0": "res://assets/polyhaven/processed/periwinkle_plant_lod0.gltf",
		"role": "flower",
		"max_count": 70,
		"scale_min": 0.45,
		"scale_max": 1.05,
		"casts_shadow": false
	},
	"grass_medium_02": {
		"path_lod1": "res://assets/polyhaven/processed/grass_medium_02_clump_lod1.glb",
		"fallback_lod1": "res://assets/polyhaven/processed/grass_medium_02_lod1.gltf",
		"role": "grass_multimesh",
		"max_count": 900,
		"scale_min": 0.45,
		"scale_max": 1.25,
		"casts_shadow": false
	}
}


func get_config(asset_id: String) -> Dictionary:
	return ASSETS.get(asset_id, {})


func get_role_ids(role: String) -> Array[String]:
	var ids: Array[String] = []
	for asset_id in ASSETS.keys():
		if ASSETS[asset_id].get("role", "") == role:
			ids.append(asset_id)
	return ids


func get_scene_for_asset(asset_id: String, prefer_lod: bool = true) -> PackedScene:
	var config := get_config(asset_id)
	if config.is_empty():
		push_warning("Poly Haven asset is not registered: " + asset_id)
		return null

	for path in _candidate_paths(config, prefer_lod):
		if ResourceLoader.exists(path, "PackedScene"):
			var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
			if scene != null:
				return scene

	push_warning("Poly Haven asset missing or not imported: " + asset_id)
	return null


func asset_exists(asset_id: String, prefer_lod: bool = true) -> bool:
	var config := get_config(asset_id)
	if config.is_empty():
		return false
	for path in _candidate_paths(config, prefer_lod):
		if ResourceLoader.exists(path, "PackedScene"):
			return true
	return false


func _candidate_paths(config: Dictionary, prefer_lod: bool) -> Array[String]:
	var keys: Array[String] = []
	if prefer_lod:
		keys = ["path_lod1", "fallback_lod1", "path_lod2", "fallback_lod2", "path_lod0", "fallback_lod0"]
	else:
		keys = ["path_lod0", "fallback_lod0", "path_lod1", "fallback_lod1", "path_lod2", "fallback_lod2"]

	var paths: Array[String] = []
	for key in keys:
		if config.has(key):
			paths.append(config[key])
	return paths
