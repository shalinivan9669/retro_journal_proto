class_name ObservationCamera
extends Camera3D

@export var move_speed := 7.0
@export var mouse_sensitivity := 0.075
var _mouse_captured := true


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		rotation_degrees.x -= event.relative.y * mouse_sensitivity
		rotation_degrees.x = clampf(rotation_degrees.x, -28.0, 12.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_mouse_captured = not _mouse_captured
		Input.set_mouse_mode(
			Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
		)


func _process(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		input.y += 1.0
	if input.length_squared() > 0.0:
		position += global_basis * input.normalized() * move_speed * delta
