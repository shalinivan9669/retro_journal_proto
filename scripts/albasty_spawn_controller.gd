extends Node3D
class_name AlbastySpawnController

## Put this on the level root or on a manager node.
## Add Marker3D/Node3D spawn points near powerline towers and put them into group `albasty_spawn_points`.
## Assign `albasty_scene` to `res://scenes/albasty_instance.tscn` in the inspector.

@export var albasty_scene: PackedScene
@export var spawn_point_group: StringName = &"albasty_spawn_points"
@export var max_alive: int = 1
@export var spawn_interval_min: float = 25.0
@export var spawn_interval_max: float = 80.0
@export_range(0.0, 1.0, 0.01) var spawn_chance: float = 0.35
@export var spawn_only_at_night: bool = false
@export var player_group: StringName = &"player"
@export var min_distance_from_player: float = 16.0
@export var max_distance_from_player: float = 80.0

var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_timer = _next_interval()

func _process(delta: float) -> void:
	if albasty_scene == null:
		return
	if _is_albasty_suppressed():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _next_interval()

	if _count_alive_albasty() >= max_alive:
		return
	if _rng.randf() > spawn_chance:
		return

	var point := _pick_spawn_point()
	if point == null:
		return
	_spawn_at(point.global_position, point.global_rotation)

func force_spawn() -> Node3D:
	if _is_albasty_suppressed():
		return null
	var point := _pick_spawn_point()
	if point == null:
		return null
	return _spawn_at(point.global_position, point.global_rotation)

func _spawn_at(pos: Vector3, rot: Vector3) -> Node3D:
	if _is_albasty_suppressed():
		return null
	var inst := albasty_scene.instantiate()
	if inst is Node3D:
		add_child(inst)
		inst.global_position = pos
		inst.global_rotation = rot
		return inst
	inst.queue_free()
	return null

func _pick_spawn_point() -> Node3D:
	var player := _get_first_in_group(player_group)
	var candidates: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(spawn_point_group):
		if node is Node3D:
			var marker := node as Node3D
			if player != null:
				var d := player.global_position.distance_to(marker.global_position)
				if d < min_distance_from_player or d > max_distance_from_player:
					continue
			candidates.append(marker)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _count_alive_albasty() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"albasty"):
		if is_instance_valid(node):
			count += 1
	return count

func _next_interval() -> float:
	return _rng.randf_range(spawn_interval_min, spawn_interval_max)


func _is_albasty_suppressed() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	return game_state != null and game_state.has_method("is_albasty_hidden_by_ritual") and bool(game_state.call("is_albasty_hidden_by_ritual"))

func _get_first_in_group(group_name: StringName) -> Node3D:
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D:
			return node
	return null
