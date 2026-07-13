class_name EnvironmentPropBuilder
extends Node3D

const CONCRETE_SHADER := preload("res://addons/archive_barrage/shaders/aged_concrete.gdshader")
const PLASTER_ALBEDO := preload(
	"res://addons/archive_barrage/assets/polyhaven/plastered_stone_wall_4k/plastered_stone_wall_diff_4k.jpg"
)
const PLASTER_NORMAL := preload(
	"res://addons/archive_barrage/assets/runtime/plastered_stone_wall/plastered_stone_wall_normal_gl_2k.webp"
)
const PLASTER_ROUGHNESS := preload(
	"res://addons/archive_barrage/assets/polyhaven/plastered_stone_wall_4k/plastered_stone_wall_rough_4k.jpg"
)
const CONCRETE_DETAIL_ALBEDO := preload(
	"res://addons/archive_barrage/assets/generated/concrete/aged_concrete_albedo_2k.png"
)
const CONCRETE_DETAIL_NORMAL := preload(
	"res://addons/archive_barrage/assets/runtime/concrete/aged_concrete_normal_gl_2k.webp"
)
const WIRE_ALBEDO := preload(
	"res://addons/archive_barrage/assets/generated/metal/old_wire_albedo_1k.png"
)
const WIRE_METALLIC := preload(
	"res://addons/archive_barrage/assets/generated/metal/old_wire_metallic_1k.png"
)
const WIRE_ROUGHNESS := preload(
	"res://addons/archive_barrage/assets/generated/metal/old_wire_roughness_1k.png"
)
const MUD_SHADER := preload("res://addons/archive_barrage/shaders/mud_decal.gdshader")
const PUDDLE_SHADER := preload("res://addons/archive_barrage/shaders/puddle.gdshader")
const BACKGROUND_SHADER := preload("res://addons/archive_barrage/shaders/background_layer.gdshader")
const MUD_MASKS := [
	preload("res://addons/archive_barrage/assets/generated/decals/mud_patch_01_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/mud_patch_02_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/mud_patch_03_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/mud_patch_04_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/mud_patch_05_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/mud_patch_06_1k.png"),
]
const PUDDLE_MASKS := [
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_01_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_02_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_03_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_04_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_05_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_06_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_07_1k.png"),
	preload("res://addons/archive_barrage/assets/generated/decals/puddle_mask_08_1k.png"),
]
const FAR_BERMS := preload(
	"res://addons/archive_barrage/assets/generated/backgrounds/far_berms_8k.png"
)
const FAR_FENCE := preload(
	"res://addons/archive_barrage/assets/generated/backgrounds/far_fence_8k.png"
)
const FAR_FOG_BAND := preload(
	"res://addons/archive_barrage/assets/generated/backgrounds/far_fog_band_8k.png"
)

var terrain: BarrageTerrain
var _rng := RandomNumberGenerator.new()
var _concrete_material: ShaderMaterial
var _wire_material: StandardMaterial3D
var _performance_mode := false
var _background_materials: Array[ShaderMaterial] = []


func build(target_terrain: BarrageTerrain, use_performance_profile: bool = false) -> void:
	terrain = target_terrain
	_performance_mode = use_performance_profile
	_rng.seed = 667
	_concrete_material = _create_concrete_material()
	_wire_material = _create_wire_material()
	_build_fence_lines()
	_build_broken_poles()
	_build_ruined_concrete()
	_build_berms()
	_build_mud_patches()
	_build_puddles()
	# The real terrain and shader sky now reach the horizon.  The former giant
	# transparent cards intersected the play surface and exposed rectangular
	# silhouettes when viewed from an ultrawide angle.


func set_flash_response(level: float) -> void:
	var clamped_level := clampf(level, 0.0, 1.0)
	for material in _background_materials:
		material.set_shader_parameter("flash_level", clamped_level)


func _create_concrete_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CONCRETE_SHADER
	material.set_shader_parameter("plaster_albedo", PLASTER_ALBEDO)
	material.set_shader_parameter("plaster_normal", PLASTER_NORMAL)
	material.set_shader_parameter("plaster_roughness", PLASTER_ROUGHNESS)
	material.set_shader_parameter("detail_albedo", CONCRETE_DETAIL_ALBEDO)
	material.set_shader_parameter("detail_normal", CONCRETE_DETAIL_NORMAL)
	return material


func _create_wire_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.115, 0.105)
	material.albedo_texture = WIRE_ALBEDO
	material.metallic = 0.72
	material.metallic_texture = WIRE_METALLIC
	material.roughness = 0.74
	material.roughness_texture = WIRE_ROUGHNESS
	return material


func _build_fence_lines() -> void:
	var rows: Array[float] = [-82.0, -172.0, -278.0]
	var row_count := 2 if _performance_mode else rows.size()
	for row_index in range(row_count):
		var points: Array[Vector3] = []
		for x in range(-260, 281, 20):
			if _rng.randf() < 0.10:
				continue
			var z: float = rows[row_index] + sin(float(x) * 0.035 + float(row_index)) * 8.0
			var height := _rng.randf_range(2.4, 3.8)
			var position := Vector3(float(x), terrain.height_at_world(float(x), z), z)
			var top := _make_concrete_post(position, height, _rng.randf_range(-7.0, 7.0))
			points.append(top)

		for index in range(points.size() - 1):
			for wire_level in range(3):
				var level := 0.62 + wire_level * 0.62
				var a := points[index] - Vector3.UP * (2.7 - level)
				var b := points[index + 1] - Vector3.UP * (2.7 - level)
				_make_wire(a, b)


func _make_concrete_post(position: Vector3, height: float, lean_degrees: float) -> Vector3:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = _rng.randf_range(0.13, 0.17)
	cylinder.bottom_radius = _rng.randf_range(0.18, 0.24)
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 3
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = _concrete_material
	mesh_instance.position = position + Vector3.UP * (height * 0.5 - 0.12)
	mesh_instance.rotation_degrees = Vector3(
		lean_degrees, _rng.randf_range(0.0, 360.0), _rng.randf_range(-3.0, 3.0)
	)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	return mesh_instance.position + mesh_instance.global_basis.y * height * 0.5


func _make_wire(a: Vector3, b: Vector3) -> void:
	var direction := b - a
	var length := direction.length()
	if length < 0.01:
		return
	var wire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.012
	cylinder.bottom_radius = 0.012
	cylinder.height = length
	cylinder.radial_segments = 6
	wire.mesh = cylinder
	wire.material_override = _wire_material
	wire.position = (a + b) * 0.5
	wire.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(wire)


func _build_broken_poles() -> void:
	var pole_count := 12 if _performance_mode else 18
	for index in range(pole_count):
		var x := _rng.randf_range(-250.0, 250.0)
		var z := _rng.randf_range(-330.0, -35.0)
		var height := _rng.randf_range(0.8, 2.2)
		_make_concrete_post(
			Vector3(x, terrain.height_at_world(x, z) - 0.2, z),
			height,
			_rng.randf_range(-24.0, 24.0)
		)


func _build_ruined_concrete() -> void:
	var ruin_count := 6 if _performance_mode else 10
	for index in range(ruin_count):
		var x := _rng.randf_range(-245.0, 245.0)
		var z := _rng.randf_range(-365.0, -70.0)
		var base_y := terrain.height_at_world(x, z)
		var ruin := MeshInstance3D.new()
		if index % 3 == 0:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = _rng.randf_range(0.8, 1.5)
			cylinder.bottom_radius = cylinder.top_radius * _rng.randf_range(1.0, 1.2)
			cylinder.height = _rng.randf_range(0.7, 1.8)
			cylinder.radial_segments = 12
			ruin.mesh = cylinder
		else:
			var block := BoxMesh.new()
			block.size = Vector3(
				_rng.randf_range(1.4, 4.6),
				_rng.randf_range(0.5, 1.4),
				_rng.randf_range(0.9, 2.8)
			)
			ruin.mesh = block
		ruin.material_override = _concrete_material
		ruin.position = Vector3(x, base_y + 0.15, z)
		ruin.rotation_degrees = Vector3(
			_rng.randf_range(-13.0, 13.0),
			_rng.randf_range(0.0, 360.0),
			_rng.randf_range(-10.0, 10.0)
		)
		ruin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(ruin)


func _build_berms() -> void:
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.030, 0.032, 0.036)
	dark_material.roughness = 0.96
	var berm_count := 8 if _performance_mode else 12
	for index in range(berm_count):
		var x := _rng.randf_range(-270.0, 270.0)
		var z := _rng.randf_range(-430.0, -120.0)
		var berm := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 20
		sphere.rings = 10
		berm.mesh = sphere
		berm.material_override = dark_material
		berm.scale = Vector3(
			_rng.randf_range(12.0, 32.0), _rng.randf_range(1.8, 4.8), _rng.randf_range(5.0, 13.0)
		)
		berm.position = Vector3(x, terrain.height_at_world(x, z) - berm.scale.y * 0.72, z)
		berm.rotation.y = _rng.randf_range(-0.6, 0.6)
		berm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(berm)


func _build_mud_patches() -> void:
	var patch_count := 4 if _performance_mode else 6
	for index in range(patch_count):
		var x := _rng.randf_range(-185.0, 185.0)
		var z := _rng.randf_range(-205.0, 58.0)
		var patch := MeshInstance3D.new()
		var patch_size := Vector2(_rng.randf_range(7.0, 22.0), _rng.randf_range(4.0, 13.0))
		patch.mesh = _make_conforming_patch_mesh(x, z, patch_size, 0.032)
		var material := ShaderMaterial.new()
		material.shader = MUD_SHADER
		material.set_shader_parameter("mud_mask", MUD_MASKS[index % MUD_MASKS.size()])
		patch.material_override = material
		# The mesh samples the terrain at every grid point.  A single tilted plane
		# intersected the rolling steppe and looked like a rectangular floor hole.
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)


func _build_puddles() -> void:
	var puddle_count := 8 if _performance_mode else 12
	for index in range(puddle_count):
		var x := _rng.randf_range(-145.0, 145.0)
		var z := _rng.randf_range(-150.0, 50.0)
		var puddle := MeshInstance3D.new()
		var puddle_size := Vector2(_rng.randf_range(4.0, 15.0), _rng.randf_range(2.0, 8.0))
		puddle.mesh = _make_conforming_patch_mesh(x, z, puddle_size, 0.040)
		var material := ShaderMaterial.new()
		material.shader = PUDDLE_SHADER
		material.set_shader_parameter(
			"puddle_mask", PUDDLE_MASKS[index % PUDDLE_MASKS.size()]
		)
		puddle.material_override = material
		puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puddle)


func _make_conforming_patch_mesh(
	center_x: float,
	center_z: float,
	size: Vector2,
	y_offset: float
) -> ArrayMesh:
	var columns := 9 if _performance_mode else 13
	var rows := 7 if _performance_mode else 11
	var angle := _rng.randf_range(0.0, TAU)
	var rotation_2d := Transform2D(angle, Vector2.ZERO)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var sample_distance := 0.65

	for row in range(rows):
		for column in range(columns):
			var uv := Vector2(
				float(column) / float(columns - 1),
				float(row) / float(rows - 1)
			)
			var unrotated := (uv - Vector2(0.5, 0.5)) * size
			var offset := rotation_2d * unrotated
			var world_x := center_x + offset.x
			var world_z := center_z + offset.y
			var height := terrain.height_at_world(world_x, world_z)
			var height_left := terrain.height_at_world(world_x - sample_distance, world_z)
			var height_right := terrain.height_at_world(world_x + sample_distance, world_z)
			var height_back := terrain.height_at_world(world_x, world_z - sample_distance)
			var height_front := terrain.height_at_world(world_x, world_z + sample_distance)
			var normal := Vector3(
				height_left - height_right,
				sample_distance * 2.0,
				height_back - height_front
			).normalized()
			vertices.append(Vector3(world_x, height + y_offset, world_z))
			normals.append(normal)
			uvs.append(uv)

	for row in range(rows - 1):
		for column in range(columns - 1):
			var a := row * columns + column
			var b := a + 1
			var c := a + columns
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _build_background_layers() -> void:
	_make_background_layer(
		FAR_BERMS, Vector3(0.0, 54.0, -1050.0), Vector2(2600.0, 110.0), 0.72
	)
	_make_background_layer(
		FAR_FENCE, Vector3(0.0, 52.0, -1035.0), Vector2(2600.0, 105.0), 0.54
	)
	_make_background_layer(
		FAR_FOG_BAND, Vector3(0.0, 58.0, -1020.0), Vector2(2600.0, 120.0), 0.38
	)


func _make_background_layer(
	layer_texture: Texture2D, position: Vector3, size: Vector2, opacity: float
) -> void:
	var layer := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	quad.orientation = PlaneMesh.FACE_Z
	layer.mesh = quad
	layer.position = position
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	material.set_shader_parameter("layer_texture", layer_texture)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("flash_level", 0.0)
	layer.material_override = material
	_background_materials.append(material)
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)
