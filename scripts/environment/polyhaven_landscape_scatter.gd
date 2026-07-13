extends Node3D
class_name PolyhavenLandscapeScatter

const REGISTRY_SCRIPT: Script = preload("res://scripts/environment/polyhaven_asset_registry.gd")
const MULTIMESH_SCRIPT: Script = preload("res://scripts/environment/polyhaven_multimesh_scatter.gd")
const MATERIAL_CONTROLLER_SCRIPT: Script = preload("res://scripts/environment/terrain_material_controller.gd")
const LEAF_MATERIAL: Material = preload("res://materials/polyhaven/mat_polyhaven_leaf_alpha.tres")
const ROCK_MATERIAL: Material = preload("res://materials/polyhaven/mat_polyhaven_rock_grounded.tres")
const FLOWER_MATERIAL: Material = preload("res://materials/polyhaven/mat_polyhaven_flower_soft.tres")

const ZONE_NO_SPAWN := 0
const ZONE_PATH_EDGE := 6

@export var terrain_sampler: Resource
@export var player_path: NodePath
@export var density_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var grass_density_multiplier: float = 1.0
@export var hero_density_multiplier: float = 1.0
@export var allow_heavy_hero_assets: bool = true
@export var use_lod_assets: bool = true
@export var use_multimesh_flora: bool = true
@export_range(24.0, 96.0, 4.0) var flora_chunk_size: float = 40.0
@export_range(60.0, 240.0, 10.0) var flora_visibility_range: float = 120.0
@export var seed_value: int = 9669
@export var debug_disable_flora: bool = false
@export var debug_disable_hero_rocks: bool = false
@export var debug_disable_hero_trees: bool = false

var rng := RandomNumberGenerator.new()
var registry
var rock_count: int = 0
var tree_count: int = 0
var shrub_count: int = 0
var grass_count: int = 0
var flower_count: int = 0
var skipped_assets: Array[String] = []


func build() -> void:
	_clear_existing()
	if terrain_sampler == null:
		push_warning("PolyhavenLandscapeScatter skipped: terrain sampler missing.")
		return

	registry = REGISTRY_SCRIPT.new()
	rng.seed = seed_value
	rock_count = 0
	tree_count = 0
	shrub_count = 0
	grass_count = 0
	flower_count = 0
	skipped_assets.clear()

	if not debug_disable_hero_rocks:
		_build_hero_rocks()
	if not debug_disable_hero_trees:
		_build_hero_trees()
	if not debug_disable_flora:
		_build_dry_shrubs()
		_build_flower_patches()
		_build_grass_patches()
		_build_lowland_reeds_like_patches()

	print("[Landscape] hero rocks=", rock_count, " trees=", tree_count, " shrubs=", shrub_count)
	print("[Landscape] multimesh grass=", grass_count, " flowers=", flower_count)


func _clear_existing() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _build_hero_rocks() -> void:
	var placements := [
		{"name": "NearRightRockAnchor", "asset": "coast_land_rocks_03", "p": Vector2(28.0, -38.0), "scale": Vector3(1.85, 1.02, 1.42), "rot": deg_to_rad(-26.0), "sink": 0.18},
		{"name": "NearRightLowCompanion", "asset": "coast_rocks_03", "p": Vector2(34.0, -32.0), "scale": Vector3(0.92, 0.55, 0.78), "rot": deg_to_rad(34.0), "sink": 0.12},
		{"name": "LeftLowlandRockLine_A", "asset": "coast_rocks_03", "p": Vector2(-76.0, -18.0), "scale": Vector3(1.42, 0.72, 1.15), "rot": deg_to_rad(82.0), "sink": 0.20},
		{"name": "LeftLowlandRockLine_B", "asset": "coast_land_rocks_03", "p": Vector2(-69.0, -28.0), "scale": Vector3(0.88, 0.48, 0.72), "rot": deg_to_rad(58.0), "sink": 0.16},
		{"name": "RearDistantRockBreak", "asset": "coast_rocks_03", "p": Vector2(46.0, 22.0), "scale": Vector3(1.16, 0.58, 0.92), "rot": deg_to_rad(-112.0), "sink": 0.16},
		{"name": "PathSideStoneScatter_A", "asset": "coast_rocks_03", "p": Vector2(14.0, -58.0), "scale": Vector3(0.48, 0.28, 0.42), "rot": deg_to_rad(12.0), "sink": 0.08},
		{"name": "PathSideStoneScatter_B", "asset": "coast_rocks_03", "p": Vector2(-12.0, -72.0), "scale": Vector3(0.42, 0.24, 0.38), "rot": deg_to_rad(71.0), "sink": 0.08}
	]

	var max_items: int = max(2, int(round(float(placements.size()) * clamp(hero_density_multiplier, 0.0, 2.0))))
	for i in range(min(max_items, placements.size())):
		var item: Dictionary = placements[i]
		var pos := _terrain_position(item["p"], -float(item["sink"]))
		if not can_place_static(pos, 3.2, item["name"].begins_with("PathSide")):
			continue
		_place_asset_or_fallback(item["asset"], item["name"], item["p"], item["scale"], item["rot"], item["sink"], "hero_rocks")


func _build_hero_trees() -> void:
	var placements := [
		{"name": "FarLeftLonelyTree", "asset": "island_tree_02", "p": Vector2(-168.0, 146.0), "scale": Vector3.ONE * 1.05, "rot": deg_to_rad(-12.0)},
		{"name": "RearRightWindTree", "asset": "island_tree_03", "p": Vector2(184.0, 132.0), "scale": Vector3.ONE * 0.92, "rot": deg_to_rad(31.0)},
		{"name": "PowerlineTinySapling", "asset": "pine_sapling_medium", "p": Vector2(154.0, -184.0), "scale": Vector3.ONE * 0.72, "rot": deg_to_rad(-48.0)}
	]

	var max_items := clampi(int(round(2.0 * hero_density_multiplier)), 1, placements.size())
	for i in range(max_items):
		var item: Dictionary = placements[i]
		var pos := _terrain_position(item["p"], 0.0)
		if not can_place_static(pos, 5.0, false):
			continue
		_place_asset_or_fallback(item["asset"], item["name"], item["p"], item["scale"], item["rot"], 0.0, "hero_tree")


func _build_dry_shrubs() -> void:
	var centers := [
		Vector2(-282.0, -188.0),
		Vector2(-286.0, -132.0),
		Vector2(-282.0, -76.0),
		Vector2(-288.0, -20.0),
		Vector2(-282.0, 36.0),
		Vector2(-286.0, 92.0),
		Vector2(-282.0, 148.0),
		Vector2(-286.0, 204.0),
		Vector2(-278.0, 252.0),
		Vector2(-276.0, -244.0)
	]
	var shrub_assets := ["searsia_lucida", "searsia_burchellii", "wild_rooibos_bush"]
	var target_count := clampi(int(round(38.0 * density_multiplier)), 0, 70)
	var attempts := target_count * 5

	for i in range(attempts):
		if shrub_count >= target_count:
			return
		var center: Vector2 = centers[i % centers.size()]
		var radius := rng.randf_range(3.0, 18.0)
		var angle := rng.randf_range(0.0, TAU)
		var p := center + Vector2(cos(angle), sin(angle)) * radius
		var pos := _terrain_position(p, -rng.randf_range(0.02, 0.06))
		var normal: Vector3 = terrain_sampler.normal_at(p.x, p.y)
		var zone: int = terrain_sampler.zone_at(p.x, p.y)
		if not can_place_plant(pos, normal, zone):
			continue
		if not can_place_static(pos, 1.2, zone == ZONE_PATH_EDGE):
			continue
		var scale_value := rng.randf_range(0.55, 1.12)
		var asset_id: String = shrub_assets[i % shrub_assets.size()]
		_place_asset_or_fallback(asset_id, "DryShrub_%02d" % shrub_count, p, Vector3.ONE * scale_value, rng.randf_range(0.0, TAU), 0.04, "dry_shrub")


func _build_flower_patches() -> void:
	var target_count := clampi(int(round(1100.0 * density_multiplier)), 0, 2200)
	var specs := [
		{
			"asset": "flower_heliophila",
			"name": "HeliophilaWhiteSteppeCarpet",
			"weight": 0.55,
			"centers": [
				Vector2(-18.0, -15.0), Vector2(17.0, -17.0), Vector2(22.0, 8.0), Vector2(-21.0, 12.0),
				Vector2(-42.0, -34.0), Vector2(38.0, -42.0), Vector2(-62.0, -8.0), Vector2(58.0, 18.0),
				Vector2(-34.0, 42.0), Vector2(24.0, 54.0), Vector2(-78.0, 32.0), Vector2(76.0, -20.0)
			]
		},
		{
			"asset": "dandelion_01",
			"name": "DandelionLivingMeadow",
			"weight": 0.30,
			"centers": [
				Vector2(-15.0, -19.0), Vector2(15.0, -22.0), Vector2(22.0, 4.0), Vector2(-23.0, 6.0),
				Vector2(-36.0, -46.0), Vector2(34.0, -54.0), Vector2(-52.0, 26.0), Vector2(48.0, 34.0)
			]
		},
		{"asset": "flower_empodium", "name": "EmpodiumSmallAccents", "weight": 0.10, "centers": [Vector2(-28.0, -32.0), Vector2(30.0, -36.0), Vector2(-44.0, 24.0)]},
		{"asset": "periwinkle_plant", "name": "PeriwinkleRareAccents", "weight": 0.05, "centers": [Vector2(32.0, -42.0), Vector2(20.0, -62.0), Vector2(-46.0, 36.0)]}
	]

	for spec in specs:
		var centers: Array = spec["centers"]
		var count: int = int(round(float(target_count) * float(spec["weight"])))
		var transforms := _make_patch_transforms(centers, count, 0.7, 12.5, 0.62, 1.24, 0.012, true)
		flower_count += _build_asset_variant_multimeshes(
			spec["asset"],
			transforms,
			spec["name"],
			"flower",
			_make_flower_mesh(),
			FLOWER_MATERIAL
		)


func _build_grass_patches() -> void:
	var near_yurt_centers := [
		Vector2(-15.0, -13.0),
		Vector2(0.0, -18.0),
		Vector2(15.0, -13.0),
		Vector2(19.0, 2.0),
		Vector2(14.0, 16.0),
		Vector2(0.0, 19.0),
		Vector2(-15.0, 15.0),
		Vector2(-19.0, 1.0),
		Vector2(-27.0, -20.0),
		Vector2(28.0, -22.0),
		Vector2(26.0, 25.0),
		Vector2(-28.0, 24.0)
	]
	var steppe_centers := [
		Vector2(-172.0, -92.0), Vector2(-194.0, -18.0), Vector2(164.0, -98.0), Vector2(62.0, -176.0),
		Vector2(-72.0, -194.0), Vector2(174.0, 74.0), Vector2(-162.0, 104.0), Vector2(54.0, 188.0),
		Vector2(-204.0, 126.0), Vector2(214.0, 118.0), Vector2(-224.0, -118.0), Vector2(226.0, -142.0),
		Vector2(-24.0, 222.0), Vector2(212.0, 18.0), Vector2(-218.0, 22.0), Vector2(18.0, -228.0)
	]
	var far_steppe_centers := [
		Vector2(-214.0, -128.0), Vector2(-224.0, 34.0), Vector2(-196.0, 186.0),
		Vector2(-86.0, 218.0), Vector2(74.0, 224.0), Vector2(196.0, 168.0),
		Vector2(226.0, 20.0), Vector2(208.0, -176.0), Vector2(96.0, -226.0),
		Vector2(-78.0, -232.0), Vector2(-184.0, -206.0), Vector2(166.0, -214.0)
	]
	var near_count := clampi(int(round(4800.0 * grass_density_multiplier)), 0, 8200)
	var near_transforms := _make_patch_transforms(near_yurt_centers, near_count, 0.35, 12.0, 1.0, 2.15, 0.008, false)
	grass_count += _build_asset_variant_multimeshes(
		"grass_medium_02",
		near_transforms,
		"GrassMedium02YurtMeadowRing",
		"grass_multimesh",
		_make_grass_clump_mesh(),
		LEAF_MATERIAL
	)

	var steppe_count := clampi(int(round(3600.0 * grass_density_multiplier)), 0, 6400)
	var steppe_transforms := _make_patch_transforms(steppe_centers, steppe_count, 2.0, 24.0, 0.88, 1.95, 0.008, false)
	grass_count += _build_asset_variant_multimeshes(
		"grass_medium_02",
		steppe_transforms,
		"GrassMedium02OuterSteppePatches",
		"grass_multimesh",
		_make_grass_clump_mesh(),
		LEAF_MATERIAL
	)

	var far_count := clampi(int(round(1700.0 * grass_density_multiplier)), 0, 3400)
	var far_transforms := _make_patch_transforms(far_steppe_centers, far_count, 8.0, 38.0, 0.72, 1.55, 0.008, false)
	grass_count += _build_asset_variant_multimeshes(
		"grass_medium_02",
		far_transforms,
		"GrassMedium02FarSteppePatches",
		"grass_multimesh",
		_make_grass_clump_mesh(),
		LEAF_MATERIAL
	)


func _build_lowland_reeds_like_patches() -> void:
	var centers := [
		Vector2(-256.0, -88.0),
		Vector2(-268.0, -18.0),
		Vector2(-252.0, 56.0),
		Vector2(-260.0, 124.0),
		Vector2(-248.0, 186.0),
		Vector2(-244.0, -154.0)
	]
	var target_count := clampi(int(round(700.0 * grass_density_multiplier)), 0, 1400)
	var transforms := _make_patch_transforms(centers, target_count, 4.0, 24.0, 0.82, 1.75, 0.015, false)
	grass_count += _build_asset_variant_multimeshes(
		"grass_medium_02",
		transforms,
		"LowlandTallGrassMedium02",
		"grass_multimesh",
		_make_grass_clump_mesh(true),
		LEAF_MATERIAL
	)


func _make_patch_transforms(
	centers: Array,
	target_count: int,
	min_radius: float,
	max_radius: float,
	min_scale: float,
	max_scale: float,
	y_offset: float,
	flowers_only: bool
) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	if target_count <= 0:
		return transforms

	var helper = MULTIMESH_SCRIPT.new()
	var attempts := target_count * 7
	for i in range(attempts):
		if transforms.size() >= target_count:
			break
		var center: Vector2 = centers[i % centers.size()]
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(min_radius, max_radius) * sqrt(rng.randf())
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var normal: Vector3 = terrain_sampler.normal_at(p.x, p.y)
		var zone: int = terrain_sampler.zone_at(p.x, p.y)
		var pos := _terrain_position(p, y_offset)
		if not can_place_plant(pos, normal, zone):
			continue
		if flowers_only and zone == ZONE_PATH_EDGE:
			continue
		if _inside_main_walk_path(p) and not flowers_only:
			continue

		var scale_value := rng.randf_range(min_scale, max_scale)
		var scale := Vector3(scale_value, scale_value * rng.randf_range(0.86, 1.18), scale_value)
		if not flowers_only:
			var horizontal_scale := scale_value * rng.randf_range(1.35, 1.72)
			var vertical_scale := scale_value * rng.randf_range(1.50, 2.05)
			scale = Vector3(horizontal_scale, vertical_scale, horizontal_scale)
		transforms.append(helper.make_transform(pos, rng.randf_range(0.0, TAU), scale))
	return transforms


func can_place_static(pos: Vector3, radius: float, allow_near_path: bool = false) -> bool:
	var p := Vector2(pos.x, pos.z)
	if p.length() < 12.0:
		return false
	if _inside_yurt_clear_area(p):
		return false
	if not allow_near_path and _inside_main_walk_path(p):
		return false
	if _near_existing_important_object(p, radius):
		return false
	return true


func can_place_plant(pos: Vector3, normal: Vector3, zone: int) -> bool:
	var p := Vector2(pos.x, pos.z)
	if p.length() < 11.5:
		return false
	if normal.y < 0.78:
		return false
	if zone == ZONE_NO_SPAWN:
		return false
	return true


func align_node_to_normal_soft(node: Node3D, normal: Vector3, strength: float) -> void:
	var up := Vector3.UP.lerp(normal, strength).normalized()
	var forward := -node.global_transform.basis.z
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var right := forward.cross(up).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	forward = up.cross(right).normalized()
	node.global_transform.basis = Basis(right, up, -forward).orthonormalized().scaled(node.scale)


func _place_asset_or_fallback(asset_id: String, node_name: String, p: Vector2, scale_value: Vector3, rotation_y: float, sink: float, role: String) -> Node3D:
	var pos := _terrain_position(p, -sink)
	var normal: Vector3 = terrain_sampler.normal_at(p.x, p.y)
	var scene: PackedScene = null
	if (allow_heavy_hero_assets or not (role in ["hero_rocks", "hero_tree"])) and not skipped_assets.has(asset_id):
		scene = registry.get_scene_for_asset(asset_id, use_lod_assets)

	var node: Node3D = null
	if scene != null:
		node = _instantiate_single_asset_variant(scene, node_name, node_name.hash(), role)
	if node == null:
		_register_skipped(asset_id)
		node = _make_procedural_for_role(node_name, role)
	add_child(node)

	node.position = pos
	node.rotation.y = rotation_y
	node.scale = scale_value
	if role in ["hero_rocks", "distant_rocks"]:
		align_node_to_normal_soft(node, normal, 0.28)
	elif role == "dry_shrub":
		align_node_to_normal_soft(node, normal, 0.12)

	var casts_shadow := role in ["hero_rocks", "hero_tree", "dry_shrub"]
	MATERIAL_CONTROLLER_SCRIPT.set_shadow_recursive(node, GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	if role in ["hero_rocks", "distant_rocks"]:
		rock_count += 1
	elif role in ["hero_tree", "distant_tree"]:
		tree_count += 1
	elif role == "dry_shrub":
		shrub_count += 1
	return node


func _instantiate_single_asset_variant(scene: PackedScene, node_name: String, variant_key: int, role: String) -> Node3D:
	var source_root := scene.instantiate()
	var variants: Array[MeshInstance3D] = []
	_collect_mesh_instances(source_root, variants)
	if variants.is_empty():
		source_root.free()
		return null

	var source: MeshInstance3D = variants[posmod(variant_key, variants.size())]
	var root := Node3D.new()
	root.name = node_name
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = source.name
	mesh_instance.mesh = source.mesh
	mesh_instance.transform.basis = source.transform.basis
	root.add_child(mesh_instance)
	MATERIAL_CONTROLLER_SCRIPT.prepare_imported_asset_materials(root, role)
	source_root.free()
	return root


func _build_asset_variant_multimeshes(
	asset_id: String,
	transforms: Array[Transform3D],
	node_name: String,
	role: String,
	fallback_mesh: Mesh,
	fallback_material: Material
) -> int:
	if transforms.is_empty():
		return 0
	if not use_multimesh_flora or skipped_assets.has(asset_id):
		var fallback_helper = MULTIMESH_SCRIPT.new()
		fallback_helper.build_chunked_multimesh_from_mesh(self, fallback_mesh, fallback_material, transforms, node_name + "Fallback", flora_chunk_size, flora_visibility_range)
		return transforms.size()

	var scene: PackedScene = registry.get_scene_for_asset(asset_id, true)
	if scene == null:
		_register_skipped(asset_id)
		var missing_helper = MULTIMESH_SCRIPT.new()
		missing_helper.build_chunked_multimesh_from_mesh(self, fallback_mesh, fallback_material, transforms, node_name + "Fallback", flora_chunk_size, flora_visibility_range)
		return transforms.size()

	var source_root := scene.instantiate()
	var variants: Array[MeshInstance3D] = []
	_collect_mesh_instances(source_root, variants)
	if variants.is_empty():
		source_root.free()
		_register_skipped(asset_id)
		var empty_helper = MULTIMESH_SCRIPT.new()
		empty_helper.build_chunked_multimesh_from_mesh(self, fallback_mesh, fallback_material, transforms, node_name + "Fallback", flora_chunk_size, flora_visibility_range)
		return transforms.size()

	var transform_sets: Array[Array] = []
	transform_sets.resize(variants.size())
	for variant_index in range(variants.size()):
		transform_sets[variant_index] = []
	for transform_index in range(transforms.size()):
		var variant_index := transform_index % variants.size()
		var variant_transform: Transform3D = transforms[transform_index]
		variant_transform.basis = variant_transform.basis * variants[variant_index].transform.basis
		transform_sets[variant_index].append(variant_transform)

	var helper = MULTIMESH_SCRIPT.new()
	for variant_index in range(variants.size()):
		var prepared_mesh := _prepared_mesh_copy(variants[variant_index].mesh, role)
		if prepared_mesh == null:
			continue
		var variant_transforms: Array[Transform3D] = []
		variant_transforms.assign(transform_sets[variant_index])
		helper.build_chunked_multimesh_from_mesh(
			self,
			prepared_mesh,
			null,
			variant_transforms,
			"%s_Variant%02d" % [node_name, variant_index + 1],
			flora_chunk_size,
			flora_visibility_range
		)
	source_root.free()
	return transforms.size()


func _prepared_mesh_copy(source: Mesh, role: String) -> Mesh:
	if source == null:
		return null
	var mesh := source.duplicate() as Mesh
	for surface in range(mesh.get_surface_count()):
		var prepared: Material = MATERIAL_CONTROLLER_SCRIPT.prepared_material_copy(mesh.surface_get_material(surface), role)
		if prepared != null:
			mesh.surface_set_material(surface, prepared)
	return mesh


func _collect_mesh_instances(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, output)


func _make_procedural_for_role(node_name: String, role: String) -> Node3D:
	if role in ["hero_rocks", "distant_rocks"]:
		return _make_procedural_rock(node_name)
	if role in ["hero_tree", "distant_tree"]:
		return _make_procedural_tree(node_name)
	if role == "dry_shrub":
		return _make_procedural_shrub(node_name)
	return Node3D.new()


func _make_procedural_rock(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "LowPolyRockMesh"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.18
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, ROCK_MATERIAL)
	root.add_child(mesh_instance)
	return root


func _make_procedural_tree(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name

	var trunk := MeshInstance3D.new()
	trunk.name = "MutedTrunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 3.8
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.9
	trunk.set_surface_override_material(0, _simple_material(Color(0.18, 0.13, 0.09, 1.0)))
	root.add_child(trunk)

	var crown := MeshInstance3D.new()
	crown.name = "WindBentCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.35
	crown_mesh.height = 1.35
	crown_mesh.radial_segments = 7
	crown_mesh.rings = 3
	crown.mesh = crown_mesh
	crown.position = Vector3(0.28, 4.0, 0.0)
	crown.scale = Vector3(1.55, 0.62, 0.92)
	crown.set_surface_override_material(0, LEAF_MATERIAL)
	root.add_child(crown)
	return root


func _make_procedural_shrub(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	for i in range(3):
		var clump := MeshInstance3D.new()
		clump.name = "ShrubClump_%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.42 + float(i) * 0.08
		mesh.height = 0.7
		mesh.radial_segments = 6
		mesh.rings = 3
		clump.mesh = mesh
		clump.position = Vector3(float(i - 1) * 0.28, 0.24, sin(float(i) * 1.7) * 0.22)
		clump.scale = Vector3(1.2, 0.62, 0.85)
		clump.set_surface_override_material(0, LEAF_MATERIAL)
		root.add_child(clump)
	return root


func _make_grass_clump_mesh(tall: bool = false) -> Mesh:
	var height := 0.62 if not tall else 1.08
	var width := 0.16 if not tall else 0.20
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()

	for i in range(5):
		var yaw := TAU * float(i) / 5.0
		var right := Vector3(cos(yaw), 0.0, sin(yaw)) * width
		var lean := Vector3(cos(yaw + 0.55), 0.0, sin(yaw + 0.55)) * (0.08 if not tall else 0.16)
		var base := vertices.size()
		vertices.append(-right)
		vertices.append(right)
		vertices.append(Vector3(lean.x, height * (0.82 + float(i % 2) * 0.16), lean.z))
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		colors.append(Color(0.42, 0.44, 0.30, 1.0))
		colors.append(Color(0.32, 0.35, 0.22, 1.0))
		colors.append(Color(0.58, 0.56, 0.36, 1.0))

	return _mesh_from_arrays(vertices, indices, colors)


func _make_flower_mesh() -> Mesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	var base_color := Color(0.68, 0.64, 0.50, 1.0)
	var stem_color := Color(0.33, 0.36, 0.24, 1.0)

	for i in range(3):
		var yaw := TAU * float(i) / 3.0
		var right := Vector3(cos(yaw), 0.0, sin(yaw)) * 0.06
		var top := Vector3(cos(yaw + 0.4) * 0.04, 0.34, sin(yaw + 0.4) * 0.04)
		var base := vertices.size()
		vertices.append(-right)
		vertices.append(right)
		vertices.append(top)
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		colors.append(stem_color)
		colors.append(stem_color)
		colors.append(base_color)

	return _mesh_from_arrays(vertices, indices, colors)


func _mesh_from_arrays(vertices: PackedVector3Array, indices: PackedInt32Array, colors: PackedColorArray) -> Mesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(mesh, 0)
	surface_tool.generate_normals()
	return surface_tool.commit()


func _mesh_from_asset(asset_id: String, fallback_mesh: Mesh) -> Mesh:
	if not use_multimesh_flora:
		return fallback_mesh
	if skipped_assets.has(asset_id):
		return fallback_mesh
	var scene: PackedScene = registry.get_scene_for_asset(asset_id, true)
	if scene == null:
		_register_skipped(asset_id)
		return fallback_mesh
	var instance: Node = scene.instantiate()
	var mesh: Mesh = _find_first_mesh(instance)
	instance.queue_free()
	if mesh == null:
		_register_skipped(asset_id)
		return fallback_mesh
	return mesh


func _find_first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			return mesh_instance.mesh
	for child in node.get_children():
		var child_mesh := _find_first_mesh(child)
		if child_mesh != null:
			return child_mesh
	return null


func _terrain_position(p: Vector2, y_offset: float) -> Vector3:
	return Vector3(p.x, terrain_sampler.height_at(p.x, p.y) + y_offset, p.y)


func _inside_yurt_clear_area(p: Vector2) -> bool:
	return p.length() < 13.2 or (abs(p.x) < 4.4 and p.y < -7.5 and p.y > -35.0)


func _inside_main_walk_path(p: Vector2) -> bool:
	return terrain_sampler.path_distance(p.x, p.y) < 4.2


func _near_existing_important_object(p: Vector2, radius: float) -> bool:
	var objects := [
		Vector2(0.0, -10.0),
		Vector2(0.0, -63.0),
		Vector2(0.0, -92.0),
		Vector2(56.0, -118.0),
		Vector2(-82.0, 88.0)
	]
	for object_pos in objects:
		if p.distance_to(object_pos) < radius + 4.0:
			return true
	return false


func _register_skipped(asset_id: String) -> void:
	if skipped_assets.has(asset_id):
		return
	skipped_assets.append(asset_id)


func _simple_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	return material
