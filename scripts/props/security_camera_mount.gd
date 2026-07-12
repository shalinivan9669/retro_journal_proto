extends Node3D

@export var target_path: NodePath
@export var sweep_enabled := true
@export var sweep_angle_deg := 2.0
@export var sweep_speed := 0.7

@onready var _target := get_node_or_null(target_path) as Node3D
var _base_rotation := Vector3.ZERO


func _ready() -> void:
	if _target != null:
		look_at(_target.global_position, Vector3.UP, true)
		_base_rotation = rotation


func _process(_delta: float) -> void:
	if not sweep_enabled:
		return
	rotation = _base_rotation
	var phase := Time.get_ticks_msec() * 0.001 * sweep_speed
	rotate_object_local(Vector3.UP, deg_to_rad(sin(phase) * sweep_angle_deg))
