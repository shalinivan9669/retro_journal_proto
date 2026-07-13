class_name BarrageTerrain
extends MeshInstance3D

const CINEMATIC_MESH_PATH := "res://addons/archive_barrage/resources/barrage_terrain_cinematic.res"
const CINEMATIC_COLLISION_PATH := "res://addons/archive_barrage/resources/barrage_terrain_cinematic_collision.res"
const PERFORMANCE_MESH_PATH := "res://addons/archive_barrage/resources/barrage_terrain_performance.res"
const PERFORMANCE_COLLISION_PATH := "res://addons/archive_barrage/resources/barrage_terrain_performance_collision.res"
const CINEMATIC_MESH := preload(CINEMATIC_MESH_PATH)
const CINEMATIC_COLLISION := preload(CINEMATIC_COLLISION_PATH)
const PERFORMANCE_MESH := preload(PERFORMANCE_MESH_PATH)
const PERFORMANCE_COLLISION := preload(PERFORMANCE_COLLISION_PATH)
const HEIGHT_TEXTURE := preload(
	"res://addons/archive_barrage/assets/generated/terrain/barrage_hill_height_2k.png"
)
const GROUND_SHADER := preload("res://addons/archive_barrage/shaders/steppe_ground.gdshader")
const STEPPE_ALBEDO := preload(
	"res://addons/archive_barrage/assets/generated/steppe_ground/steppe_ground_albedo_4k.png"
)
const STEPPE_NORMAL := preload(
	"res://addons/archive_barrage/assets/runtime/steppe_ground/steppe_ground_normal_gl_4k.webp"
)
const STEPPE_ROUGHNESS := preload(
	"res://addons/archive_barrage/assets/generated/steppe_ground/steppe_ground_roughness_4k.png"
)
const STEPPE_WET_MASK := preload(
	"res://addons/archive_barrage/assets/generated/steppe_ground/steppe_ground_wet_mask_4k.png"
)
const STEPPE_AO := preload(
	"res://addons/archive_barrage/assets/generated/steppe_ground/steppe_ground_ao_4k.png"
)
const STEPPE_HEIGHT := preload(
	"res://addons/archive_barrage/assets/generated/steppe_ground/steppe_ground_height_4k.png"
)
const ROCK_ALBEDO := preload(
	"res://addons/archive_barrage/assets/polyhaven/dark_rock_4k/dark_rock_diff_4k.jpg"
)
const ROCK_NORMAL := preload(
	"res://addons/archive_barrage/assets/runtime/dark_rock/dark_rock_normal_gl_4k.webp"
)
const ROCK_ROUGHNESS := preload(
	"res://addons/archive_barrage/assets/polyhaven/dark_rock_4k/dark_rock_rough_4k.jpg"
)
const ROCK_DISPLACEMENT := preload(
	"res://addons/archive_barrage/assets/polyhaven/dark_rock_4k/dark_rock_disp_4k.jpg"
)

@export var terrain_width := 1800.0
@export var terrain_depth := 1800.0
@export var maximum_height := 20.0
@export var grid_resolution := 257

var _height_image: Image
var _performance_mode := false


func build(
	use_performance_profile: bool = false,
	force_rebuild: bool = false,
	create_collision: bool = true
) -> void:
	_performance_mode = use_performance_profile
	grid_resolution = 129 if _performance_mode else 257
	_height_image = HEIGHT_TEXTURE.get_image()
	if not force_rebuild:
		mesh = PERFORMANCE_MESH if _performance_mode else CINEMATIC_MESH
	else:
		mesh = _generate_terrain_mesh()
	material_override = _create_ground_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if create_collision:
		_create_terrain_collision(force_rebuild)


func _generate_terrain_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var cell_x := terrain_width / float(grid_resolution - 1)
	var cell_z := terrain_depth / float(grid_resolution - 1)

	for z_index in range(grid_resolution):
		for x_index in range(grid_resolution):
			var uv := Vector2(
				float(x_index) / float(grid_resolution - 1),
				float(z_index) / float(grid_resolution - 1)
			)
			var height := _sample_height_uv(uv) * maximum_height
			var x := (uv.x - 0.5) * terrain_width
			var z := (uv.y - 0.5) * terrain_depth
			vertices.append(Vector3(x, height, z))
			uvs.append(uv)

			var hx0 := _sample_height_uv(uv - Vector2(1.0 / grid_resolution, 0.0)) * maximum_height
			var hx1 := _sample_height_uv(uv + Vector2(1.0 / grid_resolution, 0.0)) * maximum_height
			var hz0 := _sample_height_uv(uv - Vector2(0.0, 1.0 / grid_resolution)) * maximum_height
			var hz1 := _sample_height_uv(uv + Vector2(0.0, 1.0 / grid_resolution)) * maximum_height
			normals.append(
				(
					Vector3(-(hx1 - hx0) / (cell_x * 2.0), 1.0, -(hz1 - hz0) / (cell_z * 2.0))
					. normalized()
				)
			)
			var tangent := Vector3(1.0, (hx1 - hx0) / (cell_x * 2.0), 0.0).normalized()
			tangents.append(tangent.x)
			tangents.append(tangent.y)
			tangents.append(tangent.z)
			tangents.append(1.0)

	for z_index in range(grid_resolution - 1):
		for x_index in range(grid_resolution - 1):
			var a := z_index * grid_resolution + x_index
			var b := a + 1
			var c := a + grid_resolution
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return terrain_mesh


func _create_terrain_collision(force_rebuild: bool) -> void:
	var terrain_shape: ConcavePolygonShape3D
	if not force_rebuild:
		terrain_shape = PERFORMANCE_COLLISION if _performance_mode else CINEMATIC_COLLISION
	elif mesh != null:
		terrain_shape = mesh.create_trimesh_shape() as ConcavePolygonShape3D
	if terrain_shape == null:
		push_error("BarrageTerrain: could not create terrain collision")
		return

	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = terrain_shape
	static_body.add_child(collision_shape)
	add_child(static_body)


func height_at_world(world_x: float, world_z: float) -> float:
	var local := to_local(Vector3(world_x, 0.0, world_z))
	var uv := Vector2(local.x / terrain_width + 0.5, local.z / terrain_depth + 0.5)
	return global_position.y + _sample_height_uv(uv) * maximum_height


func has_walkable_ground_at(world_x: float, world_z: float) -> bool:
	var local := to_local(Vector3(world_x, global_position.y, world_z))
	return (
		absf(local.x) <= terrain_width * 0.5 - 1.0
		and absf(local.z) <= terrain_depth * 0.5 - 1.0
	)


func get_walkable_ground_y(world_x: float, world_z: float) -> float:
	return height_at_world(world_x, world_z)


func _sample_height_uv(uv: Vector2) -> float:
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	var x := mini(int(uv.x * float(_height_image.get_width() - 1)), _height_image.get_width() - 1)
	var y := mini(int(uv.y * float(_height_image.get_height() - 1)), _height_image.get_height() - 1)
	return _height_image.get_pixel(x, y).r


func _create_ground_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("steppe_albedo", STEPPE_ALBEDO)
	material.set_shader_parameter("steppe_normal", STEPPE_NORMAL)
	material.set_shader_parameter("steppe_roughness", STEPPE_ROUGHNESS)
	material.set_shader_parameter("steppe_wet_mask", STEPPE_WET_MASK)
	material.set_shader_parameter("steppe_ao", STEPPE_AO)
	material.set_shader_parameter("steppe_height", STEPPE_HEIGHT)
	material.set_shader_parameter("rock_albedo", ROCK_ALBEDO)
	material.set_shader_parameter("rock_normal", ROCK_NORMAL)
	material.set_shader_parameter("rock_roughness", ROCK_ROUGHNESS)
	material.set_shader_parameter("rock_displacement", ROCK_DISPLACEMENT)
	return material
