class_name BarrageTerrain
extends MeshInstance3D

const CINEMATIC_MESH_PATH := "res://addons/archive_barrage/resources/barrage_terrain_cinematic.res"
const CINEMATIC_COLLISION_PATH := "res://addons/archive_barrage/resources/barrage_terrain_cinematic_collision.res"
const PERFORMANCE_MESH_PATH := "res://addons/archive_barrage/resources/barrage_terrain_performance.res"
const PERFORMANCE_COLLISION_PATH := "res://addons/archive_barrage/resources/barrage_terrain_performance_collision.res"
const CINEMATIC_FILM_REVEAL_MESH_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_cinematic_film_reveal.res"
)
const CINEMATIC_FILM_REVEAL_COLLISION_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_cinematic_film_reveal_collision.res"
)
const PERFORMANCE_FILM_REVEAL_MESH_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_performance_film_reveal.res"
)
const PERFORMANCE_FILM_REVEAL_COLLISION_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_performance_film_reveal_collision.res"
)
const CINEMATIC_MESH := preload(CINEMATIC_MESH_PATH)
const CINEMATIC_COLLISION := preload(CINEMATIC_COLLISION_PATH)
const PERFORMANCE_MESH := preload(PERFORMANCE_MESH_PATH)
const PERFORMANCE_COLLISION := preload(PERFORMANCE_COLLISION_PATH)
const TERRAIN_HEIGHT_FIELD_SCRIPT := preload(
	"res://addons/film_revelation/terrain_height_field.gd"
)
const HEIGHT_TEXTURE := preload(
	"res://addons/archive_barrage/assets/generated/terrain/barrage_hill_height_2k.png"
)
const GROUND_SHADER := preload("res://addons/archive_barrage/shaders/steppe_ground.gdshader")
const LYNCH_NIGHT_GROUND_MATERIAL := preload(
	"res://lynch_night_ground_pack/godot/lynch_night_ground_material.tres"
)
const CREST_TARGET_LATERAL_FRACTION := 0.52
const CREST_TARGET_MIN_LATERAL_M := 16.0
const CREST_TARGET_MAX_LATERAL_M := 20.0
const CREST_PROFILE_MIN_OFFSET_M := -6.0
const CREST_PROFILE_MAX_OFFSET_M := 32.0
const CREST_PROFILE_STEP_M := 0.5
const CREST_PROFILE_SLOPE_SPAN_M := 3.0
const CREST_TARGET_SLOPE_FRACTION := 0.35

@export var terrain_width := 1800.0
@export var terrain_depth := 1800.0
@export var maximum_height := 20.0
@export var grid_resolution := 257
@export var use_lynch_night_ground_material := true
@export var film_reveal_hill_enabled := true

var _height_image: Image
var _performance_mode := false
var _film_height_field: TerrainHeightField


func build(
	use_performance_profile: bool = false,
	force_rebuild: bool = false,
	create_collision: bool = true
) -> void:
	_performance_mode = use_performance_profile
	# Film terrain needs enough vertices for 12-30 m crater bowls and aryk banks.
	# Rollback resources keep their original 257/129 topology untouched.
	if film_reveal_hill_enabled:
		grid_resolution = 193 if _performance_mode else 385
	else:
		grid_resolution = 129 if _performance_mode else 257
	_height_image = HEIGHT_TEXTURE.get_image()
	if not force_rebuild:
		mesh = _load_baked_mesh()
	if force_rebuild or mesh == null:
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
	var uv_step := 1.0 / float(grid_resolution - 1)

	for z_index in range(grid_resolution):
		for x_index in range(grid_resolution):
			var uv := Vector2(
				float(x_index) / float(grid_resolution - 1),
				float(z_index) / float(grid_resolution - 1)
			)
			var height := _sample_combined_height_m_uv(uv)
			var x := (uv.x - 0.5) * terrain_width
			var z := (uv.y - 0.5) * terrain_depth
			vertices.append(Vector3(x, height, z))
			uvs.append(uv)

			var hx0 := _sample_combined_height_m_uv(uv - Vector2(uv_step, 0.0))
			var hx1 := _sample_combined_height_m_uv(uv + Vector2(uv_step, 0.0))
			var hz0 := _sample_combined_height_m_uv(uv - Vector2(0.0, uv_step))
			var hz1 := _sample_combined_height_m_uv(uv + Vector2(0.0, uv_step))
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
			# Godot treats clockwise winding as the front face. Keep the terrain's
			# visible/collidable side facing upward so cull_back materials and the
			# one-sided ConcavePolygonShape3D both work from above the ground.
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(b)
			indices.append(d)
			indices.append(c)

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
		terrain_shape = _load_baked_collision()
	elif mesh != null:
		terrain_shape = mesh.create_trimesh_shape() as ConcavePolygonShape3D
	if terrain_shape == null and mesh != null:
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
	return global_position.y + _sample_baked_mesh_height_m_uv(uv)


func has_walkable_ground_at(world_x: float, world_z: float) -> bool:
	var local := to_local(Vector3(world_x, global_position.y, world_z))
	return (
		absf(local.x) <= terrain_width * 0.5 - 1.0
		and absf(local.z) <= terrain_depth * 0.5 - 1.0
	)


func get_walkable_ground_y(world_x: float, world_z: float) -> float:
	return height_at_world(world_x, world_z)


func normal_at_world(world_x: float, world_z: float, sample_distance: float = 1.25) -> Vector3:
	var distance := maxf(sample_distance, 0.05)
	var height_left := height_at_world(world_x - distance, world_z)
	var height_right := height_at_world(world_x + distance, world_z)
	var height_back := height_at_world(world_x, world_z - distance)
	var height_front := height_at_world(world_x, world_z + distance)
	return Vector3(
		height_left - height_right,
		distance * 2.0,
		height_back - height_front
	).normalized()


func get_film_reveal_hill_center_world() -> Vector2:
	_ensure_film_height_field()
	return _film_height_field.hill_center_xz()


func get_film_reveal_slope_target_world() -> Vector3:
	# Compatibility entry point retained for the runtime builder and existing
	# integrations. New code can use the explicit crest-target name below.
	return get_film_reveal_crest_target_world()


func get_film_reveal_crest_target_world() -> Vector3:
	var center := get_film_reveal_hill_center_world()
	var player_xz := Vector2(0.0, 92.0)
	var toward_player := (player_xz - center).normalized()
	var hill_direction := -toward_player
	var hill_side := Vector2(-hill_direction.y, hill_direction.x)
	# From the player's camera, horizontal screen-right is forward x UP.
	# In XZ that is (-forward.z, forward.x), exactly hill_side here.
	var screen_right := hill_side
	var lateral_offset := get_film_reveal_crest_edge_lateral_offset_m()
	var profile_origin := center + screen_right * lateral_offset
	var forward_offset := _find_film_reveal_crest_edge_forward_offset_m(
		profile_origin, toward_player
	)
	var target_xz := profile_origin + toward_player * forward_offset
	return Vector3(target_xz.x, height_at_world(target_xz.x, target_xz.y), target_xz.y)


func get_film_reveal_crest_edge_offset_m() -> float:
	var center := get_film_reveal_hill_center_world()
	var toward_player := (Vector2(0.0, 92.0) - center).normalized()
	var hill_direction := -toward_player
	var hill_side := Vector2(-hill_direction.y, hill_direction.x)
	var profile_origin := center + hill_side * get_film_reveal_crest_edge_lateral_offset_m()
	return _find_film_reveal_crest_edge_forward_offset_m(profile_origin, toward_player)


func get_film_reveal_crest_edge_lateral_offset_m() -> float:
	_ensure_film_height_field()
	return clampf(
		_film_height_field.hill_lateral_sigma_m * CREST_TARGET_LATERAL_FRACTION,
		CREST_TARGET_MIN_LATERAL_M,
		CREST_TARGET_MAX_LATERAL_M
	)


func get_film_reveal_crest_edge_offsets_m() -> Vector2:
	return Vector2(
		get_film_reveal_crest_edge_offset_m(),
		get_film_reveal_crest_edge_lateral_offset_m()
	)


func _find_film_reveal_crest_edge_forward_offset_m(
	profile_origin: Vector2,
	toward_player: Vector2
) -> float:
	# Find the actual crest on the final triangle-interpolated surface first.
	# Then choose the first outward point whose smoothed downhill gradient reaches
	# the controlled onset of the profile maximum (bounded to a walkable 14-32
	# degree band). This
	# places the target on the crown edge, not at an arbitrary mid-slope distance.
	var crest_offset := CREST_PROFILE_MIN_OFFSET_M
	var crest_height := -INF
	var crest_scan_end := 12.0
	var crest_steps := int(round(
		(crest_scan_end - CREST_PROFILE_MIN_OFFSET_M) / CREST_PROFILE_STEP_M
	))
	for step_index in range(crest_steps + 1):
		var offset := CREST_PROFILE_MIN_OFFSET_M + float(step_index) * CREST_PROFILE_STEP_M
		var point := profile_origin + toward_player * offset
		var height := height_at_world(point.x, point.y)
		if height > crest_height:
			crest_height = height
			crest_offset = offset

	var slope_start := maxf(crest_offset + CREST_PROFILE_STEP_M, 1.0)
	var max_downhill_slope := 0.0
	var max_slope_offset := slope_start
	var slope_steps := int(round(
		(CREST_PROFILE_MAX_OFFSET_M - slope_start) / CREST_PROFILE_STEP_M
	))
	for step_index in range(slope_steps + 1):
		var offset := slope_start + float(step_index) * CREST_PROFILE_STEP_M
		var slope := _sample_profile_downhill_slope(profile_origin, toward_player, offset)
		if slope > max_downhill_slope:
			max_downhill_slope = slope
			max_slope_offset = offset

	if max_downhill_slope <= 0.0001:
		return clampf(crest_offset + 6.0, 3.0, 10.0)

	var controlled_slope := clampf(
		max_downhill_slope * CREST_TARGET_SLOPE_FRACTION,
		tan(deg_to_rad(14.0)),
		tan(deg_to_rad(32.0))
	)
	for step_index in range(slope_steps + 1):
		var offset := slope_start + float(step_index) * CREST_PROFILE_STEP_M
		if _sample_profile_downhill_slope(profile_origin, toward_player, offset) >= controlled_slope:
			return clampf(offset, 3.0, 10.0)
	return clampf(max_slope_offset, 3.0, 10.0)


func _sample_profile_downhill_slope(
	profile_origin: Vector2,
	toward_player: Vector2,
	offset_m: float
) -> float:
	var inner := profile_origin + toward_player * (offset_m - CREST_PROFILE_SLOPE_SPAN_M)
	var outer := profile_origin + toward_player * (offset_m + CREST_PROFILE_SLOPE_SPAN_M)
	return (
		height_at_world(inner.x, inner.y) - height_at_world(outer.x, outer.y)
	) / (CREST_PROFILE_SLOPE_SPAN_M * 2.0)


func _sample_height_uv(uv: Vector2) -> float:
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	var x := mini(int(uv.x * float(_height_image.get_width() - 1)), _height_image.get_width() - 1)
	var y := mini(int(uv.y * float(_height_image.get_height() - 1)), _height_image.get_height() - 1)
	return _height_image.get_pixel(x, y).r


func _sample_combined_height_m_uv(uv: Vector2) -> float:
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	var base_height_m := _sample_height_uv(uv) * maximum_height
	if not film_reveal_hill_enabled:
		return base_height_m

	_ensure_film_height_field()
	var local_x := (uv.x - 0.5) * terrain_width
	var local_z := (uv.y - 0.5) * terrain_depth
	var world_position := to_global(Vector3(local_x, 0.0, local_z))
	var world_xz := Vector2(world_position.x, world_position.z)
	var additive_m := (
		_film_height_field.sample_film_steppe_height(world_xz)
		+ _film_height_field.sample_hero_hill_height(world_xz)
	)
	# Gaussian tails otherwise alter every vertex by tiny non-zero amounts.
	# Snap sub-millimetre values to an exact zero outside the composed landmark.
	if absf(additive_m) < 0.001:
		return base_height_m
	return base_height_m + additive_m


func _sample_baked_mesh_height_m_uv(uv: Vector2) -> float:
	# The render and collision resources are baked from grid_resolution vertices.
	# Match their exact triangle interpolation instead of sampling the much denser
	# source heightmap directly, otherwise ground assist pulls the player through
	# the visible/collision surface.
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	var cell_count := maxi(grid_resolution - 1, 1)
	var grid_position := uv * float(cell_count)
	var cell_x := mini(int(floor(grid_position.x)), cell_count - 1)
	var cell_z := mini(int(floor(grid_position.y)), cell_count - 1)
	var local_x := clampf(grid_position.x - float(cell_x), 0.0, 1.0)
	var local_z := clampf(grid_position.y - float(cell_z), 0.0, 1.0)
	var inverse_grid_size := 1.0 / float(cell_count)

	var uv_a := Vector2(float(cell_x), float(cell_z)) * inverse_grid_size
	var uv_b := Vector2(float(cell_x + 1), float(cell_z)) * inverse_grid_size
	var uv_c := Vector2(float(cell_x), float(cell_z + 1)) * inverse_grid_size
	var uv_d := Vector2(float(cell_x + 1), float(cell_z + 1)) * inverse_grid_size
	var height_a := _sample_combined_height_m_uv(uv_a)
	var height_b := _sample_combined_height_m_uv(uv_b)
	var height_c := _sample_combined_height_m_uv(uv_c)
	var height_d := _sample_combined_height_m_uv(uv_d)

	# Mesh indices are (a, b, c) and (b, d, c), split along b-c.
	if local_x + local_z <= 1.0:
		return height_a + (height_b - height_a) * local_x + (height_c - height_a) * local_z
	return (
		height_d
		+ (height_c - height_d) * (1.0 - local_x)
		+ (height_b - height_d) * (1.0 - local_z)
	)


func _ensure_film_height_field() -> void:
	if _film_height_field != null:
		return
	_film_height_field = TERRAIN_HEIGHT_FIELD_SCRIPT.new() as TerrainHeightField
	_film_height_field.player_origin_xz = Vector2(0.0, 92.0)
	_film_height_field.moon_azimuth_deg = -50.042
	_film_height_field.macro_amplitude_m = 0.0
	_film_height_field.meso_amplitude_m = 0.0
	_film_height_field.micro_amplitude_m = 0.0
	_film_height_field.film_observation_lift_m = 9.0
	_film_height_field.film_observation_top_radius_m = 32.0
	_film_height_field.film_observation_slope_radius_m = 88.0
	_film_height_field.film_safe_inner_radius_m = 32.0
	_film_height_field.film_safe_outer_radius_m = 52.0
	_film_height_field.hill_distance_m = 92.0
	_film_height_field.hill_height_m = 33.0
	_film_height_field.hill_forward_sigma_m = 18.0
	_film_height_field.hill_lateral_sigma_m = 31.0
	_film_height_field.hill_shoulder_height_m = 6.4


func _load_baked_mesh() -> ArrayMesh:
	if not film_reveal_hill_enabled:
		return PERFORMANCE_MESH if _performance_mode else CINEMATIC_MESH
	var mesh_path := (
		PERFORMANCE_FILM_REVEAL_MESH_PATH
		if _performance_mode
		else CINEMATIC_FILM_REVEAL_MESH_PATH
	)
	if not ResourceLoader.exists(mesh_path):
		push_warning("BarrageTerrain: film-reveal mesh is not baked; rebuilding at runtime")
		return null
	return ResourceLoader.load(mesh_path) as ArrayMesh


func _load_baked_collision() -> ConcavePolygonShape3D:
	if not film_reveal_hill_enabled:
		return PERFORMANCE_COLLISION if _performance_mode else CINEMATIC_COLLISION
	var collision_path := (
		PERFORMANCE_FILM_REVEAL_COLLISION_PATH
		if _performance_mode
		else CINEMATIC_FILM_REVEAL_COLLISION_PATH
	)
	if not ResourceLoader.exists(collision_path):
		push_warning("BarrageTerrain: film-reveal collision is not baked; rebuilding at runtime")
		return null
	return ResourceLoader.load(collision_path) as ConcavePolygonShape3D


func _create_ground_material() -> ShaderMaterial:
	if use_lynch_night_ground_material:
		return LYNCH_NIGHT_GROUND_MATERIAL

	# Keep the previous diagnostic material available for a one-toggle rollback.
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	return material
