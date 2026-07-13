class_name LostSignalLoopingRoad
extends Node3D

signal distance_advanced(total_distance: float)

@export var forest_mode := false
@export_range(0.0, 40.0, 0.1) var driving_speed := 21.0
@export_range(0.0, 40.0, 0.1) var target_speed := 21.0
@export_range(0.1, 20.0, 0.1) var acceleration := 3.0

const SEGMENT_LENGTH := 60.0
const SEGMENT_COUNT := 6

var segments: Array[Node3D] = []
var total_distance := 0.0


func _ready() -> void:
	_build_segments()


func _physics_process(delta: float) -> void:
	driving_speed = move_toward(driving_speed, target_speed, acceleration * delta)
	if driving_speed <= 0.001:
		return
	var travel := driving_speed * delta
	total_distance += travel
	for segment in segments:
		segment.position.z += travel
		if segment.position.z > 31.0:
			segment.position.z -= SEGMENT_LENGTH * SEGMENT_COUNT
	distance_advanced.emit(total_distance)


func set_speed(next_speed: float, rate := 3.0) -> void:
	target_speed = maxf(0.0, next_speed)
	acceleration = maxf(0.05, rate)


func _build_segments() -> void:
	var asphalt := load("res://assets/lost_signal/materials/road012c/Road012C_2K-JPG.tres") as StandardMaterial3D
	if asphalt:
		asphalt = asphalt.duplicate() as StandardMaterial3D
		asphalt.uv1_scale = Vector3(1.9, 1.9, 1.9)
		asphalt.albedo_color = Color(0.55, 0.59, 0.64)
		asphalt.heightmap_enabled = false
	else:
		asphalt = LostSignalVisualFactory.material(Color(0.028, 0.032, 0.037), 0.86)
	var shoulder := LostSignalVisualFactory.material(Color(0.055, 0.052, 0.045), 0.98)
	var paint := LostSignalVisualFactory.material(
		Color(0.56, 0.57, 0.52), 0.66, 0.0,
		Color(0.22, 0.23, 0.2), 0.34
	)
	var grass := LostSignalVisualFactory.material(
		Color(0.035, 0.048, 0.035) if forest_mode else Color(0.075, 0.069, 0.05), 0.96
	)
	for index in SEGMENT_COUNT:
		var segment := Node3D.new()
		segment.name = ("Forest" if forest_mode else "Road") + "Segment%02d" % index
		segment.position.z = -30.0 - index * SEGMENT_LENGTH
		add_child(segment)
		segments.append(segment)
		LostSignalVisualFactory.box(segment, "Asphalt", Vector3(7.4, 0.16, SEGMENT_LENGTH), Vector3(0, -0.12, 0), asphalt, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "ShoulderL", Vector3(3.5, 0.12, SEGMENT_LENGTH), Vector3(-5.45, -0.16, 0), shoulder, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "ShoulderR", Vector3(3.5, 0.12, SEGMENT_LENGTH), Vector3(5.45, -0.16, 0), shoulder, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "GroundL", Vector3(20, 0.08, SEGMENT_LENGTH), Vector3(-16.5, -0.21, 0), grass, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "GroundR", Vector3(20, 0.08, SEGMENT_LENGTH), Vector3(16.5, -0.21, 0), grass, Vector3.ZERO, false)
		for mark_index in 6:
			var z := -SEGMENT_LENGTH * 0.5 + 5.0 + mark_index * 10.0
			LostSignalVisualFactory.box(segment, "CenterMark%02d" % mark_index, Vector3(0.12, 0.018, 4.1), Vector3(0, -0.025, z), paint, Vector3.ZERO, false)
		for side in [-1.0, 1.0]:
			LostSignalVisualFactory.box(segment, "EdgeLine%s" % side, Vector3(0.11, 0.02, SEGMENT_LENGTH), Vector3(3.25 * side, -0.022, 0), paint, Vector3.ZERO, false)
		if forest_mode:
			_build_forest_multimeshes(segment, index)
		else:
			_build_steppe_props(segment, index)


func _build_steppe_props(segment: Node3D, seed: int) -> void:
	var post_mat := LostSignalVisualFactory.material(Color(0.16, 0.17, 0.16), 0.72, 0.45)
	var reflector := LostSignalVisualFactory.material(Color(0.7, 0.65, 0.46), 0.4, 0.0, Color(0.8, 0.68, 0.42), 1.2)
	for marker in 5:
		var z := -24.0 + marker * 12.0 + float(seed % 2)
		for side in [-1.0, 1.0]:
			LostSignalVisualFactory.box(segment, "RoadPost", Vector3(0.08, 0.62, 0.08), Vector3(4.1 * side, 0.22, z), post_mat, Vector3.ZERO, false)
			LostSignalVisualFactory.box(segment, "Reflector", Vector3(0.09, 0.09, 0.025), Vector3(4.06 * side, 0.42, z - 0.04), reflector, Vector3.ZERO, false)


func _build_forest_multimeshes(segment: Node3D, seed: int) -> void:
	var trunk_mat := LostSignalVisualFactory.material(Color(0.055, 0.043, 0.034), 0.96)
	var crown_mat := LostSignalVisualFactory.material(Color(0.018, 0.038, 0.027), 0.94)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 4.8
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = trunk_mat
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.05
	crown_mesh.bottom_radius = 1.25
	crown_mesh.height = 4.8
	crown_mesh.radial_segments = 7
	crown_mesh.material = crown_mat
	var random := RandomNumberGenerator.new()
	random.seed = 8201 + seed * 337
	for spec in [{"mesh": trunk_mesh, "name": "TreeTrunks"}, {"mesh": crown_mesh, "name": "TreeCrowns"}]:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = spec.mesh
		multimesh.instance_count = 30
		for item in 30:
			var side := -1.0 if item % 2 == 0 else 1.0
			var x := side * random.randf_range(6.2, 18.0)
			var z := random.randf_range(-28.5, 28.5)
			var scale := random.randf_range(0.72, 1.32)
			var y := 2.2 * scale if spec.name == "TreeTrunks" else 5.3 * scale
			var basis := Basis.from_euler(Vector3(0, random.randf_range(-PI, PI), 0)).scaled(Vector3.ONE * scale)
			multimesh.set_instance_transform(item, Transform3D(basis, Vector3(x, y, z)))
		var instance := MultiMeshInstance3D.new()
		instance.name = spec.name
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 155.0
		segment.add_child(instance)
	_build_kenney_tree_multimeshes(segment, seed)
	var near_tree_mat := LostSignalVisualFactory.material(Color(0.026, 0.055, 0.035), 0.94)
	for item in 6:
		var side := -1.0 if item % 2 == 0 else 1.0
		var x := side * random.randf_range(5.2, 8.0)
		var z := random.randf_range(-26.0, 26.0)
		LostSignalVisualFactory.cylinder(segment, "NearTrunk%02d" % item, 0.22, 5.5, Vector3(x, 2.65, z), trunk_mat, Vector3.ZERO, 7)
		var crown := LostSignalVisualFactory.cylinder(segment, "NearCrown%02d" % item, 1.05, 4.4, Vector3(x, 6.25, z), near_tree_mat, Vector3.ZERO, 7)
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_kenney_tree_multimeshes(segment: Node3D, seed: int) -> void:
	var paths := [
		"res://assets/lost_signal/forest/kenney_nature/tree_pineTallA_detailed.glb",
		"res://assets/lost_signal/forest/kenney_nature/tree_pineRoundC.glb",
	]
	var night_materials := [
		LostSignalVisualFactory.material(Color(0.032, 0.070, 0.046), 0.96),
		LostSignalVisualFactory.material(Color(0.042, 0.084, 0.054), 0.94),
	]
	var random := RandomNumberGenerator.new()
	random.seed = 42017 + seed * 617
	for variant in paths.size():
		var tree_mesh := _load_first_mesh(paths[variant])
		if tree_mesh == null:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = tree_mesh
		multimesh.instance_count = 14
		for item in 14:
			var side := -1.0 if item % 2 == 0 else 1.0
			var scale := random.randf_range(1.25, 2.35)
			var x := side * random.randf_range(6.5, 17.0)
			var z := random.randf_range(-28.0, 28.0)
			var basis := Basis.from_euler(Vector3(0, random.randf_range(-PI, PI), 0)).scaled(Vector3.ONE * scale)
			multimesh.set_instance_transform(item, Transform3D(basis, Vector3(x, 0.0, z)))
		var instance := MultiMeshInstance3D.new()
		instance.name = "KenneyTreeVariant%02d" % variant
		instance.multimesh = multimesh
		instance.material_override = night_materials[variant]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 145.0
		segment.add_child(instance)


func _load_first_mesh(path: String) -> Mesh:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var result: Mesh = null
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		if mesh_node.mesh:
			result = mesh_node.mesh
			break
	root.free()
	return result
