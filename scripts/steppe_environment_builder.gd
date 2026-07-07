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

@export var ground_size: float = 200.0
@export var sky_radius: float = 520.0
@export var pylon_position := Vector3(0.0, 0.0, -92.0)
@export_range(0.0, 3.0, 0.1) var flower_density_multiplier: float = 1.0
@export var enable_albasty_prototype: bool = true
@export var albasty_spawn_delay: float = 5.0
@export var albasty_respawn_delay: float = 35.0


func _ready() -> void:
	_clear_existing_geometry()
	_build_ground()
	_build_sky_dome()
	_build_power_pylon()
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


func _build_power_pylon() -> void:
	var pylon_root := Node3D.new()
	pylon_root.name = "PowerPylon"
	pylon_root.position = pylon_position
	add_child(pylon_root)

	var pylon_scene := load(PYLON_SCENE_PATH) as PackedScene
	if pylon_scene != null:
		var pylon_model := pylon_scene.instantiate()
		pylon_model.name = "PowerPylonModel"
		pylon_root.add_child(pylon_model)

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
