extends SceneTree

# Usage from the project root:
#   godot --headless --path . --script res://tools/test_barrage_living_terrain.gd
#   godot --headless --path . --script res://tools/test_barrage_living_terrain.gd -- --performance

const CINEMATIC_SCENE_PATH := "res://addons/archive_barrage/scenes/ArchiveNightBarrage.tscn"
const PERFORMANCE_SCENE_PATH := (
	"res://addons/archive_barrage/scenes/ArchiveNightBarragePerformance.tscn"
)
const CINEMATIC_FILM_MESH_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_cinematic_film_reveal.res"
)
const PERFORMANCE_FILM_MESH_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_performance_film_reveal.res"
)
const CINEMATIC_ROLLBACK_MESH_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_cinematic.res"
)
const PERFORMANCE_ROLLBACK_MESH_PATH := (
	"res://addons/archive_barrage/resources/barrage_terrain_performance.res"
)

const PLAYER_ORIGIN_XZ := Vector2(0.0, 92.0)
const FOREGROUND_HALF_WIDTH_M := 280.0
const FOREGROUND_NEAR_M := 20.0
const FOREGROUND_FAR_M := 420.0
const FOREGROUND_SAMPLE_STEP_M := 8.0
const SURFACE_MATCH_TOLERANCE_M := 0.03
const OBSERVATION_MIN_GROUND_Y_M := 9.5
const OBSERVATION_MIN_RELATIVE_HEIGHT_M := 5.0
const HERO_CENTER_MIN_Y_M := 32.0
const HERO_TARGET_MIN_Y_M := 29.0

const COMPOSED_CRATERS := [
	{"offset": Vector2(-27.0, -47.0), "radius": 17.0},
	{"offset": Vector2(39.0, -77.0), "radius": 24.0},
	{"offset": Vector2(-77.0, -126.0), "radius": 35.0},
	{"offset": Vector2(88.0, -211.0), "radius": 48.0},
]

var _failure_count := 0
var _performance_mode := false
var _scene_path := CINEMATIC_SCENE_PATH


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	_performance_mode = "--performance" in user_args or "performance" in user_args
	_scene_path = PERFORMANCE_SCENE_PATH if _performance_mode else CINEMATIC_SCENE_PATH
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(_scene_path) as PackedScene
	if packed_scene == null:
		_fail("Could not load %s" % _scene_path)
		quit(1)
		return

	var barrage := packed_scene.instantiate() as Node3D
	if barrage == null:
		_fail("Could not instantiate %s" % _scene_path)
		quit(1)
		return

	get_root().add_child(barrage)
	current_scene = barrage
	# The runtime builder creates the terrain synchronously. Physics frames make
	# the test representative of the fully registered scene without rendering it.
	for _frame in range(12):
		await process_frame
		await physics_frame

	var terrain := barrage.get_node_or_null("SteppeEnvironment") as MeshInstance3D
	var player := barrage.get_node_or_null("Player") as CharacterBody3D
	var target := barrage.get_node_or_null("HorseHillTarget") as Node3D
	_check(terrain != null, "Missing SteppeEnvironment MeshInstance3D")
	_check(player != null, "Missing runtime Player")
	_check(target != null, "Missing runtime HorseHillTarget")
	if terrain == null or player == null or target == null:
		await _finish(barrage)
		return

	barrage.process_mode = Node.PROCESS_MODE_DISABLED
	_assert_active_ground_material(terrain)
	var geometry := _assert_film_grid(terrain)
	if not geometry.is_empty():
		_assert_collision_matches_mesh(terrain, geometry)
		_assert_height_api_matches_mesh(terrain, geometry)
		_assert_safe_player_platform(terrain, player, geometry)
		_assert_observation_plateau_profile(terrain, player, geometry)
		_assert_rear_hero_crest(terrain, player, target, geometry)
		_assert_foreground_relief(terrain, geometry)
		_assert_composed_bowls(terrain, geometry)

	await _finish(barrage)


func _assert_active_ground_material(terrain: MeshInstance3D) -> void:
	var material := terrain.material_override as ShaderMaterial
	_check(material != null, "Terrain material_override is not a ShaderMaterial")
	if material == null:
		return
	_check(material.shader != null, "Active ground ShaderMaterial has no shader")
	if material.shader != null:
		_check(
			material.shader.resource_path.ends_with("lynch_night_ground.gdshader"),
			"Unexpected active terrain shader: %s" % material.shader.resource_path
		)

	var wet_roughness := _shader_float(material, &"wet_roughness")
	var matte_floor := _shader_float(material, &"matte_roughness_floor")
	var residual_specular := _shader_float(material, &"residual_specular")
	_check(
		wet_roughness >= 0.85,
		"Wet ground is still glossy: wet_roughness %.3f is below 0.85" % wet_roughness
	)
	_check(
		matte_floor >= 0.88,
		"Ground roughness floor %.3f is below 0.88" % matte_floor
	)
	_check(
		residual_specular <= 0.12,
		"Ground specular %.3f exceeds the matte limit 0.12" % residual_specular
	)
	print(
		"[LivingTerrainSmoke] material wet_roughness=%.3f matte_floor=%.3f specular=%.3f"
		% [wet_roughness, matte_floor, residual_specular]
	)


func _assert_film_grid(terrain: MeshInstance3D) -> Dictionary:
	var active_mesh := terrain.mesh as ArrayMesh
	_check(active_mesh != null, "Runtime film terrain mesh is not an ArrayMesh")
	if active_mesh == null:
		return {}

	var film_path := (
		PERFORMANCE_FILM_MESH_PATH if _performance_mode else CINEMATIC_FILM_MESH_PATH
	)
	var rollback_path := (
		PERFORMANCE_ROLLBACK_MESH_PATH
		if _performance_mode
		else CINEMATIC_ROLLBACK_MESH_PATH
	)
	var expected_film_grid := 193 if _performance_mode else 385
	var expected_rollback_grid := 129 if _performance_mode else 257
	_check(
		active_mesh.resource_path == film_path,
		"Runtime terrain did not load the film mesh: %s" % active_mesh.resource_path
	)

	var active_geometry := _mesh_geometry(active_mesh, "film")
	var rollback_mesh := load(rollback_path) as ArrayMesh
	_check(rollback_mesh != null, "Could not load rollback mesh %s" % rollback_path)
	if active_geometry.is_empty() or rollback_mesh == null:
		return {}
	var rollback_geometry := _mesh_geometry(rollback_mesh, "rollback")
	if rollback_geometry.is_empty():
		return {}

	var active_grid := int(active_geometry["grid_size"])
	var rollback_grid := int(rollback_geometry["grid_size"])
	var active_vertices := int(active_geometry["vertex_count"])
	var rollback_vertices := int(rollback_geometry["vertex_count"])
	_check(
		active_grid == expected_film_grid,
		"Film grid must be %d x %d for this profile, got %d x %d"
		% [expected_film_grid, expected_film_grid, active_grid, active_grid]
	)
	_check(
		rollback_grid == expected_rollback_grid,
		"Rollback grid changed: expected %d x %d, got %d x %d"
		% [expected_rollback_grid, expected_rollback_grid, rollback_grid, rollback_grid]
	)
	_check(
		active_grid > rollback_grid and active_vertices > rollback_vertices,
		"Film terrain is not denser than rollback (%d vs %d vertices)"
		% [active_vertices, rollback_vertices]
	)
	_check(
		int(terrain.get("grid_resolution")) == active_grid,
		"BarrageTerrain grid_resolution does not match its baked surface"
	)
	print(
		"[LivingTerrainSmoke] grid film=%dx%d (%d vertices) rollback=%dx%d (%d vertices)"
		% [
			active_grid,
			active_grid,
			active_vertices,
			rollback_grid,
			rollback_grid,
			rollback_vertices,
		]
	)
	return active_geometry


func _mesh_geometry(mesh: ArrayMesh, label: String) -> Dictionary:
	_check(mesh.get_surface_count() == 1, "%s terrain mesh must have one surface" % label)
	if mesh.get_surface_count() < 1:
		return {}
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	_check(not vertices.is_empty(), "%s terrain has no vertices" % label)
	if vertices.is_empty():
		return {}
	var grid_size := int(round(sqrt(float(vertices.size()))))
	_check(
		grid_size * grid_size == vertices.size(),
		"%s terrain vertex count %d is not a square grid" % [label, vertices.size()]
	)
	_check(
		indices.size() == (grid_size - 1) * (grid_size - 1) * 6,
		"%s terrain index count %d does not match a %dx%d grid"
		% [label, indices.size(), grid_size, grid_size]
	)
	return {
		"vertices": vertices,
		"indices": indices,
		"grid_size": grid_size,
		"vertex_count": vertices.size(),
	}


func _assert_collision_matches_mesh(
	terrain: MeshInstance3D,
	geometry: Dictionary
) -> void:
	var collision_shape := terrain.get_node_or_null(
		"TerrainCollision/CollisionShape3D"
	) as CollisionShape3D
	_check(collision_shape != null, "Terrain collision node is missing")
	if collision_shape == null:
		return
	var concave := collision_shape.shape as ConcavePolygonShape3D
	_check(concave != null, "Terrain collision is not ConcavePolygonShape3D")
	if concave == null:
		return

	var faces := concave.get_faces()
	var vertices := geometry["vertices"] as PackedVector3Array
	var indices := geometry["indices"] as PackedInt32Array
	_check(
		faces.size() == indices.size(),
		"Collision face data count %d does not match render index count %d"
		% [faces.size(), indices.size()]
	)
	if faces.is_empty() or indices.is_empty():
		return

	var sample_count := mini(257, faces.size())
	var max_vertex_error_m := 0.0
	for sample_index in range(sample_count):
		var face_index := int(
			round(float(sample_index) * float(faces.size() - 1) / float(maxi(sample_count - 1, 1)))
		)
		var render_vertex := vertices[indices[face_index]]
		max_vertex_error_m = maxf(
			max_vertex_error_m,
			faces[face_index].distance_to(render_vertex)
		)
	_check(
		max_vertex_error_m <= 0.0001,
		"Collision diverges from render terrain by %.6f m" % max_vertex_error_m
	)
	print(
		"[LivingTerrainSmoke] collision faces=%d sampled_vertex_error=%.7fm"
		% [faces.size() / 3, max_vertex_error_m]
	)


func _assert_height_api_matches_mesh(
	terrain: MeshInstance3D,
	geometry: Dictionary
) -> void:
	_check(
		terrain.has_method("height_at_world"),
		"BarrageTerrain lacks height_at_world()"
	)
	if not terrain.has_method("height_at_world"):
		return

	var probes := [
		PLAYER_ORIGIN_XZ,
		Vector2(-27.0, 45.0),
		Vector2(39.0, 15.0),
		Vector2(-77.0, -34.0),
		Vector2(88.0, -119.0),
		Vector2(-231.25, -275.5),
		Vector2(214.75, -301.125),
		Vector2(-143.625, 58.375),
		Vector2(126.875, -73.625),
		Vector2(7.25, -327.25),
	]
	var max_error_m := 0.0
	var sum_error_m := 0.0
	for world_xz in probes:
		var mesh_y := _mesh_height_at_world(terrain, geometry, world_xz)
		var api_y := float(terrain.call("height_at_world", world_xz.x, world_xz.y))
		var error_m := absf(mesh_y - api_y)
		max_error_m = maxf(max_error_m, error_m)
		sum_error_m += error_m
	var mean_error_m := sum_error_m / float(probes.size())
	_check(
		max_error_m <= SURFACE_MATCH_TOLERANCE_M,
		"height_at_world() diverges from the baked surface by %.4f m (limit %.3f m)"
		% [max_error_m, SURFACE_MATCH_TOLERANCE_M]
	)
	_check(
		mean_error_m <= 0.01,
		"Mean height_at_world() surface error %.4f m exceeds 0.01 m" % mean_error_m
	)
	print(
		"[LivingTerrainSmoke] surface_match max_error=%.5fm mean_error=%.5fm"
		% [max_error_m, mean_error_m]
	)


func _assert_safe_player_platform(
	terrain: MeshInstance3D,
	player: CharacterBody3D,
	geometry: Dictionary
) -> void:
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	_check(
		player_xz.distance_to(PLAYER_ORIGIN_XZ) <= 0.05,
		"Player origin moved away from the protected platform: %s" % player_xz
	)
	var surface_y := _mesh_height_at_world(terrain, geometry, PLAYER_ORIGIN_XZ)
	var clearance_m := player.global_position.y - surface_y
	_check(
		surface_y >= OBSERVATION_MIN_GROUND_Y_M,
		"Observation plateau is not high enough: spawn ground Y %.3f m" % surface_y
	)
	_check(
		clearance_m >= 0.18 and clearance_m <= 0.30,
		"Player ground clearance %.3f m is unsafe; expected about 0.22 m" % clearance_m
	)
	if terrain.has_method("has_walkable_ground_at"):
		_check(
			bool(terrain.call("has_walkable_ground_at", player_xz.x, player_xz.y)),
			"Player protected platform is not reported as walkable"
		)

	# The mesa crown is a deliberate +9 m observation lift. Damage and random
	# relief must be completely suppressed across the protected inner platform.
	terrain.call("height_at_world", PLAYER_ORIGIN_XZ.x, PLAYER_ORIGIN_XZ.y)
	var height_field := terrain.get("_film_height_field") as TerrainHeightField
	_check(height_field != null, "Terrain did not initialize its TerrainHeightField")
	var safe_additive_values := PackedFloat32Array()
	if height_field != null:
		_check(
			height_field.film_observation_lift_m >= 8.5,
			"Observation lift %.3f m is below the high-plateau requirement"
			% height_field.film_observation_lift_m
		)
		_check(
			height_field.film_observation_top_radius_m >= 30.0,
			"Observation crown radius %.2f m is too small"
			% height_field.film_observation_top_radius_m
		)
		for radius_value in [0.0, 5.0, 10.0, 15.0, 20.0, 28.0]:
			var radius_m := float(radius_value)
			for angle_index in range(12):
				var angle := TAU * float(angle_index) / 12.0
				var point := PLAYER_ORIGIN_XZ + Vector2(cos(angle), sin(angle)) * radius_m
				var additive_m := height_field.sample_film_steppe_height(point)
				safe_additive_values.append(additive_m)
		var additive_min := _packed_min(safe_additive_values)
		var additive_max := _packed_max(safe_additive_values)
		_check(
			additive_min >= 8.5 and additive_max <= 9.5,
			"Protected mesa crown must stay near +9 m, got %.4f..%.4f m"
			% [additive_min, additive_max]
		)
		_check(
			additive_max - additive_min <= 0.001,
			"Damage/noise varies the protected mesa crown by %.6f m"
			% (additive_max - additive_min)
		)

	# Check the rendered/interpolated surface around the capsule, not only the
	# ideal sampler. A coarse performance grid may interpolate across boundaries.
	var safe_heights := PackedFloat32Array()
	var minimum_safe_normal_y := 1.0
	for radius_value in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0]:
		var radius_m := float(radius_value)
		for angle_index in range(12):
			var angle := TAU * float(angle_index) / 12.0
			var point := PLAYER_ORIGIN_XZ + Vector2(cos(angle), sin(angle)) * radius_m
			safe_heights.append(_mesh_height_at_world(terrain, geometry, point))
			if terrain.has_method("normal_at_world"):
				var point_normal := (
					terrain.call("normal_at_world", point.x, point.y, 2.0) as Vector3
				).normalized()
				minimum_safe_normal_y = minf(minimum_safe_normal_y, point_normal.y)
	var safe_range_m := _packed_max(safe_heights) - _packed_min(safe_heights)
	_check(
		safe_range_m <= 1.20,
		"Rendered mesa crown varies by %.3f m inside 20 m" % safe_range_m
	)
	if terrain.has_method("normal_at_world"):
		_check(
			minimum_safe_normal_y >= 0.98,
			"Protected mesa crown is too steep: minimum normal.y=%.4f"
			% minimum_safe_normal_y
		)
	var additive_min_report := _packed_min(safe_additive_values)
	var additive_max_report := _packed_max(safe_additive_values)
	print(
		("[LivingTerrainSmoke] spawn player_y=%.3f ground_y=%.3f clearance=%.3fm "
		+ "crown_range=%.3fm min_normal_y=%.4f additive=%.4f..%.4f")
		% [
			player.global_position.y,
			surface_y,
			clearance_m,
			safe_range_m,
			minimum_safe_normal_y,
			additive_min_report,
			additive_max_report,
		]
	)


func _assert_observation_plateau_profile(
	terrain: MeshInstance3D,
	player: CharacterBody3D,
	geometry: Dictionary
) -> void:
	_check(
		terrain.has_method("get_film_reveal_hill_center_world"),
		"Cannot orient the observation audit without the rear hill center"
	)
	if not terrain.has_method("get_film_reveal_hill_center_world"):
		return
	var hill_center_value: Variant = terrain.call("get_film_reveal_hill_center_world")
	_check(hill_center_value is Vector2, "Rear hill center is not Vector2")
	if not hill_center_value is Vector2:
		return
	var hill_center := hill_center_value as Vector2
	var hill_direction := (hill_center - PLAYER_ORIGIN_XZ).normalized()
	var away_from_hill := -hill_direction

	# Audit the complete visible crown, not only the player capsule footprint.
	var top_heights := PackedFloat32Array()
	for radius_value in [0.0, 8.0, 16.0, 24.0, 28.0]:
		var radius_m := float(radius_value)
		for angle_index in range(24):
			var angle := TAU * float(angle_index) / 24.0
			var point := PLAYER_ORIGIN_XZ + Vector2(cos(angle), sin(angle)) * radius_m
			top_heights.append(_mesh_height_at_world(terrain, geometry, point))
	var top_min_y := _packed_min(top_heights)
	var top_max_y := _packed_max(top_heights)
	var top_range_m := top_max_y - top_min_y
	_check(
		top_min_y >= OBSERVATION_MIN_GROUND_Y_M,
		"Observation crown dips too low: minimum Y %.3f m" % top_min_y
	)
	_check(
		top_range_m <= 1.50,
		"Observation crown is not nearly level: %.3f m variation inside r28"
		% top_range_m
	)

	# Use only the forward/side surroundings so the intentionally taller rear
	# hero ridge cannot hide a low observation mesa in a circular average.
	var surrounding_heights := PackedFloat32Array()
	for radius_value in [96.0, 112.0]:
		var radius_m := float(radius_value)
		for angle_index in range(32):
			var angle := TAU * float(angle_index) / 32.0
			var direction := Vector2(cos(angle), sin(angle))
			if direction.dot(hill_direction) > 0.25:
				continue
			var point := PLAYER_ORIGIN_XZ + direction * radius_m
			surrounding_heights.append(_mesh_height_at_world(terrain, geometry, point))
	var crown_median_y := _packed_median(top_heights)
	var surroundings_median_y := _packed_median(surrounding_heights)
	var relative_height_m := crown_median_y - surroundings_median_y
	_check(
		relative_height_m >= OBSERVATION_MIN_RELATIVE_HEIGHT_M,
		"Observation mesa rises only %.3f m above its forward surroundings"
		% relative_height_m
	)

	# A high viewpoint still needs a traversable shoulder. Sample seven radial
	# paths away from the rear ridge; at least five must avoid a cliff, and the
	# damage-suppressed inner transition must stay gentle on every path.
	var safe_descent_paths := 0
	var best_path_max_slope_deg := INF
	var worst_inner_slope_deg := 0.0
	for angle_degrees in [-75.0, -50.0, -25.0, 0.0, 25.0, 50.0, 75.0]:
		var direction := away_from_hill.rotated(deg_to_rad(float(angle_degrees))).normalized()
		var previous_height := _mesh_height_at_world(terrain, geometry, PLAYER_ORIGIN_XZ)
		var path_max_slope_deg := 0.0
		var path_inner_max_slope_deg := 0.0
		for step_index in range(1, 23):
			var radius_m := float(step_index) * 4.0
			var point := PLAYER_ORIGIN_XZ + direction * radius_m
			var height := _mesh_height_at_world(terrain, geometry, point)
			var slope_deg := rad_to_deg(atan(absf(height - previous_height) / 4.0))
			path_max_slope_deg = maxf(path_max_slope_deg, slope_deg)
			if radius_m <= 52.0:
				path_inner_max_slope_deg = maxf(path_inner_max_slope_deg, slope_deg)
			previous_height = height
		worst_inner_slope_deg = maxf(worst_inner_slope_deg, path_inner_max_slope_deg)
		best_path_max_slope_deg = minf(best_path_max_slope_deg, path_max_slope_deg)
		if path_max_slope_deg <= 35.0:
			safe_descent_paths += 1
	_check(
		worst_inner_slope_deg <= 30.0,
		"Mesa crown/inner shoulder exceeds the 30 degree safety band: %.2f degrees"
		% worst_inner_slope_deg
	)
	_check(
		safe_descent_paths >= 5,
		"Only %d/7 observation-shoulder paths avoid slopes above 35 degrees"
		% safe_descent_paths
	)
	_check(
		best_path_max_slope_deg <= 25.0,
		"Observation mesa has no comfortably walkable descent path (best %.2f degrees)"
		% best_path_max_slope_deg
	)
	print(
		("[LivingTerrainSmoke] plateau top=%.3f..%.3f range=%.3f "
		+ "surroundings_median=%.3f relative=%.3f inner_max_slope=%.2fdeg "
		+ "safe_paths=%d/7 best_path=%.2fdeg")
		% [
			top_min_y,
			top_max_y,
			top_range_m,
			surroundings_median_y,
			relative_height_m,
			worst_inner_slope_deg,
			safe_descent_paths,
			best_path_max_slope_deg,
		]
	)


func _assert_rear_hero_crest(
	terrain: MeshInstance3D,
	player: CharacterBody3D,
	target: Node3D,
	geometry: Dictionary
) -> void:
	var required_methods := [
		"get_film_reveal_hill_center_world",
		"get_film_reveal_slope_target_world",
		"get_film_reveal_crest_edge_offsets_m",
		"normal_at_world",
	]
	for method_name in required_methods:
		_check(terrain.has_method(method_name), "Terrain lacks %s()" % method_name)
	if (
		not terrain.has_method("get_film_reveal_hill_center_world")
		or not terrain.has_method("get_film_reveal_slope_target_world")
		or not terrain.has_method("get_film_reveal_crest_edge_offsets_m")
		or not terrain.has_method("normal_at_world")
	):
		return

	var center_value: Variant = terrain.call("get_film_reveal_hill_center_world")
	var expected_target_value: Variant = terrain.call("get_film_reveal_slope_target_world")
	var offsets_value: Variant = terrain.call("get_film_reveal_crest_edge_offsets_m")
	_check(center_value is Vector2, "Rear hero center must be Vector2")
	_check(expected_target_value is Vector3, "Computed crest-edge target must be Vector3")
	_check(offsets_value is Vector2, "Computed crest-edge offsets must be Vector2")
	if not (center_value is Vector2 and expected_target_value is Vector3 and offsets_value is Vector2):
		return

	var center_xz := center_value as Vector2
	var expected_target := expected_target_value as Vector3
	var public_offsets := offsets_value as Vector2
	var target_xz := Vector2(target.global_position.x, target.global_position.z)
	var player_ground_y := _mesh_height_at_world(terrain, geometry, PLAYER_ORIGIN_XZ)
	var center_y := _mesh_height_at_world(terrain, geometry, center_xz)
	var target_surface_y := _mesh_height_at_world(terrain, geometry, target_xz)

	_check(
		center_y >= HERO_CENTER_MIN_Y_M,
		"Rear hero ridge center Y %.3f m is not tall enough" % center_y
	)
	_check(
		target_surface_y >= HERO_TARGET_MIN_Y_M,
		"Film target crest edge Y %.3f m is too low" % target_surface_y
	)
	_check(
		center_y - player_ground_y >= 18.0,
		"Rear ridge rises only %.3f m above the observation crown"
		% (center_y - player_ground_y)
	)
	_check(
		target_surface_y - player_ground_y >= 16.0,
		"Film target rises only %.3f m above the observation crown"
		% (target_surface_y - player_ground_y)
	)
	_check(
		target.global_position.distance_to(expected_target) <= 0.04,
		"HorseHillTarget is not at the computed crest edge: runtime=%s expected=%s"
		% [target.global_position, expected_target]
	)
	_check(
		absf(target.global_position.y - target_surface_y) <= SURFACE_MATCH_TOLERANCE_M,
		"HorseHillTarget floats %.4f m away from the baked ridge surface"
		% (target.global_position.y - target_surface_y)
	)

	var hill_direction := (center_xz - PLAYER_ORIGIN_XZ).normalized()
	var toward_player := -hill_direction
	var hill_side := Vector2(-hill_direction.y, hill_direction.x)
	# With the camera facing the rear ridge, +hill_side projects to screen-right.
	var screen_right := hill_side
	var center_to_target := target_xz - center_xz
	var forward_offset_m := center_to_target.dot(toward_player)
	var lateral_offset_m := center_to_target.dot(screen_right)
	_check(
		forward_offset_m >= 2.95 and forward_offset_m <= 10.05,
		"Target forward crest offset %.3f m is outside 3..10 m" % forward_offset_m
	)
	_check(
		lateral_offset_m >= 16.0 and lateral_offset_m <= 20.0,
		"Target screen-right lateral offset %.3f m is outside 16..20 m"
		% lateral_offset_m
	)
	_check(
		Vector2(forward_offset_m, lateral_offset_m).distance_to(public_offsets) <= 0.05,
		"Public crest offsets %s disagree with target decomposition %s"
		% [public_offsets, Vector2(forward_offset_m, lateral_offset_m)]
	)

	var target_normal := (
		terrain.call("normal_at_world", target_xz.x, target_xz.y, 0.75) as Vector3
	).normalized()
	var target_safety_normal := (
		terrain.call("normal_at_world", target_xz.x, target_xz.y, 1.25) as Vector3
	).normalized()
	var target_slope_deg := rad_to_deg(acos(clampf(target_normal.y, -1.0, 1.0)))
	_check(
		target_normal.y >= 0.80,
		"Film target slope is unsafe: normal.y=%.4f" % target_normal.y
	)
	_check(
		target_safety_normal.y >= 0.79,
		"Film target broad safety normal is too steep: normal.y=%.4f"
		% target_safety_normal.y
	)
	_check(
		target_slope_deg >= 12.0 and target_slope_deg <= 38.0,
		"Film target is not on a controlled crest edge: slope %.2f degrees"
		% target_slope_deg
	)
	_check(
		target.global_transform.basis.z.normalized().dot(target_normal) >= 0.999,
		"HorseHillTarget outward axis is not aligned to the final terrain normal"
	)

	# Independently reconstruct the lateral profile from baked triangles. This
	# catches a hard-coded offset even if the public helper returns the same value.
	var profile_origin := center_xz + screen_right * lateral_offset_m
	var crest_offset_m := -6.0
	var crest_y := -INF
	var offset_m := -6.0
	while offset_m <= 12.0001:
		var point := profile_origin + toward_player * offset_m
		var height := _mesh_height_at_world(terrain, geometry, point)
		if height > crest_y:
			crest_y = height
			crest_offset_m = offset_m
		offset_m += 0.5

	var max_profile_slope := 0.0
	offset_m = maxf(crest_offset_m + 0.5, 1.0)
	while offset_m <= 32.0001:
		max_profile_slope = maxf(
			max_profile_slope,
			_profile_downhill_slope_from_mesh(
				terrain, geometry, profile_origin, toward_player, offset_m
			)
		)
		offset_m += 0.5
	var target_profile_slope := _profile_downhill_slope_from_mesh(
		terrain, geometry, profile_origin, toward_player, forward_offset_m
	)
	var target_profile_slope_deg := rad_to_deg(atan(maxf(target_profile_slope, 0.0)))
	var slope_fraction := target_profile_slope / maxf(max_profile_slope, 0.0001)
	var outward_point := profile_origin + toward_player * (forward_offset_m + 10.0)
	var outward_y := _mesh_height_at_world(terrain, geometry, outward_point)
	_check(
		forward_offset_m >= crest_offset_m + 0.5
		and forward_offset_m <= crest_offset_m + 12.0,
		"Target is not immediately player-facing from the actual crest (crest %.2f, target %.2f)"
		% [crest_offset_m, forward_offset_m]
	)
	_check(
		crest_y >= target_surface_y + 0.40 and crest_y <= target_surface_y + 10.0,
		"Crest-to-target drop %.3f m does not describe a crown edge"
		% (crest_y - target_surface_y)
	)
	_check(
		target_profile_slope_deg >= 12.0 and target_profile_slope_deg <= 34.0,
		"Smoothed target profile slope %.2f degrees is outside the controlled band"
		% target_profile_slope_deg
	)
	_check(
		slope_fraction >= 0.20 and slope_fraction <= 0.75,
		"Target profile slope is %.3f of maximum, not an onset edge" % slope_fraction
	)
	_check(
		target_surface_y - outward_y >= 2.0,
		"Terrain drops only %.3f m in the 10 m beyond the target edge"
		% (target_surface_y - outward_y)
	)
	print(
		("[LivingTerrainSmoke] absolute_y player=%.3f camera=%.3f center=%.3f target=%.3f "
		+ "offsets[forward=%.2f lateral=%.2f] target_normal_y=%.4f/%.4f "
		+ "crest_offset=%.2f crest_drop=%.2f profile_slope=%.1fdeg fraction=%.3f")
		% [
			player.global_position.y,
			(player.get_node("Head/Camera3D") as Camera3D).global_position.y,
			center_y,
			target_surface_y,
			forward_offset_m,
			lateral_offset_m,
			target_normal.y,
			target_safety_normal.y,
			crest_offset_m,
			crest_y - target_surface_y,
			target_profile_slope_deg,
			slope_fraction,
		]
	)


func _profile_downhill_slope_from_mesh(
	terrain: MeshInstance3D,
	geometry: Dictionary,
	profile_origin: Vector2,
	toward_player: Vector2,
	offset_m: float
) -> float:
	var inner := profile_origin + toward_player * (offset_m - 3.0)
	var outer := profile_origin + toward_player * (offset_m + 3.0)
	return (
		_mesh_height_at_world(terrain, geometry, inner)
		- _mesh_height_at_world(terrain, geometry, outer)
	) / 6.0


func _assert_foreground_relief(
	terrain: MeshInstance3D,
	geometry: Dictionary
) -> void:
	var height_field := terrain.get("_film_height_field") as TerrainHeightField
	_check(height_field != null, "Cannot inspect film relief without TerrainHeightField")
	if height_field == null:
		return

	var columns := int(round(FOREGROUND_HALF_WIDTH_M * 2.0 / FOREGROUND_SAMPLE_STEP_M)) + 1
	var rows := int(round(
		(FOREGROUND_FAR_M - FOREGROUND_NEAR_M) / FOREGROUND_SAMPLE_STEP_M
	)) + 1
	var surface_values := PackedFloat32Array()
	var additive_values := PackedFloat32Array()
	surface_values.resize(columns * rows)
	additive_values.resize(columns * rows)
	var max_api_error_m := 0.0

	for row in range(rows):
		var forward_m := FOREGROUND_NEAR_M + float(row) * FOREGROUND_SAMPLE_STEP_M
		var world_z := PLAYER_ORIGIN_XZ.y - forward_m
		for column in range(columns):
			var world_x := -FOREGROUND_HALF_WIDTH_M + float(column) * FOREGROUND_SAMPLE_STEP_M
			var world_xz := Vector2(world_x, world_z)
			var index := row * columns + column
			var mesh_y := _mesh_height_at_world(terrain, geometry, world_xz)
			var api_y := float(terrain.call("height_at_world", world_x, world_z))
			surface_values[index] = mesh_y
			additive_values[index] = height_field.sample_film_steppe_height(world_xz)
			max_api_error_m = maxf(max_api_error_m, absf(mesh_y - api_y))

	var surface_stats := _statistics(surface_values)
	var additive_stats := _statistics(additive_values)
	var negative_count := 0
	var positive_count := 0
	for value in additive_values:
		if value <= -2.0:
			negative_count += 1
		if value >= 4.0:
			positive_count += 1

	var max_slope_degrees := 0.0
	var steep_edge_count := 0
	var edge_count := 0
	for row in range(rows):
		for column in range(columns):
			var index := row * columns + column
			if column + 1 < columns:
				var delta_x := absf(surface_values[index + 1] - surface_values[index])
				var slope_x := rad_to_deg(atan(delta_x / FOREGROUND_SAMPLE_STEP_M))
				max_slope_degrees = maxf(max_slope_degrees, slope_x)
				steep_edge_count += 1 if slope_x >= 12.0 else 0
				edge_count += 1
			if row + 1 < rows:
				var delta_z := absf(surface_values[index + columns] - surface_values[index])
				var slope_z := rad_to_deg(atan(delta_z / FOREGROUND_SAMPLE_STEP_M))
				max_slope_degrees = maxf(max_slope_degrees, slope_z)
				steep_edge_count += 1 if slope_z >= 12.0 else 0
				edge_count += 1

	var sample_count := additive_values.size()
	_check(
		float(additive_stats["minimum"]) <= -10.0,
		"Foreground has no deep depressions: additive min %.3f m" % additive_stats["minimum"]
	)
	_check(
		float(additive_stats["maximum"]) >= 15.0,
		"Foreground has no strong hills/rims: additive max %.3f m" % additive_stats["maximum"]
	)
	_check(
		float(additive_stats["standard_deviation"]) >= 5.0,
		"Foreground relief is statistically flat: additive stddev %.3f m"
		% additive_stats["standard_deviation"]
	)
	_check(
		negative_count >= int(ceil(float(sample_count) * 0.03)),
		"Too few foreground depressions <= -2 m: %d/%d"
		% [negative_count, sample_count]
	)
	_check(
		positive_count >= int(ceil(float(sample_count) * 0.25)),
		"Too little raised foreground >= +4 m: %d/%d"
		% [positive_count, sample_count]
	)
	_check(
		float(surface_stats["range"]) >= 28.0,
		"Rendered foreground height range %.3f m is not strongly expressive"
		% surface_stats["range"]
	)
	_check(
		float(surface_stats["standard_deviation"]) >= 5.0,
		"Rendered foreground stddev %.3f m is too flat"
		% surface_stats["standard_deviation"]
	)
	_check(
		max_slope_degrees >= 25.0,
		"Rendered foreground lacks strong slopes: max %.2f degrees" % max_slope_degrees
	)
	_check(
		steep_edge_count >= int(ceil(float(edge_count) * 0.015)),
		"Strong slopes are isolated: only %d/%d edges reach 12 degrees"
		% [steep_edge_count, edge_count]
	)
	_check(
		max_api_error_m <= SURFACE_MATCH_TOLERANCE_M,
		"Foreground height API diverges from mesh by %.4f m" % max_api_error_m
	)
	print(
		("[LivingTerrainSmoke] foreground surface[min=%.2f max=%.2f range=%.2f "
		+ "std=%.2f] additive[min=%.2f max=%.2f std=%.2f neg=%d pos=%d] "
		+ "slope[max=%.1fdeg steep=%d/%d]")
		% [
			surface_stats["minimum"],
			surface_stats["maximum"],
			surface_stats["range"],
			surface_stats["standard_deviation"],
			additive_stats["minimum"],
			additive_stats["maximum"],
			additive_stats["standard_deviation"],
			negative_count,
			positive_count,
			max_slope_degrees,
			steep_edge_count,
			edge_count,
		]
	)


func _assert_composed_bowls(
	terrain: MeshInstance3D,
	geometry: Dictionary
) -> void:
	var bowl_count := 0
	for crater_data in COMPOSED_CRATERS:
		var center := PLAYER_ORIGIN_XZ + (crater_data["offset"] as Vector2)
		var radius_m := float(crater_data["radius"])
		var low_y := _mesh_height_at_world(terrain, geometry, center)
		# Allow the combined macro slope to shift the apparent bottom slightly.
		for angle_index in range(12):
			var angle := TAU * float(angle_index) / 12.0
			var inner_point := center + Vector2(cos(angle), sin(angle)) * radius_m * 0.18
			low_y = minf(low_y, _mesh_height_at_world(terrain, geometry, inner_point))

		var near_sum := 0.0
		var rim_sum := 0.0
		var raised_rim_samples := 0
		for angle_index in range(16):
			var angle := TAU * float(angle_index) / 16.0
			var direction := Vector2(cos(angle), sin(angle))
			var near_y := _mesh_height_at_world(
				terrain, geometry, center + direction * radius_m * 0.34
			)
			var rim_y := _mesh_height_at_world(
				terrain, geometry, center + direction * radius_m * 1.02
			)
			near_sum += near_y
			rim_sum += rim_y
			if rim_y >= low_y + 1.5:
				raised_rim_samples += 1
		var near_depth_m := near_sum / 16.0 - low_y
		var rim_depth_m := rim_sum / 16.0 - low_y
		var is_bowl := (
			near_depth_m >= 0.65
			and rim_depth_m >= 3.0
			and raised_rim_samples >= 10
		)
		if is_bowl:
			bowl_count += 1
		print(
			"[LivingTerrainSmoke] bowl center=%s near_depth=%.2f rim_depth=%.2f rim_samples=%d/16"
			% [center, near_depth_m, rim_depth_m, raised_rim_samples]
		)
	_check(
		bowl_count >= 3,
		"Only %d/%d composed foreground sites read as bowl-like local minima"
		% [bowl_count, COMPOSED_CRATERS.size()]
	)


func _mesh_height_at_world(
	terrain: MeshInstance3D,
	geometry: Dictionary,
	world_xz: Vector2
) -> float:
	var vertices := geometry["vertices"] as PackedVector3Array
	var grid_size := int(geometry["grid_size"])
	var local := terrain.to_local(Vector3(world_xz.x, 0.0, world_xz.y))
	var minimum_x := vertices[0].x
	var minimum_z := vertices[0].z
	var maximum_x := vertices[grid_size - 1].x
	var maximum_z := vertices[(grid_size - 1) * grid_size].z
	var normalized_x := clampf((local.x - minimum_x) / (maximum_x - minimum_x), 0.0, 1.0)
	var normalized_z := clampf((local.z - minimum_z) / (maximum_z - minimum_z), 0.0, 1.0)
	var grid_position := Vector2(normalized_x, normalized_z) * float(grid_size - 1)
	var cell_x := mini(int(floor(grid_position.x)), grid_size - 2)
	var cell_z := mini(int(floor(grid_position.y)), grid_size - 2)
	var fraction_x := clampf(grid_position.x - float(cell_x), 0.0, 1.0)
	var fraction_z := clampf(grid_position.y - float(cell_z), 0.0, 1.0)

	var a := vertices[cell_z * grid_size + cell_x]
	var b := vertices[cell_z * grid_size + cell_x + 1]
	var c := vertices[(cell_z + 1) * grid_size + cell_x]
	var d := vertices[(cell_z + 1) * grid_size + cell_x + 1]
	var local_y := 0.0
	if fraction_x + fraction_z <= 1.0:
		local_y = a.y + (b.y - a.y) * fraction_x + (c.y - a.y) * fraction_z
	else:
		local_y = (
			d.y
			+ (c.y - d.y) * (1.0 - fraction_x)
			+ (b.y - d.y) * (1.0 - fraction_z)
		)
	return terrain.to_global(Vector3(local.x, local_y, local.z)).y


func _statistics(values: PackedFloat32Array) -> Dictionary:
	var minimum := INF
	var maximum := -INF
	var sum := 0.0
	for value in values:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		sum += value
	var mean := sum / float(maxi(values.size(), 1))
	var squared_sum := 0.0
	for value in values:
		var delta := value - mean
		squared_sum += delta * delta
	var standard_deviation := sqrt(squared_sum / float(maxi(values.size(), 1)))
	return {
		"minimum": minimum,
		"maximum": maximum,
		"range": maximum - minimum,
		"mean": mean,
		"standard_deviation": standard_deviation,
	}


func _packed_min(values: PackedFloat32Array) -> float:
	var result := INF
	for value in values:
		result = minf(result, value)
	return result


func _packed_max(values: PackedFloat32Array) -> float:
	var result := -INF
	for value in values:
		result = maxf(result, value)
	return result


func _packed_median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return NAN
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var middle := sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return sorted_values[middle]
	return (sorted_values[middle - 1] + sorted_values[middle]) * 0.5


func _shader_float(material: ShaderMaterial, parameter: StringName) -> float:
	var value: Variant = material.get_shader_parameter(parameter)
	_check(
		typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT,
		"Active ground material lacks numeric shader parameter %s" % parameter
	)
	return float(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else -INF


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failure_count += 1
	push_error("[LivingTerrainSmoke] %s" % message)


func _finish(barrage: Node) -> void:
	var profile_name := "performance" if _performance_mode else "cinematic"
	var exit_code := 0 if _failure_count == 0 else 1
	if exit_code == 0:
		print("BARRAGE_LIVING_TERRAIN_SMOKE_PASS profile=%s" % profile_name)
	else:
		print(
			"BARRAGE_LIVING_TERRAIN_SMOKE_FAIL profile=%s failures=%d"
			% [profile_name, _failure_count]
		)
	barrage.queue_free()
	await process_frame
	quit(exit_code)
