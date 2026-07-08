extends Node3D

const STEPPE_GROUND_MATERIAL: Material = preload("res://materials/mat_steppe_ground.tres")
const SKY_DOME_MATERIAL: Material = preload("res://materials/mat_sky_dome.tres")

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


func _ready() -> void:
	_clear_existing_geometry()
	_build_ground()
	_build_sky_dome()
	_build_yurt_entrance_marker()
	_build_distant_balkhash_view()
	_build_power_pylon()
	_build_secondary_powerline()
	_build_rear_powerline()
	_build_steppe_vegetation()
	_build_albasty_prototype()
	_extend_player_interaction_ray()


func _clear_existing_geometry() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


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


func _build_distant_balkhash_view() -> void:
	var root := Node3D.new()
	root.name = "DistantBalkhashRoot"
	add_child(root)

	var salt_mat := _make_unshaded_alpha_material("mat_main_balkhash_salt_flat", TEX_SALT_FLAT, Color(0.86, 0.80, 0.62, 0.92), true)
	var shore_mat := _make_unshaded_alpha_material("mat_main_balkhash_shore_strip", TEX_SHORE_STRIP, Color(0.24, 0.20, 0.17, 0.94), true)
	var water_mat := _make_unshaded_alpha_material("mat_main_balkhash_far_water", "", Color(0.31, 0.45, 0.47, 0.68), true)
	var backdrop_main_mat := _make_unshaded_alpha_material("mat_main_balkhash_backdrop_main", TEX_BACKDROP_MAIN, Color(0.62, 0.67, 0.66, 0.82), true)
	var backdrop_alt_mat := _make_unshaded_alpha_material("mat_main_balkhash_backdrop_alt", TEX_BACKDROP_ALT, Color(0.46, 0.55, 0.55, 0.34), true)
	var fog_mat := _make_unshaded_alpha_material("mat_main_balkhash_horizon_fog", TEX_HORIZON_FOG, Color(0.54, 0.56, 0.53, 0.48), true)
	var industrial_mat := _make_unshaded_alpha_material("mat_main_balkhash_industrial_smudge", TEX_INDUSTRIAL, Color(0.16, 0.17, 0.16, 0.28), true)

	_add_horizontal_plane(root, "SaltFlatExtensionPlane", Vector3(82.0, 0.016, -42.0), Vector2(72.0, 168.0), salt_mat)
	_add_horizontal_plane(root, "ShoreMudStrip", Vector3(116.0, 0.022, -44.0), Vector2(11.0, 172.0), shore_mat)
	_add_horizontal_plane(root, "LakeWaterPlane", Vector3(142.0, 0.018, -46.0), Vector2(52.0, 184.0), water_mat)

	_add_backdrop_card(root, "FarBackdropCard", Vector3(171.0, 10.2, -48.0), Vector2(188.0, 28.0), backdrop_main_mat, deg_to_rad(90.0))
	_add_backdrop_card(root, "FarBackdropAltLowShore", Vector3(165.0, 7.0, -24.0), Vector2(136.0, 18.0), backdrop_alt_mat, deg_to_rad(90.0))
	_add_backdrop_card(root, "HorizonFogCard", Vector3(160.0, 9.4, -48.0), Vector2(202.0, 22.0), fog_mat, deg_to_rad(90.0))
	_add_backdrop_card(root, "FarIndustrialOverlay", Vector3(162.0, 9.0, -80.0), Vector2(46.0, 8.0), industrial_mat, deg_to_rad(90.0))


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


func _make_material(name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = 0.95
	return material
