class_name LostSignalLoopingRoad
extends Node3D

signal distance_advanced(total_distance: float)

@export var forest_mode := false
@export_range(0.0, 40.0, 0.1) var driving_speed := 21.0
@export_range(0.0, 40.0, 0.1) var target_speed := 21.0
@export_range(0.1, 20.0, 0.1) var acceleration := 3.0

const SEGMENT_LENGTH := 120.0
const SEGMENT_COUNT := 5
const ROAD_WIDTH := 8.6

var segments: Array[Node3D] = []
var total_distance := 0.0
var _steppe_grass_mesh: Mesh
var _steppe_bush_mesh: Mesh
var _steppe_rock_mesh: Mesh


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
		if segment.position.z > SEGMENT_LENGTH * 0.5 + 1.0:
			segment.position.z -= SEGMENT_LENGTH * SEGMENT_COUNT
	distance_advanced.emit(total_distance)


func set_speed(next_speed: float, rate := 3.0) -> void:
	target_speed = maxf(0.0, next_speed)
	acceleration = maxf(0.05, rate)


func _build_segments() -> void:
	var shoulder := _make_steppe_material(Vector3(0.38, 3.8, 0.38))
	var road_base := LostSignalVisualFactory.material(Color(0.018, 0.021, 0.025), 0.94)
	var grass := LostSignalVisualFactory.material(
		Color(0.035, 0.048, 0.035) if forest_mode else Color(0.075, 0.069, 0.05), 0.96
	)
	for index in SEGMENT_COUNT:
		var asphalt := _make_asphalt_material(index)
		var segment := Node3D.new()
		segment.name = ("Forest" if forest_mode else "Road") + "Segment%02d" % index
		segment.position.z = -SEGMENT_LENGTH * 0.5 - index * SEGMENT_LENGTH
		add_child(segment)
		segments.append(segment)
		LostSignalVisualFactory.box(segment, "RoadFoundation", Vector3(ROAD_WIDTH, 0.16, SEGMENT_LENGTH), Vector3(0, -0.12, 0), road_base, Vector3.ZERO, false)
		_build_asphalt_surface(segment, asphalt)
		LostSignalVisualFactory.box(segment, "ShoulderL", Vector3(4.0, 0.12, SEGMENT_LENGTH), Vector3(-6.3, -0.16, 0), shoulder, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "ShoulderR", Vector3(4.0, 0.12, SEGMENT_LENGTH), Vector3(6.3, -0.16, 0), shoulder, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "GroundL", Vector3(64, 0.08, SEGMENT_LENGTH), Vector3(-40.3, -0.21, 0), grass if forest_mode else shoulder, Vector3.ZERO, false)
		LostSignalVisualFactory.box(segment, "GroundR", Vector3(64, 0.08, SEGMENT_LENGTH), Vector3(40.3, -0.21, 0), grass if forest_mode else shoulder, Vector3.ZERO, false)
		if forest_mode:
			_build_forest_multimeshes(segment, index)
		else:
			_build_steppe_details(segment, index)


func _build_asphalt_surface(segment: Node3D, asphalt: ShaderMaterial) -> void:
	# A dedicated upward-facing plane gives the Poly Haven maps stable,
	# predictable UVs. The dark box below it only supplies road thickness.
	var surface := MeshInstance3D.new()
	surface.name = "PolyHavenAsphaltSurface"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ROAD_WIDTH, SEGMENT_LENGTH)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 60
	mesh.material = asphalt
	surface.mesh = mesh
	surface.position.y = -0.025
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	segment.add_child(surface)


func _make_asphalt_material(index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/lost_signal_road_blend.gdshader") as Shader
	var asphalt_root := "res://assets/lost_signal/materials/polyhaven/asphalt_02/"
	var repair_root := "res://LostSignal_RoadScene_CodexPack/materials/road/"
	material.set_shader_parameter("asphalt_albedo", load(asphalt_root + "asphalt_02_diff_4k.jpg"))
	material.set_shader_parameter("asphalt_normal", load(asphalt_root + "asphalt_02_nor_gl_4k.jpg"))
	material.set_shader_parameter("asphalt_roughness", load(asphalt_root + "asphalt_02_rough_4k.jpg"))
	material.set_shader_parameter("asphalt_displacement", load(asphalt_root + "asphalt_02_disp_4k.jpg"))
	material.set_shader_parameter("asphalt_ao", load(asphalt_root + "asphalt_02_ao_4k.jpg"))
	material.set_shader_parameter("damage_normal", load(repair_root + "road_damaged/road_damaged_nor_gl_2k.jpg"))
	material.set_shader_parameter("damage_mask", load(repair_root + "road_damage_blend_mask_2k.png"))
	material.set_shader_parameter("repair_offset", Vector2(float(index) * 0.173, float(index) * 0.317))
	material.set_shader_parameter("wave_phase", float(index) * 1.137)
	return material


func _make_steppe_material(uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var root := "res://LostSignal_RoadScene_CodexPack/materials/steppe/dirt_aerial_03/"
	material.albedo_texture = load(root + "dirt_aerial_03_diff_4k.jpg") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(root + "dirt_aerial_03_nor_gl_4k.jpg") as Texture2D
	material.roughness_texture = load(root + "dirt_aerial_03_rough_4k.jpg") as Texture2D
	material.roughness = 0.94
	material.uv1_scale = uv_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _build_steppe_details(segment: Node3D, seed: int) -> void:
	if _steppe_grass_mesh == null:
		_steppe_grass_mesh = _load_first_mesh("res://assets/polyhaven/processed/grass_medium_02_lod1.gltf")
	if _steppe_bush_mesh == null:
		_steppe_bush_mesh = _load_first_mesh("res://assets/polyhaven/processed/wild_rooibos_bush_lod1.gltf")
	if _steppe_rock_mesh == null:
		_steppe_rock_mesh = _load_first_mesh("res://assets/polyhaven/processed/coast_land_rocks_03_lod1.gltf")
	var random := RandomNumberGenerator.new()
	random.seed = 91037 + seed * 811
	if _steppe_grass_mesh:
		_add_steppe_multimesh(segment, "DryGrassTufts", _steppe_grass_mesh, 42, random, 5.3, 17.0, 0.90, 2.00, false)
	if _steppe_bush_mesh:
		_add_steppe_multimesh(segment, "LowSteppeScrub", _steppe_bush_mesh, 14, random, 6.0, 23.0, 0.42, 0.92, true)
	if _steppe_rock_mesh:
		_add_steppe_multimesh(segment, "ScatteredFieldStone", _steppe_rock_mesh, 7, random, 5.8, 19.0, 0.10, 0.28, true)


func _add_steppe_multimesh(
	segment: Node3D,
	node_name: String,
	mesh: Mesh,
	count: int,
	random: RandomNumberGenerator,
	min_distance_from_centre: float,
	max_distance_from_centre: float,
	min_scale: float,
	max_scale: float,
	cast_shadows: bool
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for item in count:
		var side := -1.0 if item % 2 == 0 else 1.0
		var x := side * random.randf_range(min_distance_from_centre, max_distance_from_centre)
		var z := random.randf_range(-SEGMENT_LENGTH * 0.49, SEGMENT_LENGTH * 0.49)
		var scale := random.randf_range(min_scale, max_scale)
		var non_uniform_scale := Vector3(scale * random.randf_range(0.78, 1.25), scale, scale * random.randf_range(0.78, 1.25))
		var basis := Basis.from_euler(Vector3(0.0, random.randf_range(-PI, PI), random.randf_range(-0.04, 0.04))).scaled(non_uniform_scale)
		multimesh.set_instance_transform(item, Transform3D(basis, Vector3(x, -0.16, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 110.0 if cast_shadows else 82.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	segment.add_child(instance)


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
