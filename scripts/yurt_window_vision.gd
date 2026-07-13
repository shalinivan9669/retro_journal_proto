extends Node3D

@export var player_path: NodePath = NodePath("../Player")
@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var yurt_world_path: NodePath = NodePath("../CleanYurt/world")
@export var window_wall_path: NodePath = NodePath("../CleanYurt/world/YurtWall_06")
@export var hold_seconds: float = 2.0
@export var flower_fade_seconds: float = 2.5
@export var step_scene_seconds: float = 11.0
@export var fade_out_seconds: float = 3.0
@export var window_position: Vector3 = Vector3(8.9, 2.65, 0.8)
@export var trigger_position: Vector3 = Vector3(6.9, 1.1, 0.8)
@export var trigger_size: Vector3 = Vector3(3.2, 2.4, 3.2)

const WALL_ALBEDO_TEXTURE: Texture2D = preload("res://assets/textures/yurt/yurt_interior_weathered_felt_v2.png")
const BLUE_LEGS_SCENE: PackedScene = preload("res://assets/models/blue_legs/blue_legs_rigged_animated.glb")
const BLUE_LEGS_ANIMATION := &"stomp_alternating_loop"
const BLUE_LEGS_SOURCE_ANIMATION := &"stomp_alternating"
const BLUE_LEGS_POSITION := Vector3(22.0, 0.02, 0.0)
const BLUE_LEGS_SCALE := 9.48436
const FLOWER_COUNT := 180
const WINDOW_RADIUS := 1.32
const SAMPLE_RATE := 22050
const PLAYER_TRIGGER_RADIUS := 3.0
const WALL_CUTOUT_SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 wall_color : source_color = vec4(0.68, 0.64, 0.56, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 hole_center = vec3(8.9, 2.65, 0.8);
uniform float hole_radius = 1.32;
uniform float hole_x_half_width = 0.9;
uniform vec2 uv_scale = vec2(3.1, 1.65);
uniform float texture_strength = 1.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float same_wall_band = step(abs(world_position.x - hole_center.x), hole_x_half_width);
	float inside_round_hole = 1.0 - step(hole_radius, distance(world_position.yz, hole_center.yz));
	if (same_wall_band * inside_round_hole > 0.5) {
		discard;
	}
	vec2 tiled_uv = UV * uv_scale;
	vec3 fabric = texture(albedo_texture, tiled_uv).rgb;
	ALBEDO = mix(wall_color.rgb, fabric * wall_color.rgb * 1.05, texture_strength);
	ROUGHNESS = 0.96;
}
"""

var _player: Node3D
var _trigger_area: Area3D
var _inside_trigger := false
var _hold_timer := 0.0
var _vision_started := false
var _vision_time := 0.0
var _vision_root: Node3D
var _fade_materials: Array[StandardMaterial3D] = []
var _blue_legs: Node3D
var _blue_legs_animation_player: AnimationPlayer
var _step_timer := 0.0
var _next_left_step := true
var _rng := RandomNumberGenerator.new()
var _rumble_player: AudioStreamPlayer3D
var _rumble_playback: AudioStreamGeneratorPlayback
var _environment: Environment
var _old_fog_enabled := false
var _old_fog_density := 0.0
var _old_fog_color := Color.WHITE
var _window_light: OmniLight3D


func _ready() -> void:
	_rng.seed = 17831
	_player = get_node_or_null(player_path) as Node3D
	_apply_round_window_cutout()
	_build_round_window()
	_build_hold_trigger()
	_build_window_light()


func _exit_tree() -> void:
	if _rumble_player != null:
		_rumble_player.stop()
	_rumble_playback = null
	_restore_environment()


func _process(delta: float) -> void:
	if _vision_started:
		_update_vision(delta)
		return

	if _inside_trigger or _is_player_near_window():
		_hold_timer += delta
		if _hold_timer >= hold_seconds:
			_start_vision()
	else:
		_hold_timer = 0.0


func _apply_round_window_cutout() -> void:
	var mesh_instance := get_node_or_null(window_wall_path) as MeshInstance3D
	if mesh_instance == null:
		push_warning("YurtWindowVision: configured window wall is missing: %s" % window_wall_path)
		return

	var shader := Shader.new()
	shader.code = WALL_CUTOUT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("hole_center", window_position)
	material.set_shader_parameter("hole_radius", WINDOW_RADIUS)
	material.set_shader_parameter("hole_x_half_width", 0.9)
	material.set_shader_parameter("wall_color", Color(0.68, 0.64, 0.56, 1.0))
	material.set_shader_parameter("albedo_texture", WALL_ALBEDO_TEXTURE)
	material.set_shader_parameter("uv_scale", Vector2(1.6, 1.45))
	material.set_shader_parameter("texture_strength", 1.0)
	mesh_instance.visible = true
	mesh_instance.set_surface_override_material(0, material)


func _build_round_window() -> void:
	var frame := Node3D.new()
	frame.name = "RoundWindowHole"
	add_child(frame)
	frame.global_position = window_position

	var rim_material := _make_material(Color(0.32, 0.18, 0.09, 1.0), false)
	for i in range(28):
		var angle := TAU * float(i) / 28.0
		var block := MeshInstance3D.new()
		block.name = "WindowRim_%02d" % i
		var block_mesh := BoxMesh.new()
		block_mesh.size = Vector3(0.18, 0.16, 0.42)
		block.mesh = block_mesh
		block.position = Vector3(-0.02, sin(angle) * (WINDOW_RADIUS + 0.14), cos(angle) * (WINDOW_RADIUS + 0.14))
		block.rotation_degrees.x = rad_to_deg(angle)
		block.set_surface_override_material(0, rim_material)
		frame.add_child(block)


func _build_hold_trigger() -> void:
	_trigger_area = Area3D.new()
	_trigger_area.name = "YurtWindowVisionTrigger"
	add_child(_trigger_area)
	_trigger_area.global_position = trigger_position

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = trigger_size
	shape.shape = box
	_trigger_area.add_child(shape)
	_trigger_area.body_entered.connect(_on_trigger_body_entered)
	_trigger_area.body_exited.connect(_on_trigger_body_exited)


func _build_window_light() -> void:
	_window_light = OmniLight3D.new()
	_window_light.name = "RoundWindowOutsideLight"
	add_child(_window_light)
	_window_light.global_position = window_position + Vector3(-0.65, -0.2, 0.0)
	_window_light.light_color = Color(1.0, 0.86, 0.56)
	_window_light.light_energy = 0.45
	_window_light.omni_range = 4.5
	_window_light.shadow_enabled = false


func _build_rumble_player() -> void:
	_rumble_player = AudioStreamPlayer3D.new()
	_rumble_player.name = "SkyStepRumble"
	add_child(_rumble_player)
	_rumble_player.global_position = window_position + Vector3(14.0, 4.0, 0.0)
	_rumble_player.volume_db = 9.0
	_rumble_player.max_distance = 70.0
	_rumble_player.unit_size = 8.0
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 1.5
	_rumble_player.stream = stream
	_rumble_player.play()
	_rumble_playback = _rumble_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _on_trigger_body_entered(body: Node) -> void:
	if body == _player or body.name == "Player":
		_inside_trigger = true


func _on_trigger_body_exited(body: Node) -> void:
	if body == _player or body.name == "Player":
		_inside_trigger = false


func _is_player_near_window() -> bool:
	if _player == null:
		return false
	var distance: float = _player.global_position.distance_to(trigger_position)
	return distance <= PLAYER_TRIGGER_RADIUS


func _start_vision() -> void:
	_vision_started = true
	_vision_time = 0.0
	_step_timer = 0.6
	_next_left_step = true
	_hold_timer = 0.0
	print("Yurt window vision started")
	_capture_environment()
	if _rumble_player == null:
		_build_rumble_player()
	_build_vision_root()


func _capture_environment() -> void:
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	_environment = world_environment.environment
	_old_fog_enabled = _environment.fog_enabled
	_old_fog_density = _environment.fog_density
	_old_fog_color = _environment.fog_light_color
	_environment.fog_enabled = true


func _build_vision_root() -> void:
	_vision_root = Node3D.new()
	_vision_root.name = "WindowSunflowerVision"
	add_child(_vision_root)
	_fade_materials.clear()

	_build_window_fog()
	_build_sunflower_field()
	_build_sky_feet()
	_set_vision_alpha(0.0)


func _build_window_fog() -> void:
	var fog_material := _make_material(Color(0.72, 0.76, 0.72, 0.0), true, Color(0.48, 0.55, 0.52), 0.15)
	_fade_materials.append(fog_material)
	for i in range(7):
		var fog := MeshInstance3D.new()
		fog.name = "WindowFog_%02d" % i
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(5.8 + float(i) * 1.8, 2.7 + float(i) * 0.45)
		fog.mesh = mesh
		fog.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		fog.position = Vector3(9.7 + float(i) * 0.85, 2.55 + _rng.randf_range(-0.35, 0.35), 0.8 + _rng.randf_range(-1.5, 1.5))
		fog.set_surface_override_material(0, fog_material)
		_vision_root.add_child(fog)


func _build_sunflower_field() -> void:
	for i in range(FLOWER_COUNT):
		var row := float(i / 18)
		var col := float(i % 18)
		var base := Vector3(
			10.2 + row * 1.15 + _rng.randf_range(-0.25, 0.35),
			0.0,
			-7.2 + col * 0.85 + _rng.randf_range(-0.28, 0.28)
		)
		_build_sunflower(base, 1.05 + _rng.randf_range(-0.18, 0.35))


func _build_sunflower(base: Vector3, scale_factor: float) -> void:
	var flower := Node3D.new()
	flower.name = "Sunflower"
	flower.position = base
	flower.rotation_degrees.y = _rng.randf_range(-12.0, 12.0)
	_vision_root.add_child(flower)

	var stem_material := _make_fade_material(Color(0.12, 0.36, 0.13, 0.0))
	var petal_material := _make_fade_material(Color(1.0, 0.78, 0.08, 0.0))
	var center_material := _make_fade_material(Color(0.16, 0.08, 0.025, 0.0))

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025 * scale_factor
	stem_mesh.bottom_radius = 0.035 * scale_factor
	stem_mesh.height = 1.25 * scale_factor
	stem_mesh.radial_segments = 5
	stem.mesh = stem_mesh
	stem.position.y = 0.62 * scale_factor
	stem.set_surface_override_material(0, stem_material)
	flower.add_child(stem)

	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.12 * scale_factor
	head_mesh.bottom_radius = 0.12 * scale_factor
	head_mesh.height = 0.035 * scale_factor
	head_mesh.radial_segments = 8
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.32 * scale_factor, 0.0)
	head.rotation_degrees.x = 90.0
	head.set_surface_override_material(0, center_material)
	flower.add_child(head)

	for p in range(8):
		var petal := MeshInstance3D.new()
		var petal_mesh := BoxMesh.new()
		petal_mesh.size = Vector3(0.045, 0.012, 0.16) * scale_factor
		petal.mesh = petal_mesh
		var angle := TAU * float(p) / 8.0
		petal.position = Vector3(sin(angle) * 0.15, 1.32, cos(angle) * 0.15) * scale_factor
		petal.rotation_degrees = Vector3(0.0, rad_to_deg(angle), 0.0)
		petal.set_surface_override_material(0, petal_material)
		flower.add_child(petal)


func _build_sky_feet() -> void:
	_blue_legs = BLUE_LEGS_SCENE.instantiate() as Node3D
	if _blue_legs == null:
		push_error("YurtWindowVision: blue legs GLB could not be instantiated")
		return
	_blue_legs.name = "BlueLegsRiggedAnimated"
	_blue_legs.position = BLUE_LEGS_POSITION
	_blue_legs.scale = Vector3.ONE * BLUE_LEGS_SCALE
	_vision_root.add_child(_blue_legs)
	_prepare_blue_legs_fade_materials(_blue_legs)
	_blue_legs_animation_player = _find_animation_player(_blue_legs)
	if _blue_legs_animation_player == null:
		push_error("YurtWindowVision: blue legs AnimationPlayer is missing")
		return
	_ensure_blue_legs_animation_alias(_blue_legs_animation_player)
	if _blue_legs_animation_player.has_animation(BLUE_LEGS_ANIMATION):
		_blue_legs_animation_player.play(BLUE_LEGS_ANIMATION)
	else:
		push_error("YurtWindowVision: animation stomp_alternating_loop is missing")


func _prepare_blue_legs_fade_materials(root: Node) -> void:
	for node in _collect_descendants(root):
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if not source_material is StandardMaterial3D:
				continue
			var fade_material := source_material.duplicate(true) as StandardMaterial3D
			fade_material.resource_local_to_scene = true
			fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var color := fade_material.albedo_color
			color.a = 0.0
			fade_material.albedo_color = color
			mesh_instance.set_surface_override_material(surface_index, fade_material)
			_fade_materials.append(fade_material)


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _ensure_blue_legs_animation_alias(player: AnimationPlayer) -> void:
	if player.has_animation(BLUE_LEGS_ANIMATION):
		var existing := player.get_animation(BLUE_LEGS_ANIMATION)
		existing.loop_mode = Animation.LOOP_LINEAR
		return
	if not player.has_animation(BLUE_LEGS_SOURCE_ANIMATION):
		return
	var source := player.get_animation(BLUE_LEGS_SOURCE_ANIMATION)
	var default_library := player.get_animation_library(&"")
	if default_library == null:
		default_library = AnimationLibrary.new()
		player.add_animation_library(&"", default_library)
	else:
		var local_library := default_library.duplicate(true) as AnimationLibrary
		player.remove_animation_library(&"")
		player.add_animation_library(&"", local_library)
		default_library = local_library
	var looping_animation := source.duplicate(true) as Animation
	looping_animation.loop_mode = Animation.LOOP_LINEAR
	default_library.add_animation(BLUE_LEGS_ANIMATION, looping_animation)


func _collect_descendants(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_collect_descendants(child))
	return nodes


func _update_vision(delta: float) -> void:
	_vision_time += delta
	var total_seconds: float = flower_fade_seconds + step_scene_seconds + fade_out_seconds
	var fade_in_alpha: float = clampf(_vision_time / flower_fade_seconds, 0.0, 1.0)
	var fade_out_start: float = flower_fade_seconds + step_scene_seconds

	if _vision_time < fade_out_start:
		_set_vision_alpha(fade_in_alpha)
	else:
		var fade_out_alpha: float = 1.0 - clampf((_vision_time - fade_out_start) / fade_out_seconds, 0.0, 1.0)
		_set_vision_alpha(fade_out_alpha)

	_update_environment_fog()
	_update_sky_steps(delta)

	if _vision_time >= total_seconds:
		_finish_vision()


func _update_sky_steps(delta: float) -> void:
	if _vision_time < flower_fade_seconds:
		return
	if _vision_time > flower_fade_seconds + step_scene_seconds:
		return

	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 1.4
		_next_left_step = not _next_left_step
		_push_rumble()
		print("Sky footstep rumble")


func _push_rumble() -> void:
	if _rumble_playback == null:
		return
	var frames: int = int(float(SAMPLE_RATE) * 0.9)
	for i in range(frames):
		if _rumble_playback.get_frames_available() <= 0:
			break
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = pow(1.0 - float(i) / float(frames), 2.0)
		var low: float = sin(TAU * 34.0 * t) * 0.55
		var lower: float = sin(TAU * 18.0 * t) * 0.45
		var noise: float = _rng.randf_range(-0.18, 0.18)
		var sample: float = clampf((low + lower + noise) * env, -0.95, 0.95)
		_rumble_playback.push_frame(Vector2(sample, sample))


func _update_environment_fog() -> void:
	if _environment == null:
		return
	var fade_in_alpha: float = clampf(_vision_time / flower_fade_seconds, 0.0, 1.0)
	var fade_out_start: float = flower_fade_seconds + step_scene_seconds
	var end_alpha: float = clampf((_vision_time - fade_out_start) / fade_out_seconds, 0.0, 1.0) if _vision_time > fade_out_start else 0.0
	var fog_alpha: float = maxf(fade_in_alpha * 0.55, end_alpha)
	_environment.fog_density = lerp(_old_fog_density, 0.055, fog_alpha)
	_environment.fog_light_color = _old_fog_color.lerp(Color(0.64, 0.68, 0.66), fog_alpha)


func _finish_vision() -> void:
	print("Yurt window vision faded")
	_vision_started = false
	_inside_trigger = false
	_hold_timer = 0.0
	if _vision_root != null:
		_vision_root.queue_free()
		_vision_root = null
	_restore_environment()


func _restore_environment() -> void:
	if _environment == null:
		return
	_environment.fog_enabled = _old_fog_enabled
	_environment.fog_density = _old_fog_density
	_environment.fog_light_color = _old_fog_color
	_environment = null


func _set_vision_alpha(alpha: float) -> void:
	for material in _fade_materials:
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
		if material.emission_enabled:
			material.emission_energy_multiplier = alpha * 0.5


func _make_fade_material(color: Color, emission_color: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := _make_material(color, true, emission_color, emission_energy)
	_fade_materials.append(material)
	return material


func _make_material(color: Color, transparent: bool, emission_color: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = false
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material
