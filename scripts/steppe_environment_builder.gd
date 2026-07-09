extends Node3D

const STEPPE_GROUND_MATERIAL: Material = preload("res://materials/mat_steppe_ground.tres")
const SKY_DOME_MATERIAL: Material = preload("res://materials/mat_sky_dome.tres")
const ENHANCED_TERRAIN_MATERIAL: Material = preload("res://materials/polyhaven/mat_steppe_terrain_blend.tres")
const TERRAIN_HEIGHT_SAMPLER_SCRIPT: Script = preload("res://scripts/environment/terrain_height_sampler.gd")
const STEPPE_TERRAIN_BUILDER_SCRIPT: Script = preload("res://scripts/environment/steppe_terrain_builder.gd")
const POLYHAVEN_SCATTER_SCRIPT: Script = preload("res://scripts/environment/polyhaven_landscape_scatter.gd")
const AMBIENT_FAUNA_SCRIPT: Script = preload("res://scripts/environment/ambient_fauna_controller.gd")
const MOUNTAIN_MEGAWALL_SCENE: PackedScene = preload("res://systems/mountain_megawall/MountainMegawallRoot.tscn")

const PYLON_SCENE_PATH := "res://assets/models/props/lowpoly_power_pylon_no_wires.glb"
const GRASS_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_grass_patch.glb"
const FLOWER_WHITE_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_flower_white.glb"
const FLOWER_RED_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_flower_red.glb"
const FLOWER_YELLOW_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_flower_yellow.glb"
const HORSE_BUILDER_SCRIPT: Script = preload("res://scripts/procedural_horse_builder.gd")
const HORSE_GUARD_ZONE_SCRIPT: Script = preload("res://scripts/horse_guard_zone.gd")
const ALBASTY_SPAWNER_SCRIPT: Script = preload("res://scripts/albasty_spawner.gd")
const BACKDROP_DIR := "res://assets/textures/backdrops"
const TEX_SALT_FLAT := BACKDROP_DIR + "/balkhash_salt_flat_01.png"
const TEX_SHORE_STRIP := BACKDROP_DIR + "/balkhash_shore_strip_01.png"
const TEX_BACKDROP_MAIN := BACKDROP_DIR + "/balkhash_far_backdrop_main_01.png"
const TEX_BACKDROP_ALT := BACKDROP_DIR + "/balkhash_far_backdrop_alt_01.png"
const TEX_INDUSTRIAL := BACKDROP_DIR + "/balkhash_industrial_smudge_01.png"
const TEX_HORIZON_FOG := BACKDROP_DIR + "/balkhash_horizon_fog_01.png"
const TEX_LOW_CLOUD_DARK := "res://assets/textures/sky/cloud_dark_ash_red_alpha.png"
const TEX_LOW_CLOUD_ROSE := "res://assets/textures/sky/cloud_rose_ash_red_alpha.png"

@export var ground_size: float = 200.0
@export var sky_radius: float = 520.0
@export var pylon_position := Vector3(0.0, 0.0, -92.0)
@export var distant_pylon_position := Vector3(56.0, 0.0, -118.0)
@export var distant_pylon_scale: float = 0.58
@export var rear_pylon_position := Vector3(-82.0, 0.0, 88.0)
@export var rear_pylon_scale: float = 0.52
@export_range(0.0, 3.0, 0.1) var flower_density_multiplier: float = 1.0
@export var enable_albasty_prototype: bool = true
@export var albasty_spawn_delay: float = 5.0
@export var albasty_respawn_delay: float = 35.0

@export_group("Terrain")
@export var terrain_enabled: bool = true
@export var terrain_size: float = 620.0
@export var terrain_resolution: int = 257
@export var terrain_height_scale: float = 1.45
@export var terrain_seed: int = 9669
@export var yurt_flat_radius: float = 14.0
@export var yurt_blend_radius: float = 26.0
@export var full_map_base_enabled: bool = true
@export var full_map_base_size: float = 620.0
@export var full_map_base_top_y: float = -4.0
@export var terrain_mesh_collision_enabled: bool = false

@export_group("Poly Haven Landscape")
@export var polyhaven_scatter_enabled: bool = true
@export_range(0.0, 3.0, 0.1) var vegetation_density_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.1) var hero_asset_density_multiplier: float = 1.0
@export var allow_heavy_hero_assets: bool = true
@export var use_lod_assets: bool = true
@export var use_multimesh_flora: bool = true
@export var enable_far_impostors: bool = true
@export var ambient_fauna_enabled: bool = true

@export_group("Vista Visual Overlays")
@export var stage1_sky_cards_enabled: bool = false
@export var vista_ground_cards_enabled: bool = false
@export var vista_horizon_haze_cards_enabled: bool = false
@export var vista_low_cloud_cards_enabled: bool = false

@export_group("Mountain Megawall")
@export var mountain_megawall_enabled: bool = true
@export var mountain_megawall_yaw_degrees: float = 90.0
@export_range(0.0, 1.0, 0.01) var mountain_megawall_day_night: float = 0.18
@export_range(0.0, 2.0, 0.01) var mountain_megawall_haze_strength: float = 0.86

@export_group("Landscape Debug")
@export var debug_show_spawn_zones: bool = false
@export var debug_disable_flora: bool = false
@export var debug_disable_hero_rocks: bool = false
@export var debug_disable_hero_trees: bool = false

var _terrain_sampler
var _terrain_root: Node3D


func _ready() -> void:
	_clear_existing_geometry()
	if terrain_enabled:
		_build_enhanced_terrain()
	else:
		_build_ground()
	if full_map_base_enabled:
		_build_full_map_safety_base()

	_build_sky_dome()
	if stage1_sky_cards_enabled:
		_build_stage1_sky_atmosphere()
	_build_vista_environment()
	_build_mountain_megawall()
	_build_yurt_entrance_marker()
	_build_power_pylon()
	_build_secondary_powerline()
	_build_rear_powerline()

	if polyhaven_scatter_enabled:
		_build_polyhaven_landscape()
	else:
		_build_steppe_vegetation()

	_build_ambient_fauna()
	_build_albasty_prototype()
	_extend_player_interaction_ray()


func _clear_existing_geometry() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func _build_enhanced_terrain() -> void:
	_terrain_sampler = TERRAIN_HEIGHT_SAMPLER_SCRIPT.new()
	_terrain_sampler.seed_value = terrain_seed
	_terrain_sampler.base_height_scale = terrain_height_scale
	_terrain_sampler.yurt_flat_radius = yurt_flat_radius
	_terrain_sampler.yurt_blend_radius = yurt_blend_radius
	_terrain_sampler.setup()

	var terrain_builder = STEPPE_TERRAIN_BUILDER_SCRIPT.new()
	terrain_builder.sampler = _terrain_sampler
	terrain_builder.terrain_size = terrain_size
	terrain_builder.terrain_resolution = terrain_resolution
	terrain_builder.material = ENHANCED_TERRAIN_MATERIAL
	terrain_builder.collision_enabled = terrain_mesh_collision_enabled
	terrain_builder.debug_show_spawn_zones = debug_show_spawn_zones

	_terrain_root = terrain_builder.build(self)
	if _terrain_root == null:
		push_warning("Enhanced terrain failed; using flat ground fallback.")
		_build_ground()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "SteppeGround"
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ground_size, 0.08, ground_size)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, -0.04, 0.0)
	mesh_instance.set_surface_override_material(0, STEPPE_GROUND_MATERIAL)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(ground_size, 0.08, ground_size)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.04, 0.0)
	body.add_child(collision)


func _build_full_map_safety_base() -> void:
	var thickness := 0.16
	var body := StaticBody3D.new()
	body.name = "FullMapSafetyBase"
	add_child(body)

	var center_y := full_map_base_top_y - thickness * 0.5
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FullMapSafetyBaseMesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(full_map_base_size, thickness, full_map_base_size)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, center_y, 0.0)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, STEPPE_GROUND_MATERIAL)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "FullMapSafetyBaseCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(full_map_base_size, thickness, full_map_base_size)
	collision.shape = shape
	collision.position = Vector3(0.0, center_y, 0.0)
	body.add_child(collision)


func has_walkable_ground_at(x: float, z: float) -> bool:
	if _terrain_sampler != null and absf(x) <= terrain_size * 0.5 and absf(z) <= terrain_size * 0.5:
		return true
	if absf(x) <= ground_size * 0.5 and absf(z) <= ground_size * 0.5:
		return true
	if full_map_base_enabled and absf(x) <= full_map_base_size * 0.5 and absf(z) <= full_map_base_size * 0.5:
		return true
	return false


func get_walkable_ground_y(x: float, z: float) -> float:
	if _terrain_sampler != null and absf(x) <= terrain_size * 0.5 and absf(z) <= terrain_size * 0.5:
		return float(_terrain_sampler.height_at(x, z))
	if absf(x) <= ground_size * 0.5 and absf(z) <= ground_size * 0.5:
		return 0.0
	if full_map_base_enabled and absf(x) <= full_map_base_size * 0.5 and absf(z) <= full_map_base_size * 0.5:
		return full_map_base_top_y
	return -INF


func _build_sky_dome() -> void:
	var sky := MeshInstance3D.new()
	sky.name = "SkyDome"
	var mesh := SphereMesh.new()
	mesh.radius = sky_radius
	mesh.height = sky_radius * 2.0
	mesh.radial_segments = 64
	mesh.rings = 32
	sky.mesh = mesh
	sky.set_surface_override_material(0, SKY_DOME_MATERIAL)
	add_child(sky)


func _build_stage1_sky_atmosphere() -> void:
	var root := Node3D.new()
	root.name = "Stage1SkyAtmosphereRoot"
	add_child(root)

	var front_cloud_mat := _make_unshaded_alpha_material("mat_stage1_front_ash_cloud_mass", TEX_LOW_CLOUD_DARK, Color(0.42, 0.34, 0.34, 0.46), true)
	var rose_cloud_mat := _make_unshaded_alpha_material("mat_stage1_rose_cloud_mass", TEX_LOW_CLOUD_ROSE, Color(0.58, 0.36, 0.34, 0.36), true)

	var front_bank := _add_backdrop_card(root, "FrontAshRedSkyBank", Vector3(0.0, 128.0, -330.0), Vector2(560.0, 170.0), front_cloud_mat, 0.0)
	front_bank.rotation_degrees.z = -1.2
	var low_front_bank := _add_backdrop_card(root, "LowFrontDirtyRoseCloudShelf", Vector3(24.0, 88.0, -292.0), Vector2(470.0, 118.0), rose_cloud_mat, 0.0)
	low_front_bank.rotation_degrees.z = 1.5
	var rear_bank := _add_backdrop_card(root, "RearAshSkyBank", Vector3(-20.0, 122.0, 318.0), Vector2(500.0, 148.0), front_cloud_mat, deg_to_rad(180.0))
	rear_bank.rotation_degrees.z = 0.8
	var left_bank := _add_backdrop_card(root, "LeftBalkhashSkyShelf", Vector3(-310.0, 106.0, -24.0), Vector2(420.0, 130.0), rose_cloud_mat, deg_to_rad(90.0))
	left_bank.rotation_degrees.z = -1.0


func _build_yurt_entrance_marker() -> void:
	var marker := Marker3D.new()
	marker.name = "YurtEntranceMarker"
	marker.position = Vector3(0.0, 0.0, -10.8)
	marker.add_to_group("yurt_entrance")
	add_child(marker)


func _build_power_pylon() -> void:
	_add_power_pylon(self, "PowerPylon", pylon_position, 1.0, true)


func _build_secondary_powerline() -> void:
	var root := Node3D.new()
	root.name = "DistantPowerlineRoot"
	add_child(root)

	_add_power_pylon(root, "DistantPowerPylon", distant_pylon_position, distant_pylon_scale, false)

	var wire_mat := _make_material("mat_main_scene_distant_wire", Color(0.018, 0.017, 0.015, 1.0))
	var pylon_a := pylon_position
	var pylon_b := distant_pylon_position
	var b_scale := distant_pylon_scale

	_build_sagging_wire(root, "DistantWire_Top_Front", pylon_a + Vector3(6.1, 29.4, -1.6), pylon_b + Vector3(-5.0 * b_scale, 29.4 * b_scale, -1.2 * b_scale), 1.15, wire_mat, 22)
	_build_sagging_wire(root, "DistantWire_Top_Back", pylon_a + Vector3(6.1, 29.4, 1.6), pylon_b + Vector3(-5.0 * b_scale, 29.4 * b_scale, 1.2 * b_scale), 1.18, wire_mat, 22)
	_build_sagging_wire(root, "DistantWire_Mid_Front", pylon_a + Vector3(4.7, 23.6, -1.8), pylon_b + Vector3(-3.8 * b_scale, 23.6 * b_scale, -1.4 * b_scale), 0.92, wire_mat, 20)
	_build_sagging_wire(root, "DistantWire_Mid_Back", pylon_a + Vector3(4.7, 23.6, 1.8), pylon_b + Vector3(-3.8 * b_scale, 23.6 * b_scale, 1.4 * b_scale), 0.95, wire_mat, 20)


func _build_rear_powerline() -> void:
	var root := Node3D.new()
	root.name = "RearPowerlineRoot"
	add_child(root)

	_add_power_pylon(root, "RearDistantPowerPylon", rear_pylon_position, rear_pylon_scale, false)

	var wire_mat := _make_material("mat_main_scene_rear_wire", Color(0.016, 0.015, 0.013, 1.0))
	var pylon_a := pylon_position
	var pylon_b := rear_pylon_position
	var b_scale := rear_pylon_scale

	_build_sagging_wire(root, "RearWire_Top_Front", pylon_a + Vector3(-5.8, 29.2, -1.6), pylon_b + Vector3(4.8 * b_scale, 29.2 * b_scale, -1.2 * b_scale), 1.75, wire_mat, 26)
	_build_sagging_wire(root, "RearWire_Top_Back", pylon_a + Vector3(-5.8, 29.2, 1.6), pylon_b + Vector3(4.8 * b_scale, 29.2 * b_scale, 1.2 * b_scale), 1.78, wire_mat, 26)
	_build_sagging_wire(root, "RearWire_Mid_Front", pylon_a + Vector3(-4.4, 23.4, -1.8), pylon_b + Vector3(3.6 * b_scale, 23.4 * b_scale, -1.4 * b_scale), 1.35, wire_mat, 24)
	_build_sagging_wire(root, "RearWire_Mid_Back", pylon_a + Vector3(-4.4, 23.4, 1.8), pylon_b + Vector3(3.6 * b_scale, 23.4 * b_scale, 1.4 * b_scale), 1.38, wire_mat, 24)


func _add_power_pylon(parent: Node3D, node_name: String, position: Vector3, scale_value: float, with_collision: bool) -> Node3D:
	var pylon_root := Node3D.new()
	pylon_root.name = node_name
	pylon_root.position = position
	pylon_root.scale = Vector3.ONE * scale_value
	parent.add_child(pylon_root)

	var pylon_scene := load(PYLON_SCENE_PATH) as PackedScene
	if pylon_scene != null:
		var pylon_model := pylon_scene.instantiate()
		pylon_model.name = "PowerPylonModel"
		pylon_root.add_child(pylon_model)

	if not with_collision:
		return pylon_root

	var base_collision := StaticBody3D.new()
	base_collision.name = "PowerPylonBaseCollision"
	base_collision.position = Vector3(0.0, 0.6, 0.0)
	pylon_root.add_child(base_collision)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 1.2, 6.0)
	collision.shape = shape
	base_collision.add_child(collision)
	return pylon_root


func _build_vista_environment() -> void:
	var root := Node3D.new()
	root.name = "VistaEnvironmentRoot"
	add_child(root)

	var shore_mat := _make_unshaded_alpha_material("mat_vista_dusty_far_shore", TEX_SHORE_STRIP, Color(0.56, 0.48, 0.37, 0.72), true)
	var rear_shore_mat := _make_unshaded_alpha_material("mat_vista_pale_rear_shore", TEX_BACKDROP_ALT, Color(0.61, 0.56, 0.49, 0.46), true)
	var industrial_mat := _make_unshaded_alpha_material("mat_vista_industrial_silhouette", "", Color(0.07, 0.073, 0.068, 0.45), true)
	var industrial_smudge_mat := _make_unshaded_alpha_material("mat_vista_industrial_smudge", TEX_INDUSTRIAL, Color(0.18, 0.17, 0.16, 0.22), true)

	if vista_ground_cards_enabled:
		var salt_mat := _make_unshaded_alpha_material("mat_vista_left_salt_flat_blend", TEX_SALT_FLAT, Color(0.58, 0.54, 0.43, 0.58), true)
		var mineral_mud_mat := _make_unshaded_alpha_material("mat_vista_mineral_mud_edge", TEX_SHORE_STRIP, Color(0.47, 0.43, 0.34, 0.72), true)
		var shallow_water_mat := _make_unshaded_alpha_material("mat_vista_brackish_shallow_water", "", Color(0.30, 0.43, 0.42, 0.42), true)
		var lake_water_mat := _make_lake_water_material()
		_build_lake_vista_left(root, salt_mat, mineral_mud_mat, shallow_water_mat)
		_add_horizontal_plane(root, "LakeWaterFar", Vector3(-154.0, 0.018, -20.0), Vector2(92.0, 212.0), lake_water_mat)

	_build_distant_shore_backdrop(root, shore_mat, rear_shore_mat, vista_ground_cards_enabled)
	_build_industrial_horizon_silhouettes(root, industrial_mat, industrial_smudge_mat)
	if vista_horizon_haze_cards_enabled:
		var haze_mat := _make_unshaded_alpha_material("mat_vista_low_horizon_haze", TEX_HORIZON_FOG, Color(0.55, 0.53, 0.49, 0.48), true)
		var upper_haze_mat := _make_unshaded_alpha_material("mat_vista_upper_dirty_rose_haze", TEX_HORIZON_FOG, Color(0.52, 0.46, 0.44, 0.23), true)
		_build_horizon_haze_band(root, haze_mat, upper_haze_mat)
	if vista_low_cloud_cards_enabled:
		var low_cloud_dark_mat := _make_unshaded_alpha_material("mat_vista_low_cloud_dark", TEX_LOW_CLOUD_DARK, Color(0.34, 0.29, 0.29, 0.30), true)
		var low_cloud_rose_mat := _make_unshaded_alpha_material("mat_vista_low_cloud_rose", TEX_LOW_CLOUD_ROSE, Color(0.49, 0.37, 0.36, 0.22), true)
		_build_low_cloud_mass_cards(root, low_cloud_dark_mat, low_cloud_rose_mat)


func _build_mountain_megawall() -> void:
	if not mountain_megawall_enabled:
		return

	var megawall := MOUNTAIN_MEGAWALL_SCENE.instantiate()
	megawall.name = "MountainMegawallRoot"
	if megawall.has_method("set_mountain_direction_yaw_degrees"):
		megawall.set_mountain_direction_yaw_degrees(mountain_megawall_yaw_degrees)
	else:
		megawall.set("mountain_direction_yaw_degrees", mountain_megawall_yaw_degrees)
	megawall.set("day_night", mountain_megawall_day_night)
	megawall.set("haze_strength", mountain_megawall_haze_strength)
	add_child(megawall)


func _build_lake_vista_left(parent: Node3D, salt_mat: Material, mineral_mud_mat: Material, shallow_water_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "LakeVistaLeft"
	parent.add_child(root)

	_add_horizontal_plane(root, "DrySaltFlatBlendLeft", Vector3(-92.0, 0.016, -22.0), Vector2(17.0, 176.0), salt_mat)
	_add_horizontal_plane(root, "MineralMudLakeEdge", Vector3(-103.5, 0.019, -20.0), Vector2(18.0, 196.0), mineral_mud_mat)
	_add_horizontal_plane(root, "BrackishShallowWater", Vector3(-118.0, 0.021, -22.0), Vector2(28.0, 204.0), shallow_water_mat)


func _build_distant_shore_backdrop(parent: Node3D, shore_mat: Material, rear_shore_mat: Material, include_ground_card: bool) -> void:
	var root := Node3D.new()
	root.name = "DistantShoreBackdrop"
	parent.add_child(root)

	if include_ground_card:
		_add_horizontal_plane(root, "FarExposedShoreFlat", Vector3(-204.0, 0.026, -18.0), Vector2(31.0, 216.0), shore_mat)
	_add_backdrop_card(root, "LongLowDustyShoreStrip", Vector3(-214.0, 4.3, -18.0), Vector2(250.0, 8.5), shore_mat, deg_to_rad(90.0))
	_add_backdrop_card(root, "PaleRearShoreWash", Vector3(-220.0, 6.2, 58.0), Vector2(170.0, 11.0), rear_shore_mat, deg_to_rad(90.0))


func _build_industrial_horizon_silhouettes(parent: Node3D, silhouette_mat: Material, smudge_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "IndustrialHorizonSilhouettes"
	parent.add_child(root)

	_add_backdrop_card(root, "IndustrialSmudgeCard", Vector3(-204.0, 6.0, -56.0), Vector2(78.0, 11.0), smudge_mat, deg_to_rad(90.0))
	_add_silhouette_box(root, "LowFactoryBlockA", Vector3(-198.0, 1.45, -78.0), Vector3(0.9, 2.9, 12.0), silhouette_mat)
	_add_silhouette_box(root, "LowFactoryBlockB", Vector3(-198.2, 1.1, -62.0), Vector3(0.9, 2.2, 18.0), silhouette_mat)
	_add_silhouette_box(root, "ThinChimneyA", Vector3(-197.8, 5.0, -68.5), Vector3(0.55, 10.0, 0.55), silhouette_mat)
	_add_silhouette_box(root, "ThinChimneyB", Vector3(-197.9, 4.1, -51.0), Vector3(0.48, 8.2, 0.48), silhouette_mat)
	_add_silhouette_box(root, "DistantWarehouseSlab", Vector3(-199.0, 1.0, 72.0), Vector3(0.9, 2.0, 22.0), silhouette_mat)

	_add_horizon_power_tower(root, "TinyPowerlineTowerA", Vector3(-196.0, 0.18, 18.0), 8.8, 5.6, silhouette_mat)
	_add_horizon_power_tower(root, "TinyPowerlineTowerB", Vector3(-198.0, 0.16, 46.0), 7.2, 4.8, silhouette_mat)
	_add_silhouette_segment(root, "FarPowerCableA", Vector3(-196.4, 7.2, 18.0), Vector3(-198.4, 6.4, 46.0), 0.07, silhouette_mat)
	_add_silhouette_segment(root, "FarPowerCableB", Vector3(-196.4, 6.0, 18.0), Vector3(-198.4, 5.4, 46.0), 0.06, silhouette_mat)


func _build_horizon_haze_band(parent: Node3D, haze_mat: Material, upper_haze_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "HorizonHazeBand"
	parent.add_child(root)

	_add_backdrop_card(root, "LowDustHazeCard", Vector3(-162.0, 8.3, -16.0), Vector2(276.0, 20.0), haze_mat, deg_to_rad(90.0))
	_add_backdrop_card(root, "UpperDirtyRoseHazeCard", Vector3(-168.0, 18.0, -10.0), Vector2(288.0, 28.0), upper_haze_mat, deg_to_rad(90.0))


func _build_low_cloud_mass_cards(parent: Node3D, dark_mat: Material, rose_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "LowCloudMassCards"
	parent.add_child(root)

	var west_bank := _add_backdrop_card(root, "LowAshRedCloudMassWest", Vector3(-184.0, 31.0, -92.0), Vector2(160.0, 34.0), dark_mat, deg_to_rad(90.0))
	west_bank.rotation_degrees.z = -1.5
	var long_bank := _add_backdrop_card(root, "LowDirtyRoseCloudMassCenter", Vector3(-198.0, 27.0, 12.0), Vector2(218.0, 42.0), rose_mat, deg_to_rad(90.0))
	long_bank.rotation_degrees.z = 1.0
	var north_bank := _add_backdrop_card(root, "LowGrayCloudMassNorth", Vector3(-188.0, 35.0, 104.0), Vector2(132.0, 30.0), dark_mat, deg_to_rad(90.0))
	north_bank.rotation_degrees.z = -0.75


func _build_steppe_vegetation() -> void:
	var vegetation := Node3D.new()
	vegetation.name = "SteppeVegetation"
	add_child(vegetation)

	var grass_scene := load(GRASS_SCENE_PATH) as PackedScene
	var white_scene := load(FLOWER_WHITE_SCENE_PATH) as PackedScene
	var red_scene := load(FLOWER_RED_SCENE_PATH) as PackedScene
	var yellow_scene := load(FLOWER_YELLOW_SCENE_PATH) as PackedScene

	var near_exit_positions := [
		Vector3(-5.8, 0.0, -14.5), Vector3(-3.6, 0.0, -16.0), Vector3(-1.2, 0.0, -13.6),
		Vector3(2.4, 0.0, -15.2), Vector3(5.2, 0.0, -17.8), Vector3(-7.4, 0.0, -20.8),
		Vector3(-4.1, 0.0, -22.6), Vector3(0.8, 0.0, -20.0), Vector3(4.7, 0.0, -23.5),
		Vector3(7.6, 0.0, -19.4), Vector3(-2.8, 0.0, -27.5), Vector3(3.3, 0.0, -29.4)
	]
	var path_positions := [
		Vector3(-9.0, 0.0, -34.0), Vector3(-2.5, 0.0, -38.0), Vector3(6.0, 0.0, -42.0),
		Vector3(11.0, 0.0, -49.0), Vector3(-7.5, 0.0, -54.0), Vector3(3.5, 0.0, -61.0),
		Vector3(13.5, 0.0, -68.0), Vector3(-12.0, 0.0, -73.0)
	]
	var sparse_far_positions := [
		Vector3(-18.0, 0.0, -86.0), Vector3(19.0, 0.0, -82.0), Vector3(-8.0, 0.0, -94.0)
	]

	_scatter_patch(vegetation, grass_scene, white_scene, red_scene, yellow_scene, near_exit_positions, 0.95, 1.35, 0.0)
	_scatter_patch(vegetation, grass_scene, white_scene, red_scene, null, path_positions, 0.75, 1.1, 100.0)
	_scatter_patch(vegetation, grass_scene, white_scene, null, null, sparse_far_positions, 0.55, 0.85, 200.0)


func _build_polyhaven_landscape() -> void:
	if _terrain_sampler == null:
		push_warning("Poly Haven scatter skipped: terrain sampler missing.")
		_build_steppe_vegetation()
		return

	var scatter = POLYHAVEN_SCATTER_SCRIPT.new()
	scatter.name = "PolyHavenLandscapeScatter"
	scatter.terrain_sampler = _terrain_sampler
	scatter.density_multiplier = vegetation_density_multiplier
	scatter.hero_density_multiplier = hero_asset_density_multiplier
	scatter.allow_heavy_hero_assets = allow_heavy_hero_assets
	scatter.use_lod_assets = use_lod_assets
	scatter.use_multimesh_flora = use_multimesh_flora
	scatter.seed_value = terrain_seed + 101
	scatter.debug_disable_flora = debug_disable_flora
	scatter.debug_disable_hero_rocks = debug_disable_hero_rocks
	scatter.debug_disable_hero_trees = debug_disable_hero_trees
	add_child(scatter)
	scatter.build()


func _build_ambient_fauna() -> void:
	if not ambient_fauna_enabled:
		return
	var fauna = AMBIENT_FAUNA_SCRIPT.new()
	fauna.name = "AmbientFaunaRoot"
	fauna.seed_value = terrain_seed + 303
	fauna.enabled = true
	add_child(fauna)


func _build_albasty_prototype() -> void:
	if not enable_albasty_prototype:
		return

	var prototype_root := Node3D.new()
	prototype_root.name = "AlbastyHorsePrototype"
	add_child(prototype_root)

	var horse_zone_position := Vector3(0.0, 0.0, -63.0)
	var horse_positions := [
		Vector3(-4.0, 0.0, -64.5),
		Vector3(-1.3, 0.0, -61.2),
		Vector3(2.1, 0.0, -65.0),
		Vector3(4.8, 0.0, -61.8),
	]
	var horse_rotations := [
		deg_to_rad(18.0),
		deg_to_rad(-26.0),
		deg_to_rad(34.0),
		deg_to_rad(-42.0),
	]
	var horse_colors := [
		Color(0.08, 0.045, 0.027, 1.0),
		Color(0.12, 0.07, 0.04, 1.0),
		Color(0.035, 0.028, 0.024, 1.0),
		Color(0.10, 0.055, 0.035, 1.0),
	]

	var horses := Node3D.new()
	horses.name = "Horses"
	prototype_root.add_child(horses)

	for i in range(horse_positions.size()):
		var horse := Node3D.new()
		horse.name = "Horse_%02d" % (i + 1)
		horse.position = horse_positions[i]
		horse.rotation.y = horse_rotations[i]
		horse.set_script(HORSE_BUILDER_SCRIPT)
		horse.set("coat_color", horse_colors[i])
		horse.add_to_group("horse")
		horses.add_child(horse)

	var horse_guard_zone := Area3D.new()
	horse_guard_zone.name = "HorseGuardZone"
	horse_guard_zone.position = horse_zone_position
	horse_guard_zone.set_script(HORSE_GUARD_ZONE_SCRIPT)
	horse_guard_zone.add_to_group("horses")
	prototype_root.add_child(horse_guard_zone)

	var horse_zone_collision := CollisionShape3D.new()
	horse_zone_collision.name = "CollisionShape3D"
	horse_zone_collision.position = Vector3(0.0, 2.0, 0.0)
	var horse_zone_shape := BoxShape3D.new()
	horse_zone_shape.size = Vector3(18.0, 4.0, 18.0)
	horse_zone_collision.shape = horse_zone_shape
	horse_guard_zone.add_child(horse_zone_collision)

	var spawn_point := Marker3D.new()
	spawn_point.name = "AlbastySpawnPoint"
	spawn_point.position = pylon_position + Vector3(7.0, 0.0, 7.0)
	spawn_point.add_to_group("albasty_spawn_points")
	prototype_root.add_child(spawn_point)

	var spawner := Node3D.new()
	spawner.name = "AlbastySpawner"
	spawner.set_script(ALBASTY_SPAWNER_SCRIPT)
	spawner.set("spawn_point_path", NodePath("../AlbastySpawnPoint"))
	spawner.set("target_path", NodePath("../HorseGuardZone"))
	spawner.set("player_path", NodePath("../../../Player"))
	spawner.set("spawn_delay", albasty_spawn_delay)
	spawner.set("respawn_delay", albasty_respawn_delay)
	spawner.set("max_alive", 1)
	spawner.set("spawn_on_ready", true)
	spawner.set("repeat_spawn", true)
	prototype_root.add_child(spawner)


func _extend_player_interaction_ray() -> void:
	var ray := get_node_or_null("../Player/Head/Camera3D/InteractionRay") as RayCast3D
	if ray == null:
		return
	ray.target_position = Vector3(0.0, 0.0, -12.0)
	ray.collide_with_areas = true


func _scatter_patch(parent: Node3D, grass_scene: PackedScene, white_scene: PackedScene, red_scene: PackedScene, yellow_scene: PackedScene, centers: Array, min_scale: float, max_scale: float, name_offset: float) -> void:
	var density: int = max(0, int(round(5.0 * flower_density_multiplier)))
	for center_index: int in range(centers.size()):
		var center: Vector3 = centers[center_index]
		for item_index: int in range(density):
			var offset: Vector3 = _patch_offset(center_index, item_index)
			var position: Vector3 = center + offset
			var scene: PackedScene = grass_scene
			var kind: int = (center_index + item_index) % 9
			if kind in [0, 2, 5, 7] and white_scene != null:
				scene = white_scene
			elif kind == 3 and red_scene != null:
				scene = red_scene
			elif kind == 8 and yellow_scene != null:
				scene = yellow_scene
			if scene == null:
				continue

			var plant := scene.instantiate() as Node3D
			plant.name = "SteppePlant_%03d_%02d" % [int(name_offset) + center_index, item_index]
			plant.position = position
			plant.rotation.y = fmod(float(center_index * 47 + item_index * 31), 360.0) * PI / 180.0
			var plant_scale: float = lerp(min_scale, max_scale, float((center_index * 11 + item_index * 7) % 10) / 9.0)
			plant.scale = Vector3.ONE * plant_scale
			parent.add_child(plant)


func _patch_offset(center_index: int, item_index: int) -> Vector3:
	var angle := float((center_index * 83 + item_index * 137) % 360) * PI / 180.0
	var radius := 0.45 + float((center_index * 19 + item_index * 23) % 100) / 100.0 * 2.3
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _add_horizontal_plane(parent: Node3D, node_name: String, position: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_backdrop_card(parent: Node3D, node_name: String, position: Vector3, size: Vector2, material: Material, rotation_y: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_silhouette_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation_y: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_silhouette_segment(parent: Node3D, node_name: String, start: Vector3, end: Vector3, thickness: float, material: Material) -> MeshInstance3D:
	var direction := end - start
	var length := direction.length()
	if length <= 0.001:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, length)
	mesh_instance.mesh = mesh
	mesh_instance.position = (start + end) * 0.5
	mesh_instance.look_at_from_position(mesh_instance.position, end, Vector3.UP)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_horizon_power_tower(parent: Node3D, node_name: String, base_position: Vector3, height: float, span: float, material: Material) -> Node3D:
	var tower := Node3D.new()
	tower.name = node_name
	tower.position = base_position
	parent.add_child(tower)

	var half_span := span * 0.5
	_add_silhouette_segment(tower, "LeftLeg", Vector3(0.0, 0.0, -half_span), Vector3(0.0, height, -half_span * 0.24), 0.14, material)
	_add_silhouette_segment(tower, "RightLeg", Vector3(0.0, 0.0, half_span), Vector3(0.0, height, half_span * 0.24), 0.14, material)
	_add_silhouette_segment(tower, "LeftDiagonal", Vector3(0.0, height * 0.18, -half_span * 0.78), Vector3(0.0, height * 0.66, half_span * 0.34), 0.1, material)
	_add_silhouette_segment(tower, "RightDiagonal", Vector3(0.0, height * 0.18, half_span * 0.78), Vector3(0.0, height * 0.66, -half_span * 0.34), 0.1, material)
	_add_silhouette_box(tower, "LowerCrossbar", Vector3(0.0, height * 0.54, 0.0), Vector3(0.16, 0.16, span), material)
	_add_silhouette_box(tower, "UpperCrossbar", Vector3(0.0, height * 0.78, 0.0), Vector3(0.16, 0.16, span * 0.78), material)
	_add_silhouette_box(tower, "TopMast", Vector3(0.0, height * 0.91, 0.0), Vector3(0.18, height * 0.18, 0.18), material)
	return tower


func _build_sagging_wire(parent: Node3D, node_name: String, start: Vector3, end: Vector3, sag: float, material: Material, segments: int) -> void:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)

	var previous := start
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := start.lerp(end, t)
		point.y -= sin(t * PI) * sag
		_wire_segment(root, "seg_%02d" % i, previous, point, material)
		previous = point


func _wire_segment(parent: Node3D, node_name: String, a: Vector3, b: Vector3, material: Material) -> void:
	var direction := b - a
	var length := direction.length()
	if length <= 0.001:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, length)
	mesh_instance.mesh = mesh
	mesh_instance.position = (a + b) * 0.5
	mesh_instance.look_at_from_position(mesh_instance.position, b, Vector3.UP)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)


func _make_unshaded_alpha_material(name: String, texture_path: String = "", color: Color = Color.WHITE, transparent: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	if texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
		var texture := ResourceLoader.load(texture_path, "Texture2D") as Texture2D
		if texture != null:
			material.albedo_texture = texture

	return material


func _make_lake_water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 water_color : source_color = vec4(0.24, 0.36, 0.38, 0.58);
uniform vec4 mineral_color : source_color = vec4(0.46, 0.55, 0.50, 0.36);

void fragment() {
	vec2 long_uv = UV * vec2(8.0, 22.0);
	float long_ripple = sin(long_uv.x * 1.35 + long_uv.y * 0.18 + TIME * 0.055) * 0.5 + 0.5;
	float mineral_mottle = sin(long_uv.x * 3.1 - long_uv.y * 0.42 + TIME * 0.025) * 0.5 + 0.5;
	float mix_amount = long_ripple * 0.055 + mineral_mottle * 0.045;
	ALBEDO = mix(water_color.rgb, mineral_color.rgb, mix_amount);
	ALPHA = water_color.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
"""

	var material := ShaderMaterial.new()
	material.resource_name = "mat_vista_lake_water_subtle_noise"
	material.shader = shader
	return material


func _make_material(name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = 0.95
	return material
