class_name RidersManifestation
extends Node3D

## Runtime-built, one-shot manifestation for the two static riders. The source
## scenes are preloaded and instantiated in _init(), so manifest() performs no
## resource loading and only reveals already-resident geometry.

signal manifestation_finished

const WHITE_RIDER_SCENE: PackedScene = preload(
	"res://assets/film/two_white_horses/riders/white_rider_source.glb"
)
const BLACK_RIDER_SCENE: PackedScene = preload(
	"res://assets/film/two_white_horses/riders/black_rider_source.glb"
)
const MANIFESTATION_SHADER: Shader = preload(
	"res://addons/film_revelation/riders_manifestation.gdshader"
)

const DEFAULT_DURATION_S := 1.45
const RIDER_LATERAL_OFFSET_M := 2.2
const BLACK_RIDER_DEPTH_OFFSET_M := 0.7
const WHITE_RIDER_SOURCE_SCALE := 2.38098
const BLACK_RIDER_SOURCE_SCALE := 2.36681
const GROUND_RAY_ORIGIN_HEIGHT_M := 10.0
const GROUND_RAY_LENGTH_M := 30.0
const SILHOUETTE_HOLD_S := 0.10
const BLACK_RIDER_DELAY_S := 0.14
const DEFAULT_COLD_RENDER_LAYER := 1 << 19
const WHITE_RIDER_LIGHT_LAYER := 1 << 18
const BLACK_RIDER_LIGHT_LAYER := 1 << 17

@export var ground_collision_mask: int = 1
@export var cold_rim_render_layer: int = DEFAULT_COLD_RENDER_LAYER
@export var cold_rim_energy: float = 0.30
@export var cold_rim_range_m: float = 8.0

@export_group("Rider light layers")
@export var white_rider_light_layer: int = WHITE_RIDER_LIGHT_LAYER
@export var black_rider_light_layer: int = BLACK_RIDER_LIGHT_LAYER

@export_group("White rider eyes")
@export var rider_face_anchor_normalized := Vector3(0.50, 0.90, 0.96)
@export_range(0.005, 0.08, 0.001) var white_eye_local_x_offset_m := 0.025
@export_range(0.005, 0.05, 0.001) var white_eye_radius_m := 0.018
@export_range(0.005, 0.08, 0.001) var white_eye_height_m := 0.032
@export var white_eye_color := Color(0.24, 0.58, 1.0)
@export_range(0.0, 8.0, 0.05) var white_eye_emission_energy := 3.0
@export_range(0.0, 1.0, 0.01) var white_eye_reveal_start := 0.58

@export_group("White rider face and key")
@export_range(0.0, 2.0, 0.01) var white_face_bounce_energy := 0.16
@export_range(0.1, 4.0, 0.05) var white_face_bounce_range_m := 0.85
@export_range(0.1, 8.0, 0.1) var white_face_bounce_attenuation := 2.4
@export_range(0.0, 3.0, 0.01) var white_cold_key_energy := 0.55
@export_range(0.5, 15.0, 0.1) var white_cold_key_range_m := 6.0
@export_range(1.0, 90.0, 0.5) var white_cold_key_angle_deg := 38.0
@export_range(0.1, 8.0, 0.1) var white_cold_key_attenuation := 1.7
@export var white_cold_key_offset_m := Vector3(-0.65, 0.80, 1.35)

@export_group("Black rider face and rim")
@export var black_face_light_color := Color(1.0, 0.035, 0.012)
@export_range(0.0, 3.0, 0.01) var black_face_light_energy := 0.65
@export_range(0.5, 8.0, 0.1) var black_face_light_range_m := 2.2
@export_range(1.0, 90.0, 0.5) var black_face_light_angle_deg := 27.0
@export_range(0.1, 8.0, 0.1) var black_face_light_attenuation := 2.2
@export var black_face_light_offset_m := Vector3(0.0, -0.12, 0.25)
@export_range(0.0, 1.0, 0.01) var black_face_reveal_start := 0.72
@export var black_cold_rim_color := Color(0.20, 0.29, 0.48)
@export_range(0.0, 3.0, 0.01) var black_cold_rim_energy := 0.30
@export_range(0.5, 15.0, 0.1) var black_cold_rim_range_m := 5.5
@export_range(1.0, 90.0, 0.5) var black_cold_rim_angle_deg := 44.0
@export_range(0.1, 8.0, 0.1) var black_cold_rim_attenuation := 1.6
@export var black_cold_rim_offset_m := Vector3(0.75, 0.72, -1.10)

var riders_manifested: bool = false

var riders_center: Marker3D
var white_rider_point: Marker3D
var black_rider_point: Marker3D
var white_rider: Node3D
var black_rider: Node3D

var _white_ground_ray: RayCast3D
var _black_ground_ray: RayCast3D
var _cold_rim_light: OmniLight3D
var _white_rider_lighting: Node3D
var _white_eye_glow_root: Node3D
var _left_eye_core: MeshInstance3D
var _right_eye_core: MeshInstance3D
var _white_eye_material: StandardMaterial3D
var _white_eye_face_bounce: OmniLight3D
var _white_rider_cold_key: SpotLight3D
var _black_rider_lighting: Node3D
var _black_rider_red_face_light: SpotLight3D
var _black_rider_cold_rim: SpotLight3D
var _lighting_tween: Tween
var _camera: Camera3D
var _player: Node3D
var _terrain: Node
var _center_world := Vector3.ZERO
var _setup_requested := false
var _manifesting := false
var _manifest_started_usec: int = 0
var _manifest_duration_s := DEFAULT_DURATION_S
var _transition_records: Array[Dictionary] = []
var _transition_materials: Array[ShaderMaterial] = []
var _white_transition_materials: Array[ShaderMaterial] = []
var _black_transition_materials: Array[ShaderMaterial] = []
var _transition_materials_ready := false
var _white_rider_base_transform := Transform3D.IDENTITY
var _black_rider_base_transform := Transform3D.IDENTITY
var _white_texture: Texture2D
var _flat_normal_texture: Texture2D


func _init() -> void:
	_build_runtime_tree()
	set_process(false)


func _ready() -> void:
	_prepare_transition_materials()
	if _setup_requested:
		_apply_setup()
	_set_riders_visible(false)
	set_process(false)


func _exit_tree() -> void:
	_manifesting = false
	set_process(false)
	if _lighting_tween != null and _lighting_tween.is_valid():
		_lighting_tween.kill()
	_restore_source_materials()


func _process(_delta: float) -> void:
	if not _manifesting:
		set_process(false)
		return
	var elapsed_s := float(Time.get_ticks_usec() - _manifest_started_usec) / 1000000.0
	var linear_progress := clampf(elapsed_s / maxf(_manifest_duration_s, 0.001), 0.0, 1.0)
	_update_manifestation_materials(elapsed_s)
	if linear_progress >= 1.0:
		_finish_manifestation(true)


## Places the pair around center_world. The white rider is 2.2 m to the
## player's screen-left; the black rider is 2.2 m to screen-right and 0.7 m
## farther from the player. setup() may be called before or after add_child().
func setup(
	center_world: Vector3,
	camera_node: Camera3D = null,
	player_node: Node3D = null,
	terrain_node: Node = null
) -> void:
	_center_world = center_world
	_camera = camera_node
	_player = player_node
	_terrain = terrain_node
	_setup_requested = true
	if is_inside_tree():
		_apply_setup()


## Starts the one-shot bottom-up reveal. All models, textures, and transition
## materials have already been created; this method performs no resource load.
func manifest(duration_s: float = DEFAULT_DURATION_S) -> bool:
	if riders_manifested or _manifesting:
		return false
	if duration_s <= 0.0:
		show_immediate()
		return true
	if _setup_requested and is_inside_tree():
		_apply_setup()
	_prepare_transition_materials()
	_apply_transition_materials()
	_update_transition_world_bounds()
	_set_riders_visible(true)
	_cold_rim_light.visible = true
	_begin_cinematic_lighting_reveal(duration_s)
	_manifest_duration_s = maxf(
		duration_s,
		BLACK_RIDER_DELAY_S + SILHOUETTE_HOLD_S + 0.001
	)
	_manifest_started_usec = Time.get_ticks_usec()
	_manifesting = true
	_update_manifestation_materials(0.0)
	set_process(true)
	return true


## Makes both riders visible in their original imported PBR materials without
## running the dissolve. Repeated calls are intentionally idempotent.
func show_immediate() -> void:
	if riders_manifested:
		return
	if _setup_requested and is_inside_tree():
		_apply_setup()
	_manifesting = false
	set_process(false)
	_restore_source_materials()
	_set_riders_visible(true)
	_cold_rim_light.visible = true
	_set_cinematic_lighting_visible(true)
	_set_cinematic_lighting_immediate()
	riders_manifested = true
	manifestation_finished.emit()


func _build_runtime_tree() -> void:
	riders_center = Marker3D.new()
	riders_center.name = "RidersCenter"
	add_child(riders_center)

	white_rider_point = Marker3D.new()
	white_rider_point.name = "WhiteRiderPoint"
	add_child(white_rider_point)
	black_rider_point = Marker3D.new()
	black_rider_point.name = "BlackRiderPoint"
	add_child(black_rider_point)

	_white_ground_ray = _create_ground_ray("WhiteGroundRay")
	white_rider_point.add_child(_white_ground_ray)
	_black_ground_ray = _create_ground_ray("BlackGroundRay")
	black_rider_point.add_child(_black_ground_ray)

	white_rider = WHITE_RIDER_SCENE.instantiate() as Node3D
	if white_rider == null:
		push_error("RidersManifestation: white rider scene root must be Node3D")
		white_rider = Node3D.new()
	white_rider.name = "WhiteRider"
	add_child(white_rider)
	black_rider = BLACK_RIDER_SCENE.instantiate() as Node3D
	if black_rider == null:
		push_error("RidersManifestation: black rider scene root must be Node3D")
		black_rider = Node3D.new()
	black_rider.name = "BlackRider"
	add_child(black_rider)
	# Both source scenes are authored at roughly 1.89 m high. Match their final
	# spectral silhouette height while keeping the imported proportions intact.
	white_rider.scale = Vector3.ONE * WHITE_RIDER_SOURCE_SCALE
	black_rider.scale = Vector3.ONE * BLACK_RIDER_SOURCE_SCALE

	_white_rider_base_transform = white_rider.transform
	_black_rider_base_transform = black_rider.transform
	_prepare_static_model(white_rider, white_rider_light_layer)
	_prepare_static_model(black_rider, black_rider_light_layer)

	_cold_rim_light = OmniLight3D.new()
	_cold_rim_light.name = "ColdRimLight"
	_cold_rim_light.light_color = Color(0.38, 0.60, 0.90)
	_cold_rim_light.light_energy = cold_rim_energy
	_cold_rim_light.omni_range = cold_rim_range_m
	_cold_rim_light.shadow_enabled = false
	_cold_rim_light.light_cull_mask = cold_rim_render_layer
	_cold_rim_light.light_volumetric_fog_energy = 0.0
	# Behind and moon-side of the +Z-facing riders: a rim, never a front fill.
	_cold_rim_light.position = Vector3(-2.2, 3.0, -2.6)
	_cold_rim_light.visible = false
	riders_center.add_child(_cold_rim_light)
	_build_cinematic_lighting()


func _create_ground_ray(node_name: StringName) -> RayCast3D:
	var ray := RayCast3D.new()
	ray.name = node_name
	ray.position = Vector3(0.0, GROUND_RAY_ORIGIN_HEIGHT_M, 0.0)
	ray.target_position = Vector3(0.0, -GROUND_RAY_LENGTH_M, 0.0)
	ray.collision_mask = ground_collision_mask
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.hit_from_inside = true
	ray.enabled = false
	return ray


func _prepare_static_model(model_root: Node3D, rider_light_layer: int) -> void:
	model_root.visible = false
	model_root.process_mode = Node.PROCESS_MODE_DISABLED
	for descendant in model_root.find_children("*", "", true, false):
		descendant.process_mode = Node.PROCESS_MODE_DISABLED
		if descendant is CollisionObject3D:
			var collider := descendant as CollisionObject3D
			collider.collision_layer = 0
			collider.collision_mask = 0
			collider.input_ray_pickable = false
		if descendant is CollisionShape3D:
			(descendant as CollisionShape3D).disabled = true
		elif descendant is CollisionPolygon3D:
			(descendant as CollisionPolygon3D).disabled = true
		elif descendant is AnimationPlayer:
			(descendant as AnimationPlayer).stop()
		elif descendant is AnimationTree:
			(descendant as AnimationTree).active = false
		elif descendant is RigidBody3D:
			(descendant as RigidBody3D).freeze = true
		if descendant is MeshInstance3D:
			var mesh_instance := descendant as MeshInstance3D
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.layers |= cold_rim_render_layer | rider_light_layer


func _build_cinematic_lighting() -> void:
	_white_rider_lighting = Node3D.new()
	_white_rider_lighting.name = "WhiteRiderLighting"
	riders_center.add_child(_white_rider_lighting)
	_white_eye_glow_root = Node3D.new()
	_white_eye_glow_root.name = "WhiteEyeGlowRoot"
	_white_rider_lighting.add_child(_white_eye_glow_root)

	_white_eye_material = StandardMaterial3D.new()
	_white_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_white_eye_material.albedo_color = white_eye_color
	_white_eye_material.emission_enabled = true
	_white_eye_material.emission = white_eye_color
	_white_eye_material.emission_energy_multiplier = 0.0
	_left_eye_core = _create_eye_core("LeftEyeCore")
	_right_eye_core = _create_eye_core("RightEyeCore")
	_white_eye_glow_root.add_child(_left_eye_core)
	_white_eye_glow_root.add_child(_right_eye_core)

	_white_eye_face_bounce = OmniLight3D.new()
	_white_eye_face_bounce.name = "WhiteEyeFaceBounce"
	_white_eye_face_bounce.light_color = white_eye_color
	_white_eye_face_bounce.light_energy = 0.0
	_white_eye_face_bounce.omni_range = white_face_bounce_range_m
	_white_eye_face_bounce.omni_attenuation = white_face_bounce_attenuation
	_configure_rider_light(_white_eye_face_bounce, white_rider_light_layer)
	_white_rider_lighting.add_child(_white_eye_face_bounce)

	_white_rider_cold_key = SpotLight3D.new()
	_white_rider_cold_key.name = "WhiteRiderColdKey"
	_white_rider_cold_key.light_color = Color(0.48, 0.67, 0.96)
	_white_rider_cold_key.light_energy = 0.0
	_white_rider_cold_key.spot_range = white_cold_key_range_m
	_white_rider_cold_key.spot_angle = white_cold_key_angle_deg
	_white_rider_cold_key.spot_angle_attenuation = white_cold_key_attenuation
	_configure_rider_light(_white_rider_cold_key, white_rider_light_layer)
	_white_rider_lighting.add_child(_white_rider_cold_key)

	_black_rider_lighting = Node3D.new()
	_black_rider_lighting.name = "BlackRiderLighting"
	riders_center.add_child(_black_rider_lighting)
	_black_rider_red_face_light = SpotLight3D.new()
	_black_rider_red_face_light.name = "BlackRiderRedFaceLight"
	_black_rider_red_face_light.light_color = black_face_light_color
	_black_rider_red_face_light.light_energy = 0.0
	_black_rider_red_face_light.spot_range = black_face_light_range_m
	_black_rider_red_face_light.spot_angle = black_face_light_angle_deg
	_black_rider_red_face_light.spot_angle_attenuation = black_face_light_attenuation
	_configure_rider_light(_black_rider_red_face_light, black_rider_light_layer)
	_black_rider_lighting.add_child(_black_rider_red_face_light)

	_black_rider_cold_rim = SpotLight3D.new()
	_black_rider_cold_rim.name = "BlackRiderColdRim"
	_black_rider_cold_rim.light_color = black_cold_rim_color
	_black_rider_cold_rim.light_energy = 0.0
	_black_rider_cold_rim.spot_range = black_cold_rim_range_m
	_black_rider_cold_rim.spot_angle = black_cold_rim_angle_deg
	_black_rider_cold_rim.spot_angle_attenuation = black_cold_rim_attenuation
	_configure_rider_light(_black_rider_cold_rim, black_rider_light_layer)
	_black_rider_lighting.add_child(_black_rider_cold_rim)
	_set_cinematic_lighting_visible(false)


func _create_eye_core(node_name: StringName) -> MeshInstance3D:
	var eye := MeshInstance3D.new()
	eye.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = white_eye_radius_m
	sphere.height = white_eye_height_m
	sphere.radial_segments = 12
	sphere.rings = 6
	eye.mesh = sphere
	eye.material_override = _white_eye_material
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eye.layers = white_rider_light_layer
	return eye


func _configure_rider_light(light: Light3D, cull_mask: int) -> void:
	light.shadow_enabled = false
	light.light_cull_mask = cull_mask
	light.light_volumetric_fog_energy = 0.0


func _apply_setup() -> void:
	if not is_inside_tree():
		return
	var anchor_position := _center_world + Vector3(0.0, 0.0, 1.0)
	if is_instance_valid(_player):
		anchor_position = _player.global_position
	elif is_instance_valid(_camera):
		anchor_position = _camera.global_position

	var away_from_player := _center_world - anchor_position
	away_from_player.y = 0.0
	if away_from_player.length_squared() < 0.0001:
		away_from_player = Vector3.FORWARD
	away_from_player = away_from_player.normalized()
	var toward_player := -away_from_player
	var screen_right := away_from_player.cross(Vector3.UP).normalized()
	# The imported riders use +Z as their model front (the equivalent of
	# look_at(anchor_position, Vector3.UP, true)).
	var center_basis := Basis(screen_right, Vector3.UP, toward_player).orthonormalized()
	var center_transform := Transform3D(center_basis, _center_world)
	riders_center.global_transform = center_transform
	white_rider_point.global_transform = center_transform * Transform3D(
		Basis.IDENTITY, Vector3(-RIDER_LATERAL_OFFSET_M, 0.0, 0.0)
	)
	black_rider_point.global_transform = center_transform * Transform3D(
		Basis.IDENTITY,
		Vector3(RIDER_LATERAL_OFFSET_M, 0.0, -BLACK_RIDER_DEPTH_OFFSET_M)
	)
	_cold_rim_light.position = Vector3(-2.2, 3.0, -2.6)
	_cold_rim_light.light_energy = cold_rim_energy
	_cold_rim_light.omni_range = cold_rim_range_m
	_cold_rim_light.light_cull_mask = cold_rim_render_layer
	_ground_pair()
	_position_cinematic_lighting()
	_update_transition_world_bounds()


func _ground_pair() -> void:
	white_rider.global_transform = white_rider_point.global_transform * _white_rider_base_transform
	black_rider.global_transform = black_rider_point.global_transform * _black_rider_base_transform
	_ground_point(white_rider_point, white_rider, _white_ground_ray)
	_ground_point(black_rider_point, black_rider, _black_ground_ray)


func _ground_point(point: Node3D, model: Node3D, ray: RayCast3D) -> void:
	ray.collision_mask = ground_collision_mask
	ray.enabled = true
	ray.force_raycast_update()
	var point_world := point.global_position
	var ground_y := _center_world.y
	if ray.is_colliding():
		ground_y = ray.get_collision_point().y
	elif is_instance_valid(_terrain) and _terrain.has_method("height_at_world"):
		var sampled_height: Variant = _terrain.call(
			"height_at_world", point_world.x, point_world.z
		)
		if sampled_height is float or sampled_height is int:
			ground_y = float(sampled_height)
	point_world.y = ground_y
	point.global_position = point_world
	ray.enabled = false

	var base_transform := (
		_white_rider_base_transform if model == white_rider else _black_rider_base_transform
	)
	model.global_transform = point.global_transform * base_transform
	var bounds := _visual_bounds_in_space(model, point)
	if bounds.size != Vector3.ZERO:
		model.global_position += Vector3.UP * -bounds.position.y


func _position_cinematic_lighting() -> void:
	if not is_inside_tree():
		return
	var white_face_local := _normalized_point_in_bounds(
		white_rider, rider_face_anchor_normalized
	)
	var black_face_local := _normalized_point_in_bounds(
		black_rider, rider_face_anchor_normalized
	)
	var left_eye_world := white_rider.to_global(
		white_face_local + Vector3(-white_eye_local_x_offset_m, 0.0, 0.0)
	)
	var right_eye_world := white_rider.to_global(
		white_face_local + Vector3(white_eye_local_x_offset_m, 0.0, 0.0)
	)
	var white_face_world := white_rider.to_global(white_face_local)
	var black_face_world := black_rider.to_global(black_face_local)
	var white_basis := white_rider.global_basis.orthonormalized()
	var black_basis := black_rider.global_basis.orthonormalized()
	var white_right := white_basis.x.normalized()
	var white_up := white_basis.y.normalized()
	var white_front := white_basis.z.normalized()
	var black_right := black_basis.x.normalized()
	var black_up := black_basis.y.normalized()
	var black_front := black_basis.z.normalized()

	_left_eye_core.global_position = left_eye_world
	_left_eye_core.global_basis = white_basis
	_right_eye_core.global_position = right_eye_world
	_right_eye_core.global_basis = white_basis
	_white_eye_face_bounce.global_position = white_face_world + white_front * 0.10

	_white_rider_cold_key.global_position = (
		white_face_world
		+ white_right * white_cold_key_offset_m.x
		+ white_up * white_cold_key_offset_m.y
		+ white_front * white_cold_key_offset_m.z
	)
	_aim_light_at(_white_rider_cold_key, white_face_world)

	_black_rider_red_face_light.global_position = (
		black_face_world
		+ black_right * black_face_light_offset_m.x
		+ black_up * black_face_light_offset_m.y
		+ black_front * black_face_light_offset_m.z
	)
	_aim_light_at(_black_rider_red_face_light, black_face_world)

	_black_rider_cold_rim.global_position = (
		black_face_world
		+ black_right * black_cold_rim_offset_m.x
		+ black_up * black_cold_rim_offset_m.y
		+ black_front * black_cold_rim_offset_m.z
	)
	_aim_light_at(_black_rider_cold_rim, black_face_world + black_up * 0.10)


func _normalized_point_in_bounds(model: Node3D, normalized_point: Vector3) -> Vector3:
	var bounds := _visual_bounds_in_space(model, model)
	if bounds.size == Vector3.ZERO:
		return Vector3.ZERO
	var safe_point := normalized_point.clamp(Vector3.ZERO, Vector3.ONE)
	return bounds.position + bounds.size * safe_point


func _aim_light_at(light: Node3D, target_world: Vector3) -> void:
	var direction := target_world - light.global_position
	if direction.length_squared() < 0.000001:
		return
	var up := Vector3.UP
	if absf(direction.normalized().dot(up)) > 0.98:
		up = Vector3.FORWARD
	light.look_at(target_world, up)


func _begin_cinematic_lighting_reveal(duration_s: float) -> void:
	if _lighting_tween != null and _lighting_tween.is_valid():
		_lighting_tween.kill()
	_set_cinematic_lighting_visible(true)
	_set_white_eye_amount(0.0)
	_set_black_face_amount(0.0)
	_set_key_light_amount(0.0)
	var safe_duration := maxf(duration_s, 0.001)
	var white_delay := safe_duration * clampf(white_eye_reveal_start, 0.0, 0.99)
	var black_delay := safe_duration * clampf(black_face_reveal_start, 0.0, 0.99)
	var key_delay := safe_duration * 0.42
	_lighting_tween = create_tween().set_parallel(true)
	_lighting_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lighting_tween.tween_method(
		Callable(self, "_set_white_eye_amount"), 0.0, 1.0,
		maxf(safe_duration - white_delay, 0.001)
	).set_delay(white_delay)
	_lighting_tween.tween_method(
		Callable(self, "_set_black_face_amount"), 0.0, 1.0,
		maxf(safe_duration - black_delay, 0.001)
	).set_delay(black_delay)
	_lighting_tween.tween_method(
		Callable(self, "_set_key_light_amount"), 0.0, 1.0,
		maxf(safe_duration - key_delay, 0.001)
	).set_delay(key_delay)


func _set_cinematic_lighting_immediate() -> void:
	if _lighting_tween != null and _lighting_tween.is_valid():
		_lighting_tween.kill()
	_set_white_eye_amount(1.0)
	_set_black_face_amount(1.0)
	_set_key_light_amount(1.0)


func _set_white_eye_amount(amount: float) -> void:
	var safe_amount := clampf(amount, 0.0, 1.0)
	_white_eye_material.emission_energy_multiplier = white_eye_emission_energy * safe_amount
	_white_eye_glow_root.visible = safe_amount > 0.001
	_white_eye_face_bounce.light_energy = white_face_bounce_energy * safe_amount


func _set_black_face_amount(amount: float) -> void:
	_black_rider_red_face_light.light_energy = (
		black_face_light_energy * clampf(amount, 0.0, 1.0)
	)


func _set_key_light_amount(amount: float) -> void:
	var safe_amount := clampf(amount, 0.0, 1.0)
	_white_rider_cold_key.light_energy = white_cold_key_energy * safe_amount
	_black_rider_cold_rim.light_energy = black_cold_rim_energy * safe_amount


func _set_cinematic_lighting_visible(visible_state: bool) -> void:
	_white_rider_lighting.visible = visible_state
	_black_rider_lighting.visible = visible_state
	if not visible_state:
		_white_eye_glow_root.visible = false


func _prepare_transition_materials() -> void:
	if _transition_materials_ready:
		return
	_transition_materials_ready = true
	_ensure_fallback_textures()
	_prepare_model_transition_materials(
		white_rider, Color(0.72, 0.75, 0.80), _white_transition_materials
	)
	_prepare_model_transition_materials(
		black_rider, Color(0.025, 0.030, 0.040), _black_transition_materials
	)


func _prepare_model_transition_materials(
	model: Node3D,
	fallback_color: Color,
	rider_materials: Array[ShaderMaterial]
) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.layers |= cold_rim_render_layer
		var surface_count := mesh_instance.mesh.get_surface_count()
		if surface_count <= 0:
			continue
		if mesh_instance.material_override != null:
			var whole_transition := _create_transition_material(
				mesh_instance.material_override, fallback_color
			)
			_transition_records.append({
				"mesh": mesh_instance,
				"surface": -1,
				"original": mesh_instance.material_override,
				"transition": whole_transition,
			})
			_transition_materials.append(whole_transition)
			rider_materials.append(whole_transition)
			continue
		for surface_index in range(surface_count):
			var original_override := mesh_instance.get_surface_override_material(surface_index)
			var source_material := mesh_instance.get_active_material(surface_index)
			var transition := _create_transition_material(source_material, fallback_color)
			_transition_records.append({
				"mesh": mesh_instance,
				"surface": surface_index,
				"original": original_override,
				"transition": transition,
			})
			_transition_materials.append(transition)
			rider_materials.append(transition)


func _create_transition_material(source: Material, fallback_color: Color) -> ShaderMaterial:
	var transition := ShaderMaterial.new()
	transition.shader = MANIFESTATION_SHADER
	transition.render_priority = 1
	transition.set_shader_parameter("base_color", fallback_color)
	transition.set_shader_parameter("base_texture", _white_texture)
	transition.set_shader_parameter("metallic_texture", _white_texture)
	transition.set_shader_parameter("roughness_texture", _white_texture)
	transition.set_shader_parameter("normal_texture", _flat_normal_texture)
	transition.set_shader_parameter("emission_texture", _white_texture)
	if source is BaseMaterial3D:
		var pbr := source as BaseMaterial3D
		transition.set_shader_parameter("base_color", pbr.albedo_color)
		transition.set_shader_parameter("use_base_texture", pbr.albedo_texture != null)
		if pbr.albedo_texture != null:
			transition.set_shader_parameter("base_texture", pbr.albedo_texture)
		transition.set_shader_parameter("metallic", pbr.metallic)
		transition.set_shader_parameter("roughness", pbr.roughness)
		transition.set_shader_parameter("specular", pbr.metallic_specular)
		transition.set_shader_parameter("use_metallic_texture", pbr.metallic_texture != null)
		if pbr.metallic_texture != null:
			transition.set_shader_parameter("metallic_texture", pbr.metallic_texture)
		transition.set_shader_parameter(
			"metallic_channel", _texture_channel_mask(pbr.metallic_texture_channel)
		)
		transition.set_shader_parameter("use_roughness_texture", pbr.roughness_texture != null)
		if pbr.roughness_texture != null:
			transition.set_shader_parameter("roughness_texture", pbr.roughness_texture)
		transition.set_shader_parameter(
			"roughness_channel", _texture_channel_mask(pbr.roughness_texture_channel)
		)
		transition.set_shader_parameter(
			"use_normal_texture", pbr.normal_enabled and pbr.normal_texture != null
		)
		if pbr.normal_texture != null:
			transition.set_shader_parameter("normal_texture", pbr.normal_texture)
		transition.set_shader_parameter("normal_scale", pbr.normal_scale)
		var source_emission := Color.BLACK
		if pbr.emission_enabled:
			source_emission = pbr.emission * pbr.emission_energy_multiplier
		transition.set_shader_parameter("source_emission", Vector3(
			source_emission.r, source_emission.g, source_emission.b
		))
		transition.set_shader_parameter(
			"use_emission_texture", pbr.emission_enabled and pbr.emission_texture != null
		)
		if pbr.emission_texture != null:
			transition.set_shader_parameter("emission_texture", pbr.emission_texture)
		transition.set_shader_parameter("uv_scale", Vector2(pbr.uv1_scale.x, pbr.uv1_scale.y))
		transition.set_shader_parameter("uv_offset", Vector2(pbr.uv1_offset.x, pbr.uv1_offset.y))
	return transition


func _texture_channel_mask(channel: int) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0.0, 1.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0.0, 0.0, 1.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0.0, 0.0, 0.0, 1.0)
		_:
			return Vector4(1.0, 0.0, 0.0, 0.0)


func _ensure_fallback_textures() -> void:
	if _white_texture == null:
		var white_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		white_image.fill(Color.WHITE)
		_white_texture = ImageTexture.create_from_image(white_image)
	if _flat_normal_texture == null:
		var normal_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		normal_image.fill(Color(0.5, 0.5, 1.0, 1.0))
		_flat_normal_texture = ImageTexture.create_from_image(normal_image)


func _apply_transition_materials() -> void:
	for record in _transition_records:
		var mesh_instance := record["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		var surface_index := int(record["surface"])
		if surface_index < 0:
			mesh_instance.material_override = record["transition"] as Material
		else:
			mesh_instance.set_surface_override_material(
				surface_index, record["transition"] as Material
			)


func _restore_source_materials() -> void:
	for record in _transition_records:
		var mesh_instance := record["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		var surface_index := int(record["surface"])
		if surface_index < 0:
			mesh_instance.material_override = record["original"] as Material
		else:
			mesh_instance.set_surface_override_material(
				surface_index, record["original"] as Material
			)


func _update_manifestation_materials(elapsed_s: float) -> void:
	_update_rider_materials(_white_transition_materials, elapsed_s, 0.0)
	_update_rider_materials(
		_black_transition_materials, elapsed_s, BLACK_RIDER_DELAY_S
	)


func _update_rider_materials(
	materials: Array[ShaderMaterial],
	elapsed_s: float,
	start_delay_s: float
) -> void:
	var local_elapsed_s := elapsed_s - start_delay_s
	var phase := 0.0
	var reveal_progress := 0.0
	if local_elapsed_s >= 0.0 and local_elapsed_s < SILHOUETTE_HOLD_S:
		phase = 1.0
	elif local_elapsed_s >= SILHOUETTE_HOLD_S:
		phase = 2.0
		var fill_duration_s := maxf(
			_manifest_duration_s - start_delay_s - SILHOUETTE_HOLD_S,
			0.001
		)
		var linear_fill := clampf(
			(local_elapsed_s - SILHOUETTE_HOLD_S) / fill_duration_s,
			0.0,
			1.0
		)
		reveal_progress = smoothstep(0.0, 1.0, linear_fill)
	for material in materials:
		material.set_shader_parameter("manifestation_phase", phase)
		material.set_shader_parameter("reveal_progress", reveal_progress)


func _update_transition_world_bounds() -> void:
	if not is_inside_tree() or not _transition_materials_ready:
		return
	_set_material_world_bounds(
		_white_transition_materials,
		_visual_bounds_in_space(white_rider, null)
	)
	_set_material_world_bounds(
		_black_transition_materials,
		_visual_bounds_in_space(black_rider, null)
	)


func _set_material_world_bounds(
	materials: Array[ShaderMaterial],
	bounds: AABB
) -> void:
	if bounds.size == Vector3.ZERO:
		return
	for material in materials:
		material.set_shader_parameter("world_bottom_y", bounds.position.y)
		material.set_shader_parameter("world_top_y", bounds.end.y)


func _visual_bounds_in_space(model: Node3D, space: Node3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found_visual := false
	var space_inverse := Transform3D.IDENTITY
	if is_instance_valid(space):
		space_inverse = space.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var into_space := mesh_instance.global_transform
		if is_instance_valid(space):
			into_space = space_inverse * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := mesh_bounds.position + Vector3(
				mesh_bounds.size.x if (corner_index & 1) != 0 else 0.0,
				mesh_bounds.size.y if (corner_index & 2) != 0 else 0.0,
				mesh_bounds.size.z if (corner_index & 4) != 0 else 0.0
			)
			var transformed := into_space * corner
			minimum = minimum.min(transformed)
			maximum = maximum.max(transformed)
			found_visual = true
	if not found_visual:
		return AABB()
	return AABB(minimum, maximum - minimum)


func _set_riders_visible(visible_state: bool) -> void:
	white_rider.visible = visible_state
	black_rider.visible = visible_state
	if not visible_state:
		_set_cinematic_lighting_visible(false)


func _finish_manifestation(emit_finished: bool) -> void:
	_manifesting = false
	set_process(false)
	_restore_source_materials()
	_set_riders_visible(true)
	_cold_rim_light.visible = true
	_set_cinematic_lighting_visible(true)
	_set_cinematic_lighting_immediate()
	riders_manifested = true
	if emit_finished:
		manifestation_finished.emit()
