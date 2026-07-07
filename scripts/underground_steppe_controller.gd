extends Node3D

const CONCRETE_MATERIAL: Material = preload("res://materials/mat_underground_concrete.tres")
const WET_GRASS_MATERIAL: Material = preload("res://materials/mat_underground_wet_grass.tres")
const WATER_MATERIAL: Material = preload("res://materials/mat_underground_water.tres")
const FLOWER_WHITE_MATERIAL: Material = preload("res://materials/mat_underground_flower_white.tres")

const GRASS_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_grass_patch.glb"
const FLOWER_WHITE_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_flower_white.glb"

@export var hall_width: float = 24.0
@export var hall_depth: float = 18.0
@export var ceiling_height: float = 3.1
@export_range(0.0, 3.0, 0.1) var flower_density_multiplier: float = 1.0
@export_file("*.tscn") var return_scene_path: String = "res://scenes/Main.tscn"

var _generated_root: Node3D


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_level()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().change_scene_to_file(return_scene_path)


func _build_level() -> void:
	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedUndergroundSteppe"
	add_child(_generated_root)

	_build_concrete_shell()
	_build_water()
	_build_vegetation()
	_build_far_opening_marker()


func _build_concrete_shell() -> void:
	_add_static_box("WetGreenFloor", Vector3(hall_width, 0.16, hall_depth), Vector3(0.0, -0.08, 0.0), WET_GRASS_MATERIAL)
	_add_static_box("ConcreteCeiling", Vector3(hall_width + 0.6, 0.32, hall_depth + 0.6), Vector3(0.0, ceiling_height, 0.0), CONCRETE_MATERIAL)
	_add_static_box("NorthConcreteWall", Vector3(hall_width + 0.6, ceiling_height, 0.32), Vector3(0.0, ceiling_height * 0.5, -hall_depth * 0.5), CONCRETE_MATERIAL)
	_add_static_box("SouthConcreteWall", Vector3(hall_width + 0.6, ceiling_height, 0.32), Vector3(0.0, ceiling_height * 0.5, hall_depth * 0.5), CONCRETE_MATERIAL)
	_add_static_box("WestConcreteWall", Vector3(0.32, ceiling_height, hall_depth + 0.6), Vector3(-hall_width * 0.5, ceiling_height * 0.5, 0.0), CONCRETE_MATERIAL)
	_add_static_box("EastConcreteWall", Vector3(0.32, ceiling_height, hall_depth + 0.6), Vector3(hall_width * 0.5, ceiling_height * 0.5, 0.0), CONCRETE_MATERIAL)
	_add_static_box("EntryConcretePlatform", Vector3(5.2, 0.12, 3.2), Vector3(0.0, 0.02, hall_depth * 0.5 - 2.0), CONCRETE_MATERIAL)


func _build_water() -> void:
	_add_puddle("PuddleWest", Vector3(-5.0, 0.015, 0.8), Vector3(2.4, 1.0, 1.2))
	_add_puddle("PuddleNorth", Vector3(4.2, 0.015, -4.3), Vector3(1.7, 1.0, 0.85))


func _build_vegetation() -> void:
	var grass_scene := load(GRASS_SCENE_PATH) as PackedScene
	var flower_scene := load(FLOWER_WHITE_SCENE_PATH) as PackedScene
	var centers := [
		Vector3(-7.0, 0.0, -4.5),
		Vector3(-3.0, 0.0, -2.0),
		Vector3(2.4, 0.0, -5.4),
		Vector3(6.5, 0.0, -1.5),
		Vector3(-6.2, 0.0, 3.2),
		Vector3(1.0, 0.0, 2.4),
		Vector3(5.8, 0.0, 4.4)
	]
	var density: int = max(1, int(round(5.0 * flower_density_multiplier)))
	for center_index: int in range(centers.size()):
		for item_index: int in range(density):
			var position: Vector3 = centers[center_index] + _patch_offset(center_index, item_index)
			var use_flower := item_index % 3 == 0
			var scene := flower_scene if use_flower else grass_scene
			if scene != null:
				var plant := scene.instantiate() as Node3D
				plant.name = "UndergroundPlant_%02d_%02d" % [center_index, item_index]
				plant.position = position
				plant.rotation.y = deg_to_rad(float((center_index * 53 + item_index * 29) % 360))
				plant.scale = Vector3.ONE * (0.65 + float((center_index + item_index) % 5) * 0.12)
				_generated_root.add_child(plant)
			else:
				_add_placeholder_flower("PlaceholderFlower_%02d_%02d" % [center_index, item_index], position)


func _build_far_opening_marker() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.015, 0.025, 0.02, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.0, 0.04, 0.025, 1.0)
	material.emission_energy_multiplier = 0.35
	_add_mesh_box("DarkFarOpening", Vector3(4.2, 2.1, 0.06), Vector3(0.0, 1.05, -hall_depth * 0.5 - 0.19), material)


func _add_static_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	_generated_root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_mesh_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	_generated_root.add_child(mesh_instance)
	return mesh_instance


func _add_puddle(node_name: String, position: Vector3, scale_value: Vector3) -> void:
	var puddle := MeshInstance3D.new()
	puddle.name = node_name
	puddle.position = position
	puddle.scale = scale_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.025
	mesh.radial_segments = 48
	puddle.mesh = mesh
	puddle.set_surface_override_material(0, WATER_MATERIAL)
	_generated_root.add_child(puddle)


func _add_placeholder_flower(node_name: String, position: Vector3) -> void:
	var stem := _add_mesh_box(node_name + "_Stem", Vector3(0.035, 0.35, 0.035), position + Vector3(0.0, 0.18, 0.0), WET_GRASS_MATERIAL)
	stem.rotation.y = deg_to_rad(20.0)
	_add_mesh_box(node_name + "_Bloom", Vector3(0.18, 0.04, 0.18), position + Vector3(0.0, 0.38, 0.0), FLOWER_WHITE_MATERIAL)


func _patch_offset(center_index: int, item_index: int) -> Vector3:
	var angle := deg_to_rad(float((center_index * 71 + item_index * 137) % 360))
	var radius := 0.3 + float((center_index * 17 + item_index * 23) % 100) / 100.0 * 1.8
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
