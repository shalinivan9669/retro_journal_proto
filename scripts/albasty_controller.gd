extends Node3D
class_name AlbastyController

signal reached_horse_zone
signal scared_away

@export var target_path: NodePath
@export var player_path: NodePath
@export var move_speed: float = 0.85
@export var turn_speed: float = 3.0
@export var stop_distance: float = 1.8
@export var scare_distance: float = 12.0
@export var retreat_speed: float = 4.5
@export var retreat_duration: float = 2.0
@export var auto_repel_distance: float = 3.0

var _target: Node3D
var _player: Node3D
var _state := "stalking"
var _retreat_timer := 0.0
var _retreat_dir := Vector3.ZERO
var _reached_printed := false


func _ready() -> void:
	add_to_group("albasty")
	_target = get_node_or_null(target_path) as Node3D
	_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if _state == "scared":
		_process_retreat(delta)
		return

	if _player != null and global_position.distance_to(_player.global_position) <= auto_repel_distance:
		scare_away(_player)
		return

	if _target == null:
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stop_distance:
		_reached_horse_zone()
		return

	var direction := to_target.normalized()
	global_position += direction * move_speed * delta
	_slow_look_at(global_position + direction, delta)


func interact(_dialogue_ui: Node = null) -> void:
	if _state == "scared":
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) > scare_distance:
		return
	scare_away(_player)


func scare_away(source: Node3D) -> void:
	if _state == "scared":
		return

	var away := global_position - source.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = -global_transform.basis.z
	_retreat_dir = away.normalized()
	_retreat_timer = retreat_duration
	_state = "scared"
	scared_away.emit()
	print("Albasty scared away")


func on_horse_zone_reached() -> void:
	_reached_horse_zone()


func _process_retreat(delta: float) -> void:
	global_position += _retreat_dir * retreat_speed * delta
	_slow_look_at(global_position - _retreat_dir, delta)
	_retreat_timer -= delta
	if _retreat_timer <= 0.0:
		queue_free()


func _reached_horse_zone() -> void:
	if _reached_printed:
		return
	_reached_printed = true
	reached_horse_zone.emit()
	print("Albasty reached horses")


func _slow_look_at(world_target: Vector3, delta: float) -> void:
	var flat_target := world_target
	flat_target.y = global_position.y
	var direction := flat_target - global_position
	if direction.length() < 0.001:
		return
	var desired_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clamp(turn_speed * delta, 0.0, 1.0))
