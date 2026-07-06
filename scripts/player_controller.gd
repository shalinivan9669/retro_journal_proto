extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 16.0
@export var controls_locked: bool = false

@onready var head: Node3D = $Head
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay

var pitch := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		head.rotation.x = pitch

	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			var dialogue_ui := _get_dialogue_ui()
			if _is_dialogue_open(dialogue_ui):
				dialogue_ui.call("hide_message")
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if event.keycode == KEY_E:
			var dialogue_ui := _get_dialogue_ui()
			if _is_dialogue_open(dialogue_ui):
				dialogue_ui.call("hide_message")
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_try_interact()


func _physics_process(delta: float) -> void:
	if controls_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
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

	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	move_and_slide()


func _try_interact() -> void:
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return

	var target := interaction_ray.get_collider()
	while target != null and not target.has_method("interact"):
		target = target.get_parent()

	if target != null:
		target.call("interact", _get_dialogue_ui())


func _get_dialogue_ui() -> Node:
	return get_tree().get_first_node_in_group("dialogue_ui")


func _is_dialogue_open(dialogue_ui: Node) -> bool:
	if dialogue_ui == null or not dialogue_ui.has_method("is_open"):
		return false
	return bool(dialogue_ui.call("is_open"))
