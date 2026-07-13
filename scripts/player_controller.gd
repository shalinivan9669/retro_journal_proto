extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var sprint_multiplier: float = 2.6
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 16.0
@export var jump_enabled: bool = false
@export var jump_velocity: float = 6.0
@export_range(0.0, 89.0, 0.1) var floor_max_angle_degrees: float = 45.0
@export var physics_floor_snap_length: float = 0.6
@export var controls_locked: bool = false
@export var standing_height: float = 1.7
@export var crouch_height: float = 1.05
@export var standing_head_y: float = 1.7
@export var crouch_head_y: float = 1.05
@export var crouch_speed_multiplier: float = 0.45
@export var albasty_easy_interact_distance: float = 58.0
@export var albasty_easy_interact_min_dot: float = -0.05
@export var landscape_ground_assist_enabled: bool = true
@export var landscape_ground_surface_offset: float = 0.025
@export var landscape_ground_snap_down: float = 1.35
@export var landscape_ground_step_up: float = 0.9
@export var landscape_ground_rescue_margin: float = 0.14
@export var shovel_scene_path: String = "res://assets/polyhaven/props/rusted_spade_01/rusted_spade_01_2k.gltf"
@export var aim_zoom_multiplier: float = 1.5
@export var aim_zoom_speed: float = 12.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var shadow_proxy: MeshInstance3D = $PlayerShadowProxy
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var pitch := 0.0
var _capsule_shape: CapsuleShape3D
var _is_crouching := false
var _has_triggered_crouch_lore := false
var _steppe_environment: Node
var _shovel_equipped := false
var _held_shovel: Node3D
var _shovel_rest_position := Vector3(-0.72, -0.42, -0.92)
var _shovel_rest_rotation := Vector3(deg_to_rad(-54.0), deg_to_rad(-18.0), deg_to_rad(12.0))
var _dig_phase := 0.0
var _dig_call_cooldown := 0.0
var _default_camera_fov := 75.0
var _aim_zoom_held := false
var _jump_was_pressed := false


func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_capsule_shape = collision_shape.shape as CapsuleShape3D
	if camera != null:
		_default_camera_fov = camera.fov
	floor_max_angle = deg_to_rad(floor_max_angle_degrees)
	floor_snap_length = (
		maxf(physics_floor_snap_length, landscape_ground_snap_down)
		if landscape_ground_assist_enabled
		else physics_floor_snap_length
	)
	_steppe_environment = _find_steppe_environment()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return

	if controls_locked:
		_aim_zoom_held = false
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_aim_zoom_held = event.pressed
		if event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		head.rotation.x = pitch

	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _shovel_equipped and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			return
		if _is_interact_event(event):
			_handle_interact_action()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			var film_viewer := get_tree().get_first_node_in_group("film_viewer")
			if film_viewer != null and film_viewer.has_method("handle_key") and bool(film_viewer.call("handle_key", event.keycode)):
				get_viewport().set_input_as_handled()
				return

			var signal_dialogue := _get_signal_dialogue_window()
			if _is_signal_dialogue_open(signal_dialogue):
				signal_dialogue.call("hide_signal_message")
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				return

			var dialogue_ui := _get_dialogue_ui()
			if _is_dialogue_open(dialogue_ui):
				dialogue_ui.call("hide_message")
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if _is_interact_event(event):
			_handle_interact_action()
			return

		if event.keycode == KEY_F:
			var film_viewer := get_tree().get_first_node_in_group("film_viewer")
			if film_viewer != null and film_viewer.has_method("handle_key") and bool(film_viewer.call("handle_key", event.keycode)):
				get_viewport().set_input_as_handled()
				return

			var signal_dialogue := _get_signal_dialogue_window()
			if _is_signal_dialogue_open(signal_dialogue):
				return

			_try_signal_trigger()

		if event.keycode == KEY_2:
			_toggle_shovel()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	_update_aim_zoom(delta)
	_update_shovel(delta)


func _update_aim_zoom(delta: float) -> void:
	if camera == null:
		return
	var zooming := not controls_locked and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and _aim_zoom_held
	var target_fov := _get_zoom_fov(_default_camera_fov) if zooming else _default_camera_fov
	var blend := clampf(delta * aim_zoom_speed, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, target_fov, blend)


func _get_zoom_fov(base_fov: float) -> float:
	var multiplier := maxf(aim_zoom_multiplier, 1.0)
	var half_angle := deg_to_rad(base_fov) * 0.5
	return rad_to_deg(atan(tan(half_angle) / multiplier) * 2.0)


func _physics_process(delta: float) -> void:
	var jump_pressed := Input.is_key_pressed(KEY_SPACE)
	var jump_just_pressed := jump_enabled and jump_pressed and not _jump_was_pressed
	_jump_was_pressed = jump_pressed
	if controls_locked:
		_hide_interaction_prompt()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_update_crouch(delta)
	var assisted_floor := _apply_landscape_ground_assist(true)

	if jump_just_pressed and (assisted_floor or is_on_floor()):
		velocity.y = jump_velocity
	elif not assisted_floor and not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	input_dir = input_dir.normalized()
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := walk_speed
	if _is_crouching:
		speed = walk_speed * crouch_speed_multiplier
	elif _is_sprint_pressed():
		speed = walk_speed * sprint_multiplier

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	_apply_landscape_ground_assist(false)
	_update_interaction_prompt()


func _ensure_input_actions() -> void:
	if InputMap.has_action("interact"):
		return

	InputMap.add_action("interact")

	var key_event := InputEventKey.new()
	key_event.keycode = KEY_E
	InputMap.action_add_event("interact", key_event)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interact", mouse_event)


func _is_interact_event(event: InputEvent) -> bool:
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		return true
	if event is InputEventKey:
		return event.keycode == KEY_E
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT
	return false


func _handle_interact_action() -> void:
	var signal_dialogue := _get_signal_dialogue_window()
	if _is_signal_dialogue_open(signal_dialogue):
		signal_dialogue.call("hide_signal_message")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	var dialogue_ui := _get_dialogue_ui()
	if _is_dialogue_open(dialogue_ui):
		dialogue_ui.call("hide_message")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		_try_interact()


func _try_interact() -> void:
	var target := _get_ray_target_with_method("interact")

	if target != null:
		target.call("interact", _get_dialogue_ui())
		return

	# Albasty is a forgiving fallback target, so normal yurt interactions keep priority.
	target = _get_easy_albasty_target()
	if target != null:
		target.call("interact", _get_dialogue_ui())


func _try_signal_trigger() -> void:
	var target := _get_ray_target_with_method("trigger_signal")

	if target != null:
		target.call("trigger_signal", _get_dialogue_ui())


func _toggle_shovel() -> void:
	_shovel_equipped = not _shovel_equipped
	_ensure_held_shovel()
	if _held_shovel != null:
		_held_shovel.visible = _shovel_equipped


func _ensure_held_shovel() -> void:
	if _held_shovel != null or camera == null:
		return

	var root := Node3D.new()
	root.name = "HeldRustedSpade"
	root.position = _shovel_rest_position
	root.rotation = _shovel_rest_rotation
	root.visible = false
	camera.add_child(root)
	_held_shovel = root

	var scene := load(shovel_scene_path) as PackedScene
	if scene != null:
		var model := scene.instantiate()
		model.name = "RustedSpade01Model"
		if model is Node3D:
			var model_3d := model as Node3D
			model_3d.scale = Vector3.ONE * 1.14
			model_3d.rotation_degrees = Vector3(-96.0, 0.0, 184.0)
			model_3d.position = Vector3(0.0, -0.18, 0.0)
		root.add_child(model)
	else:
		_build_fallback_shovel(root)


func _build_fallback_shovel(parent: Node3D) -> void:
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.28, 0.17, 0.09, 1.0)
	handle_mat.roughness = 0.9
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.22, 0.16, 0.12, 1.0)
	metal_mat.roughness = 0.94
	metal_mat.metallic = 0.2

	var handle := MeshInstance3D.new()
	handle.name = "FallbackHandle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.025
	handle_mesh.height = 1.15
	handle_mesh.radial_segments = 10
	handle.mesh = handle_mesh
	handle.rotation_degrees.x = 90.0
	handle.position = Vector3(0.0, 0.0, -0.22)
	handle.set_surface_override_material(0, handle_mat)
	parent.add_child(handle)

	var blade := MeshInstance3D.new()
	blade.name = "FallbackBlade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.32, 0.04, 0.42)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, -0.02, -0.86)
	blade.set_surface_override_material(0, metal_mat)
	parent.add_child(blade)


func _update_shovel(delta: float) -> void:
	if _held_shovel == null:
		if _shovel_equipped:
			_ensure_held_shovel()
		return

	_dig_call_cooldown = maxf(0.0, _dig_call_cooldown - delta)
	var digging := _shovel_equipped and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if digging:
		_dig_phase += delta * 9.0
		var swing := sin(_dig_phase)
		var thrust := maxf(0.0, swing)
		_held_shovel.position = _shovel_rest_position + Vector3(0.0, -0.18 * thrust, -0.34 * thrust)
		_held_shovel.rotation = _shovel_rest_rotation + Vector3(deg_to_rad(34.0 * thrust), deg_to_rad(-5.0 * swing), deg_to_rad(5.0 * swing))
		if _dig_call_cooldown <= 0.0 and thrust > 0.72:
			_try_shovel_dig()
			_dig_call_cooldown = 0.24
	else:
		_dig_phase = 0.0
		_held_shovel.position = _held_shovel.position.lerp(_shovel_rest_position, clampf(delta * 14.0, 0.0, 1.0))
		_held_shovel.rotation = _held_shovel.rotation.lerp(_shovel_rest_rotation, clampf(delta * 14.0, 0.0, 1.0))


func _try_shovel_dig() -> void:
	var target := _get_ray_target_with_method("shovel_dig")
	if target != null:
		target.call("shovel_dig", self)


func _update_interaction_prompt() -> void:
	var dialogue_ui := _get_dialogue_ui()
	if dialogue_ui == null or not dialogue_ui.has_method("show_prompt"):
		return

	if _is_dialogue_open(dialogue_ui):
		dialogue_ui.call("hide_prompt")
		return

	var target := _get_ray_target_with_method("get_interaction_prompt")
	if target == null:
		dialogue_ui.call("hide_prompt")
		return

	var prompt := String(target.call("get_interaction_prompt"))
	if prompt.is_empty():
		dialogue_ui.call("hide_prompt")
	else:
		dialogue_ui.call("show_prompt", prompt)


func _hide_interaction_prompt() -> void:
	var dialogue_ui := _get_dialogue_ui()
	if dialogue_ui != null and dialogue_ui.has_method("hide_prompt"):
		dialogue_ui.call("hide_prompt")


func _apply_landscape_ground_assist(before_move: bool) -> bool:
	if not landscape_ground_assist_enabled:
		return false

	var ground_y := _get_landscape_ground_y()
	if ground_y <= -INF * 0.5:
		return false

	var target_y := ground_y + landscape_ground_surface_offset
	var delta_y := global_position.y - target_y
	var should_snap := false

	if delta_y < -landscape_ground_rescue_margin:
		should_snap = true
	elif before_move:
		should_snap = absf(delta_y) <= 0.08
	else:
		if delta_y >= 0.0 and delta_y <= landscape_ground_snap_down and velocity.y <= 0.05:
			should_snap = true
		elif delta_y < 0.0 and absf(delta_y) <= landscape_ground_step_up:
			should_snap = true

	if not should_snap:
		return false

	var fixed_position := global_position
	fixed_position.y = target_y
	global_position = fixed_position
	if velocity.y < 0.0:
		velocity.y = 0.0
	return true


func _get_landscape_ground_y() -> float:
	var steppe_environment := _get_steppe_environment()
	if steppe_environment == null:
		return -INF
	if not steppe_environment.has_method("has_walkable_ground_at"):
		return -INF
	if not steppe_environment.has_method("get_walkable_ground_y"):
		return -INF
	if not bool(steppe_environment.call("has_walkable_ground_at", global_position.x, global_position.z)):
		return -INF
	return float(steppe_environment.call("get_walkable_ground_y", global_position.x, global_position.z))


func _get_steppe_environment() -> Node:
	if _steppe_environment != null and is_instance_valid(_steppe_environment):
		return _steppe_environment
	_steppe_environment = _find_steppe_environment()
	return _steppe_environment


func _find_steppe_environment() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("SteppeEnvironment")


func _get_ray_target_with_method(method_name: String) -> Node:
	if interaction_ray == null:
		return null

	var world := get_world_3d()
	if world == null:
		return null

	var from := interaction_ray.global_position
	var to := interaction_ray.to_global(interaction_ray.target_position)
	var excluded: Array[RID] = []
	excluded.append(get_rid())

	for _i in range(10):
		var query := PhysicsRayQueryParameters3D.create(from, to, interaction_ray.collision_mask, excluded)
		query.collide_with_areas = interaction_ray.collide_with_areas
		query.collide_with_bodies = interaction_ray.collide_with_bodies
		query.hit_from_inside = true

		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return null

		var collider := hit.get("collider") as Node
		var target := _find_parent_with_method(collider, method_name)
		if target != null:
			return target

		if hit.has("rid"):
			excluded.append(hit["rid"])
		elif collider is CollisionObject3D:
			excluded.append((collider as CollisionObject3D).get_rid())
		else:
			return null

	return null


func _find_parent_with_method(node: Node, method_name: String) -> Node:
	var target := node
	while target != null and not target.has_method(method_name):
		target = target.get_parent()
	return target


func _get_easy_albasty_target() -> Node:
	if camera == null:
		return null

	# Wide front-sector search makes the distant spirit scareable without precise aim.
	var best: Node = null
	var best_score := -INF
	var forward := -camera.global_transform.basis.z.normalized()

	for node in get_tree().get_nodes_in_group("albasty"):
		if not is_instance_valid(node):
			continue
		if not node.has_method("interact"):
			continue

		var n3d := node as Node3D
		if n3d == null:
			continue

		var to_target := n3d.global_position - camera.global_position
		var distance := to_target.length()
		if distance <= 0.01 or distance > albasty_easy_interact_distance:
			continue

		var direction_to_target := to_target.normalized()
		var dot := forward.dot(direction_to_target)
		if dot < albasty_easy_interact_min_dot:
			continue

		var distance_score := 1.0 - (distance / albasty_easy_interact_distance)
		var score := dot * 2.0 + distance_score
		if score > best_score:
			best_score = score
			best = node

	return best


func _update_crouch(delta: float) -> void:
	var wants_crouch := _is_crouch_pressed()
	var was_crouching := _is_crouching
	if wants_crouch:
		_is_crouching = true
	elif _is_crouching and _can_stand():
		_is_crouching = false

	if _is_crouching and not was_crouching:
		_try_show_crouch_lore()

	var target_height := crouch_height if _is_crouching else standing_height
	var target_head_y := crouch_head_y if _is_crouching else standing_head_y
	var weight := clampf(delta * 12.0, 0.0, 1.0)

	var current_height := target_height
	if _capsule_shape != null:
		current_height = lerpf(_capsule_shape.height, target_height, weight)
		_capsule_shape.height = current_height
	if collision_shape != null:
		collision_shape.position.y = current_height * 0.5
	if shadow_proxy != null:
		shadow_proxy.position.y = current_height * 0.5
		shadow_proxy.scale.y = current_height / standing_height
	if head != null:
		head.position.y = lerpf(head.position.y, target_head_y, weight)


func _try_show_crouch_lore() -> void:
	if _has_triggered_crouch_lore:
		return
	_has_triggered_crouch_lore = true

	var overlay := get_tree().get_first_node_in_group("crouch_lore_overlay")
	if overlay != null and overlay.has_method("show_lore"):
		overlay.call("show_lore")


func _can_stand() -> bool:
	if _capsule_shape == null:
		return true

	var height_delta := standing_height - _capsule_shape.height
	if height_delta <= 0.01:
		return true

	return not test_move(global_transform, Vector3.UP * height_delta)


func _is_sprint_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _is_crouch_pressed() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)


func _get_dialogue_ui() -> Node:
	return get_tree().get_first_node_in_group("dialogue_ui")


func _get_signal_dialogue_window() -> Node:
	return get_tree().get_first_node_in_group("signal_dialogue_window")


func _is_dialogue_open(dialogue_ui: Node) -> bool:
	if dialogue_ui == null or not dialogue_ui.has_method("is_open"):
		return false
	return bool(dialogue_ui.call("is_open"))


func _is_signal_dialogue_open(signal_dialogue: Node) -> bool:
	if signal_dialogue == null or not signal_dialogue.has_method("is_open"):
		return false
	return bool(signal_dialogue.call("is_open"))


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
