extends Node3D

@export var trigger_distance: float = 2.25
@export var look_trigger_distance: float = 4.2
@export var look_dot_threshold: float = 0.985
@export var escape_delay_min: float = 0.15
@export var escape_delay_max: float = 0.34
@export var escape_offset: Vector3 = Vector3(0.65, 0.0, -0.46)
@export var escape_seconds: float = 0.22

@onready var visual: Node3D = $Visual

var _triggered := false
var _escaping := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(_delta: float) -> void:
	if _triggered:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)
	if distance <= trigger_distance or _player_is_looking_at_me(player, distance):
		_trigger_escape()


func _process(_delta: float) -> void:
	if _triggered or visual == null:
		return
	var twitch := sin(Time.get_ticks_msec() * 0.024) * 0.035
	visual.rotation.z = twitch


func _player_is_looking_at_me(player: Node3D, distance: float) -> bool:
	if distance > look_trigger_distance:
		return false

	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return false

	var to_cockroach := (global_position - camera.global_position).normalized()
	var forward := -camera.global_transform.basis.z.normalized()
	return forward.dot(to_cockroach) >= look_dot_threshold


func _trigger_escape() -> void:
	if _escaping:
		return

	_triggered = true
	_escaping = true
	await get_tree().create_timer(_rng.randf_range(escape_delay_min, escape_delay_max)).timeout

	var target := position + escape_offset
	var tween := create_tween()
	tween.tween_property(self, "position", target, escape_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	set_physics_process(false)
	set_process(false)
