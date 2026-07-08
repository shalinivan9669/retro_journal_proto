extends Node3D

signal caught_player

@export var rush_speed: float = 5.2
@export var catch_distance: float = 1.25
@export var bob_amount: float = 0.08
@export var bob_speed: float = 11.0
@export var sway_amount: float = 4.5

@onready var model_pivot: Node3D = $ModelPivot

var _target: Node3D
var _state := "idle"
var _rush_delay := 0.0
var _time := 0.0
var _base_pivot_position := Vector3.ZERO
var _base_pivot_rotation := Vector3.ZERO
var _caught := false


func _ready() -> void:
	_base_pivot_position = model_pivot.position
	_base_pivot_rotation = model_pivot.rotation_degrees
	add_to_group("final_soldier_enemy")


func set_target(player: Node3D) -> void:
	_target = player
	_face_target()


func start_rush(delay: float = 0.0) -> void:
	_rush_delay = maxf(delay, 0.0)
	_state = "waiting_to_rush" if _rush_delay > 0.0 else "rush"
	_time = 0.0


func _process(delta: float) -> void:
	_time += delta

	if _state == "waiting_to_rush":
		_play_idle_motion(delta)
		_rush_delay -= delta
		if _rush_delay <= 0.0:
			_state = "rush"
			_time = 0.0
		return

	if _state == "rush":
		_rush(delta)
	else:
		_play_idle_motion(delta)


func _rush(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_play_idle_motion(delta)
		return

	var target_position := _target.global_position
	var to_target := target_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	if distance <= catch_distance:
		_emit_caught_once()
		return

	var direction := to_target / distance
	_face_target()
	global_position += direction * rush_speed * delta

	var bob := sin(_time * bob_speed) * bob_amount
	var sway := sin(_time * bob_speed * 0.72) * sway_amount
	model_pivot.position = _base_pivot_position + Vector3(0.0, bob, 0.0)
	model_pivot.rotation_degrees = _base_pivot_rotation + Vector3(0.0, 0.0, sway)


func _play_idle_motion(delta: float) -> void:
	_face_target()
	var breath := sin(_time * 1.7) * bob_amount * 0.18
	var sway := sin(_time * 1.15) * sway_amount * 0.12
	model_pivot.position = model_pivot.position.lerp(_base_pivot_position + Vector3(0.0, breath, 0.0), clampf(delta * 6.0, 0.0, 1.0))
	model_pivot.rotation_degrees = model_pivot.rotation_degrees.lerp(_base_pivot_rotation + Vector3(0.0, 0.0, sway), clampf(delta * 5.0, 0.0, 1.0))


func _face_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var look_target := Vector3(_target.global_position.x, global_position.y, _target.global_position.z)
	if global_position.distance_squared_to(look_target) <= 0.0001:
		return
	look_at(look_target, Vector3.UP)


func _emit_caught_once() -> void:
	if _caught:
		return
	_caught = true
	caught_player.emit()
