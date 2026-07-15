extends SceneTree

# Usage from the project root:
#   godot --headless --path . --script res://tools/test_riders_manifestation.gd
#   godot --headless --path . --script res://tools/test_riders_manifestation.gd -- --performance

const CINEMATIC_SCENE_PATH := "res://addons/archive_barrage/scenes/ArchiveNightBarrage.tscn"
const PERFORMANCE_SCENE_PATH := (
	"res://addons/archive_barrage/scenes/ArchiveNightBarragePerformance.tscn"
)
const RIDERS_SCRIPT_PATH := "res://addons/film_revelation/riders_manifestation.gd"
const WHITE_SOURCE_PATH := (
	"res://assets/film/two_white_horses/riders/white_rider_source.glb"
)
const BLACK_SOURCE_PATH := (
	"res://assets/film/two_white_horses/riders/black_rider_source.glb"
)

const WHITE_SOURCE_DIMENSIONS_M := Vector3(1.1523988, 1.8857769, 1.8615599)
const BLACK_SOURCE_DIMENSIONS_M := Vector3(1.1044779, 1.8970714, 1.8156104)
const WHITE_SOURCE_TRIANGLES := 500000
const BLACK_SOURCE_TRIANGLES := 499996
const SOURCE_DIMENSION_TOLERANCE_M := 0.002
const GROUND_TOLERANCE_M := 0.05
const FINAL_HEIGHT_MIN_M := 4.45
const FINAL_HEIGHT_MAX_M := 4.5001
const COLD_RENDER_LAYER := 1 << 19

var _failures: Array[String] = []
var _performance_mode := false
var _scene_path := CINEMATIC_SCENE_PATH


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	_performance_mode = "--performance" in user_args or "performance" in user_args
	_scene_path = PERFORMANCE_SCENE_PATH if _performance_mode else CINEMATIC_SCENE_PATH
	call_deferred("_run")


func _run() -> void:
	_assert_manifest_path_has_no_dynamic_load()

	var packed_scene := load(_scene_path) as PackedScene
	_check(packed_scene != null, "could not load %s" % _scene_path)
	if packed_scene == null:
		_finish_test(null)
		return

	var barrage := packed_scene.instantiate() as Node3D
	_check(barrage != null, "could not instantiate %s" % _scene_path)
	if barrage == null:
		_finish_test(null)
		return

	root.add_child(barrage)
	current_scene = barrage
	# The runtime builder is synchronous. A few frames register its terrain
	# collision in PhysicsServer before the grounding assertions below.
	for _frame in range(4):
		await process_frame
		await physics_frame

	var terrain := barrage.get_node_or_null("SteppeEnvironment") as BarrageTerrain
	var target := barrage.get_node_or_null("HorseHillTarget") as Node3D
	var player := barrage.get_node_or_null("Player") as CharacterBody3D
	var riders := barrage.get_node_or_null("RidersManifestation") as RidersManifestation
	_check(terrain != null, "runtime SteppeEnvironment is missing")
	_check(target != null, "runtime HorseHillTarget is missing")
	_check(player != null, "runtime Player is missing")
	_check(riders != null, "runtime RidersManifestation is missing")
	if terrain == null or target == null or player == null or riders == null:
		_finish_test(barrage)
		return

	_check(riders.get_parent() == barrage, "RidersManifestation must be a direct barrage child")
	_assert_required_direct_tree(riders)
	_assert_source_model(
		riders.white_rider,
		"white",
		WHITE_SOURCE_PATH,
		WHITE_SOURCE_DIMENSIONS_M,
		WHITE_SOURCE_TRIANGLES
	)
	_assert_source_model(
		riders.black_rider,
		"black",
		BLACK_SOURCE_PATH,
		BLACK_SOURCE_DIMENSIONS_M,
		BLACK_SOURCE_TRIANGLES
	)
	_assert_crest_placement_and_grounding(riders, terrain, target, player)
	_assert_cold_light_and_render_isolation(riders)

	# Stop unrelated barrage simulation while exercising the synchronous
	# one-shot and immediate material-restore contract.
	barrage.process_mode = Node.PROCESS_MODE_DISABLED
	_assert_one_shot_and_immediate_restore(riders)

	_finish_test(barrage)


func _assert_manifest_path_has_no_dynamic_load() -> void:
	_check(FileAccess.file_exists(RIDERS_SCRIPT_PATH), "manifestation script is missing")
	if not FileAccess.file_exists(RIDERS_SCRIPT_PATH):
		return
	var source := FileAccess.get_file_as_string(RIDERS_SCRIPT_PATH)
	_check(not source.is_empty(), "manifestation script could not be read")
	_check(
		source.contains(WHITE_SOURCE_PATH) and source.contains(BLACK_SOURCE_PATH),
		"both rider sources must be resident preloads"
	)
	_check(
		not source.contains("ResourceLoader.load"),
		"manifestation code must not call ResourceLoader.load()"
	)
	var dynamic_load_pattern := RegEx.new()
	var compile_error := dynamic_load_pattern.compile("(^|[^A-Za-z0-9_])load\\s*\\(")
	_check(compile_error == OK, "dynamic-load static-scan regex did not compile")
	if compile_error == OK:
		var dynamic_load_match := dynamic_load_pattern.search(source)
		_check(
			dynamic_load_match == null,
			"manifestation code contains load() outside its resident preloads"
		)


func _assert_required_direct_tree(riders: RidersManifestation) -> void:
	var required_names := [
		"RidersCenter",
		"WhiteRiderPoint",
		"BlackRiderPoint",
		"WhiteRider",
		"BlackRider",
	]
	for required_name in required_names:
		var child := riders.get_node_or_null(NodePath(required_name))
		_check(child != null, "required node %s is missing" % required_name)
		if child != null:
			_check(
				child.get_parent() == riders,
				"%s must be a direct RidersManifestation child" % required_name
			)
	_check(riders.get_child_count() == 5, "RidersManifestation must have exactly five direct children")
	_check(riders.riders_center is Marker3D, "RidersCenter must be Marker3D")
	_check(riders.white_rider_point is Marker3D, "WhiteRiderPoint must be Marker3D")
	_check(riders.black_rider_point is Marker3D, "BlackRiderPoint must be Marker3D")
	_check(
		riders.get_node_or_null("RidersCenter") == riders.riders_center,
		"RidersCenter public reference is stale"
	)
	_check(
		riders.get_node_or_null("WhiteRider") == riders.white_rider,
		"WhiteRider public reference is stale"
	)
	_check(
		riders.get_node_or_null("BlackRider") == riders.black_rider,
		"BlackRider public reference is stale"
	)

	_assert_ground_ray(
		riders.get_node_or_null("WhiteRiderPoint/WhiteGroundRay") as RayCast3D,
		"white"
	)
	_assert_ground_ray(
		riders.get_node_or_null("BlackRiderPoint/BlackGroundRay") as RayCast3D,
		"black"
	)


func _assert_ground_ray(ray: RayCast3D, label: String) -> void:
	_check(ray != null, "%s 10 m grounding ray is missing" % label)
	if ray == null:
		return
	_check(
		is_equal_approx(ray.position.y, RidersManifestation.GROUND_RAY_ORIGIN_HEIGHT_M),
		"%s ray must begin exactly 10 m above its terrain point" % label
	)
	_check(
		ray.target_position.is_equal_approx(
			Vector3(0.0, -RidersManifestation.GROUND_RAY_LENGTH_M, 0.0)
		),
		"%s ray must cast straight down through the terrain" % label
	)
	_check(ray.collision_mask == 1, "%s ray must use the terrain collision mask" % label)
	_check(ray.collide_with_bodies, "%s ray must collide with terrain bodies" % label)
	_check(not ray.collide_with_areas, "%s ray must ignore areas" % label)
	_check(not ray.enabled, "%s ray must disable itself after grounding" % label)


func _assert_source_model(
	model: Node3D,
	label: String,
	expected_scene_path: String,
	expected_dimensions: Vector3,
	expected_triangles: int
) -> void:
	_check(model != null, "%s GLB root was not instantiated at scene load" % label)
	if model == null:
		return
	_check(
		String(model.scene_file_path) == expected_scene_path,
		"%s direct child is not the expected resident GLB root: %s"
		% [label, model.scene_file_path]
	)
	_check(not model.visible, "%s GLB root must start hidden" % label)
	_check(
		model.process_mode == Node.PROCESS_MODE_DISABLED,
		"%s GLB root must start process-disabled" % label
	)

	var meshes := _mesh_instances(model)
	_check(not meshes.is_empty(), "%s resident GLB has no MeshInstance3D" % label)
	var triangle_count := 0
	for mesh_instance in meshes:
		_check(
			not mesh_instance.is_visible_in_tree(),
			"%s resident mesh must be hidden before manifestation" % label
		)
		_check(
			mesh_instance.process_mode == Node.PROCESS_MODE_DISABLED,
			"%s resident mesh must be process-disabled" % label
		)
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			_check(
				mesh_instance.mesh.surface_get_primitive_type(surface_index)
				== Mesh.PRIMITIVE_TRIANGLES,
				"%s source surface %d is not a triangle surface" % [label, surface_index]
			)
			var index_count: int = mesh_instance.mesh.surface_get_array_index_len(surface_index)
			var vertex_count: int = mesh_instance.mesh.surface_get_array_len(surface_index)
			triangle_count += int((index_count if index_count > 0 else vertex_count) / 3)

	var source_bounds := _visual_bounds_in_space(model, model)
	var dimension_error := _maximum_component_abs(source_bounds.size - expected_dimensions)
	_check(
		dimension_error <= SOURCE_DIMENSION_TOLERANCE_M,
		"%s source dimensions changed: got %s expected %s (max error %.5f m)"
		% [label, source_bounds.size, expected_dimensions, dimension_error]
	)
	_check(
		triangle_count == expected_triangles,
		"%s source triangle count changed: got %d expected %d"
		% [label, triangle_count, expected_triangles]
	)

	var forbidden_nodes: Array[String] = []
	for node in _subtree_nodes(model):
		_check(
			node.process_mode == Node.PROCESS_MODE_DISABLED,
			"%s source descendant %s is not process-disabled" % [label, node.name]
		)
		if (
			node is Skeleton3D
			or node is AnimationPlayer
			or node is AnimationTree
			or node is CollisionObject3D
			or node is CollisionShape3D
			or node is CollisionPolygon3D
		):
			forbidden_nodes.append("%s:%s" % [node.name, node.get_class()])
	_check(
		forbidden_nodes.is_empty(),
		"%s source must be static and collider-free; found %s" % [label, forbidden_nodes]
	)
	print(
		"[RidersManifestation] %s source=%s triangles=%d"
		% [label, source_bounds.size, triangle_count]
	)


func _assert_crest_placement_and_grounding(
	riders: RidersManifestation,
	terrain: BarrageTerrain,
	target: Node3D,
	player: CharacterBody3D
) -> void:
	_check(
		terrain.has_method("get_film_reveal_crest_target_world"),
		"terrain lacks get_film_reveal_crest_target_world()"
	)
	if not terrain.has_method("get_film_reveal_crest_target_world"):
		return
	var crest_value: Variant = terrain.call("get_film_reveal_crest_target_world")
	_check(crest_value is Vector3, "terrain crest target must be Vector3")
	if not crest_value is Vector3:
		return
	var crest_world := crest_value as Vector3
	_check(
		target.global_position.distance_to(crest_world) <= 0.05,
		"HorseHillTarget is not at the final terrain crest"
	)
	_check(
		riders.riders_center.global_position.distance_to(target.global_position) <= 0.02,
		"RidersCenter must exactly reuse HorseHillTarget terrain position"
	)

	var center_inverse := riders.riders_center.global_transform.affine_inverse()
	var white_local := center_inverse * riders.white_rider_point.global_position
	var black_local := center_inverse * riders.black_rider_point.global_position
	_check(
		absf(white_local.x + RidersManifestation.RIDER_LATERAL_OFFSET_M) <= 0.01,
		"white point must be 2.2 m screen-left (got %.4f)" % white_local.x
	)
	_check(absf(white_local.z) <= 0.01, "white point depth offset must be zero")
	_check(
		absf(black_local.x - RidersManifestation.RIDER_LATERAL_OFFSET_M) <= 0.01,
		"black point must be 2.2 m screen-right (got %.4f)" % black_local.x
	)
	_check(
		absf(black_local.z + RidersManifestation.BLACK_RIDER_DEPTH_OFFSET_M) <= 0.01,
		"black point must be 0.7 m farther from the player (got %.4f)" % black_local.z
	)

	var toward_player := player.global_position - riders.riders_center.global_position
	toward_player.y = 0.0
	toward_player = toward_player.normalized()
	var center_front := riders.riders_center.global_basis.z.normalized()
	center_front.y = 0.0
	center_front = center_front.normalized()
	_check(
		center_front.dot(toward_player) >= 0.999,
		"RidersCenter +Z must face the player"
	)
	for model in [riders.white_rider, riders.black_rider]:
		var model_front: Vector3 = model.global_basis.z.normalized()
		model_front.y = 0.0
		model_front = model_front.normalized()
		_check(model_front.dot(toward_player) >= 0.999, "%s +Z does not face player" % model.name)

	_assert_model_grounded(riders.white_rider_point, riders.white_rider, terrain, "white")
	_assert_model_grounded(riders.black_rider_point, riders.black_rider, terrain, "black")


func _assert_model_grounded(
	point: Marker3D,
	model: Node3D,
	terrain: BarrageTerrain,
	label: String
) -> void:
	var sampled_ground_y := float(terrain.height_at_world(point.global_position.x, point.global_position.z))
	_check(
		absf(point.global_position.y - sampled_ground_y) <= GROUND_TOLERANCE_M,
		"%s point misses triangle-interpolated terrain by %.4f m"
		% [label, absf(point.global_position.y - sampled_ground_y)]
	)
	var world_bounds := _world_visual_bounds(model)
	var visual_bottom_y := world_bounds.position.y
	_check(
		absf(visual_bottom_y - sampled_ground_y) <= GROUND_TOLERANCE_M,
		"%s visual bottom misses terrain by %.4f m"
		% [label, absf(visual_bottom_y - sampled_ground_y)]
	)
	_check(
		world_bounds.size.y >= FINAL_HEIGHT_MIN_M
		and world_bounds.size.y <= FINAL_HEIGHT_MAX_M,
		"%s final height %.4f m must remain in %.2f..4.50 m"
		% [label, world_bounds.size.y, FINAL_HEIGHT_MIN_M]
	)
	print(
		"[RidersManifestation] %s ground_y=%.4f bottom_y=%.4f final_height=%.4f"
		% [label, sampled_ground_y, visual_bottom_y, world_bounds.size.y]
	)


func _assert_cold_light_and_render_isolation(riders: RidersManifestation) -> void:
	var cold_light := riders.get_node_or_null("RidersCenter/ColdRimLight") as OmniLight3D
	_check(cold_light != null, "dedicated ColdRimLight is missing")
	if cold_light != null:
		_check(not cold_light.visible, "cold rim light must start hidden")
		_check(
			cold_light.light_cull_mask == COLD_RENDER_LAYER,
			"cold light must cull to only the special rider layer"
		)
		_check(not cold_light.shadow_enabled, "cold light shadows must be disabled")
		_check(
			cold_light.light_color.b > cold_light.light_color.g
			and cold_light.light_color.g > cold_light.light_color.r,
			"rider rim light must remain cold blue"
		)
		_check(cold_light.position.z < 0.0, "cold light must remain behind +Z-facing riders")

	for model in [riders.white_rider, riders.black_rider]:
		for mesh_instance in _mesh_instances(model):
			_check(
				(mesh_instance.layers & COLD_RENDER_LAYER) != 0,
				"%s is missing the cold-light render layer" % mesh_instance.name
			)
			_check(
				mesh_instance.cast_shadow
				== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"%s must not cast shadows" % mesh_instance.name
			)


func _assert_one_shot_and_immediate_restore(riders: RidersManifestation) -> void:
	_check(riders.has_method("manifest"), "manifest() API is missing")
	_check(riders.has_method("show_immediate"), "show_immediate() API is missing")
	var material_snapshot := _capture_surface_overrides(riders)
	var finish_count := [0]
	riders.manifestation_finished.connect(func() -> void: finish_count[0] += 1)

	_check(riders.manifest(20.0), "first manifestation request must start")
	_check(
		riders.white_rider.visible and riders.black_rider.visible,
		"manifest() must reveal both pre-instantiated roots"
	)
	_check(_has_transition_override(riders), "manifest() did not install resident dither materials")
	_check(not riders.manifest(20.0), "manifestation must reject a concurrent second request")

	# This is deliberately called while the long reveal is active. It verifies
	# archive hydration/forced completion can restore the exact imported PBR
	# overrides immediately, without waiting for a process frame.
	riders.show_immediate()
	_check(riders.riders_manifested, "show_immediate() did not complete the active manifestation")
	_check(not riders.is_processing(), "show_immediate() left manifestation processing active")
	_check(finish_count[0] == 1, "immediate completion must emit exactly one finished signal")
	_check(
		riders.white_rider.visible and riders.black_rider.visible,
		"immediate completion must leave both riders visible"
	)
	var cold_light := riders.get_node_or_null("RidersCenter/ColdRimLight") as OmniLight3D
	_check(cold_light != null and cold_light.visible, "immediate completion must enable cold rim")
	_assert_surface_overrides_restored(material_snapshot)
	_check(not riders.manifest(), "completed manifestation must remain one-shot")
	riders.show_immediate()
	_check(finish_count[0] == 1, "show_immediate() must be idempotent after completion")


func _mesh_instances(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result


func _subtree_nodes(model: Node3D) -> Array[Node]:
	var result: Array[Node] = [model]
	for node in model.find_children("*", "", true, false):
		result.append(node)
	return result


func _capture_surface_overrides(riders: RidersManifestation) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for model in [riders.white_rider, riders.black_rider]:
		for mesh_instance in _mesh_instances(model):
			if mesh_instance.mesh == null:
				continue
			var surface_overrides: Array[Material] = []
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				surface_overrides.append(
					mesh_instance.get_surface_override_material(surface_index)
				)
			snapshot.append({
				"mesh": mesh_instance,
				"whole": mesh_instance.material_override,
				"surfaces": surface_overrides,
			})
	return snapshot


func _has_transition_override(riders: RidersManifestation) -> bool:
	for model in [riders.white_rider, riders.black_rider]:
		for mesh_instance in _mesh_instances(model):
			if mesh_instance.material_override is ShaderMaterial:
				return true
			if mesh_instance.mesh == null:
				continue
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.get_surface_override_material(surface_index) is ShaderMaterial:
					return true
	return false


func _assert_surface_overrides_restored(snapshot: Array[Dictionary]) -> void:
	for record in snapshot:
		var mesh_instance := record["mesh"] as MeshInstance3D
		_check(
			is_same(mesh_instance.material_override, record["whole"]),
			"whole imported material override was not restored exactly"
		)
		var original_surfaces: Array = record["surfaces"]
		for surface_index in range(original_surfaces.size()):
			_check(
				is_same(
					mesh_instance.get_surface_override_material(surface_index),
					original_surfaces[surface_index]
				),
				"surface %d imported override was not restored exactly" % surface_index
			)


func _visual_bounds_in_space(model: Node3D, space: Node3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found := false
	var world_to_space := space.global_transform.affine_inverse()
	for mesh_instance in _mesh_instances(model):
		if mesh_instance.mesh == null:
			continue
		var mesh_to_space := world_to_space * mesh_instance.global_transform
		var source_bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := source_bounds.position + Vector3(
				source_bounds.size.x if (corner_index & 1) != 0 else 0.0,
				source_bounds.size.y if (corner_index & 2) != 0 else 0.0,
				source_bounds.size.z if (corner_index & 4) != 0 else 0.0
			)
			var transformed_corner := mesh_to_space * corner
			minimum = minimum.min(transformed_corner)
			maximum = maximum.max(transformed_corner)
			found = true
	return AABB(minimum, maximum - minimum) if found else AABB()


func _world_visual_bounds(model: Node3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found := false
	for mesh_instance in _mesh_instances(model):
		if mesh_instance.mesh == null:
			continue
		var source_bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := source_bounds.position + Vector3(
				source_bounds.size.x if (corner_index & 1) != 0 else 0.0,
				source_bounds.size.y if (corner_index & 2) != 0 else 0.0,
				source_bounds.size.z if (corner_index & 4) != 0 else 0.0
			)
			var world_corner := mesh_instance.global_transform * corner
			minimum = minimum.min(world_corner)
			maximum = maximum.max(world_corner)
			found = true
	return AABB(minimum, maximum - minimum) if found else AABB()


func _maximum_component_abs(value: Vector3) -> float:
	return maxf(absf(value.x), maxf(absf(value.y), absf(value.z)))


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[RidersManifestation:%s] %s" % [_profile_name(), message])


func _profile_name() -> String:
	return "performance" if _performance_mode else "cinematic"


func _finish_test(barrage: Node) -> void:
	var exit_code := 0 if _failures.is_empty() else 1
	if exit_code == 0:
		print("RIDERS_MANIFESTATION_TEST: PASS profile=%s" % _profile_name())
	else:
		print(
			"RIDERS_MANIFESTATION_TEST: FAIL profile=%s failures=%d"
			% [_profile_name(), _failures.size()]
		)
		for failure in _failures:
			print(" - %s" % failure)
	if barrage != null:
		barrage.queue_free()
		await process_frame
		await process_frame
	quit(exit_code)
