extends Node3D
class_name AlbastyController

signal reached_horse_zone
signal scared_away

enum AlbastyState {
	IDLE,
	APPROACHING_HORSE,
	WAITING_AT_HORSE,
	STEALING_RETREAT,
	HIDDEN_AFTER_STEAL,
	APPROACHING_YURT,
	YURT_REACHED,
	REPELLED,
	PEACEFUL_POWERLINE
}

@export var target_path: NodePath
@export var player_path: NodePath
@export var move_speed: float = 0.85
@export var turn_speed: float = 3.0
@export var stop_distance: float = 1.8
@export var scare_distance: float = 58.0
@export var easy_interaction_distance: float = 58.0
@export var retreat_speed: float = 4.5
@export var retreat_duration: float = 2.0
@export var auto_repel_distance: float = 8.0
@export var horse_reach_distance: float = 2.8
@export var horse_steal_countdown: float = 5.0
@export var steal_hide_duration: float = 60.0
@export var approach_speed: float = 1.2
@export var steal_retreat_speed: float = 2.0
@export var steal_retreat_distance: float = 8.0
@export var steal_retreat_duration: float = 3.0
@export var yurt_approach_speed: float = 1.0
@export var yurt_stop_distance: float = 1.8
@export var debug_albasty_horse_ai: bool = true

var _target: Node3D
var _player: Node3D
var _state: AlbastyState = AlbastyState.IDLE
var _retreat_timer := 0.0
var _retreat_dir := Vector3.ZERO
var _horse_wait_timer := 0.0
var _hide_timer := 0.0
var _steal_retreat_timer := 0.0
var _retreat_target := Vector3.ZERO
var _current_horse: Node3D
var _current_horse_last_position := Vector3.ZERO
var _yurt_target: Node3D
var _spawn_position := Vector3.ZERO
var _has_spawn_position := false
var stolen_horse_count := 0


func _ready() -> void:
	add_to_group("albasty")
	_target = get_node_or_null(target_path) as Node3D
	_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D


func set_spawn_position(position: Vector3) -> void:
	_spawn_position = position
	_has_spawn_position = true


func set_peaceful_powerline_mode(marker: Node3D = null) -> void:
	_current_horse = null
	_yurt_target = null
	_horse_wait_timer = 0.0
	if marker != null:
		global_position = marker.global_position
	_state = AlbastyState.PEACEFUL_POWERLINE
	visible = true
	_set_interaction_enabled(false)
	_set_collision_enabled(true)


func _physics_process(delta: float) -> void:
	if not _has_spawn_position:
		set_spawn_position(global_position)

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	match _state:
		AlbastyState.IDLE:
			_pick_next_goal()
		AlbastyState.APPROACHING_HORSE:
			_update_approach_horse(delta)
		AlbastyState.WAITING_AT_HORSE:
			_update_waiting_at_horse(delta)
		AlbastyState.STEALING_RETREAT:
			_update_stealing_retreat(delta)
		AlbastyState.HIDDEN_AFTER_STEAL:
			_update_hidden_after_steal(delta)
		AlbastyState.APPROACHING_YURT:
			_update_approach_yurt(delta)
		AlbastyState.YURT_REACHED:
			pass
		AlbastyState.REPELLED:
			_process_repelled(delta)
		AlbastyState.PEACEFUL_POWERLINE:
			_process_peaceful_powerline(delta)


func interact(_dialogue_ui: Node = null) -> void:
	if _state == AlbastyState.HIDDEN_AFTER_STEAL or _state == AlbastyState.REPELLED:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	var allowed_distance: float = maxf(scare_distance, easy_interaction_distance)
	if global_position.distance_to(_player.global_position) > allowed_distance:
		return
	if _state == AlbastyState.WAITING_AT_HORSE:
		_horse_wait_timer = 0.0
		_current_horse = null
	scare_away(_player)


func scare_away(source: Node3D) -> void:
	if _state == AlbastyState.HIDDEN_AFTER_STEAL or _state == AlbastyState.REPELLED:
		return

	var away := global_position - source.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = -global_transform.basis.z
	_retreat_dir = away.normalized()
	_retreat_timer = retreat_duration
	_state = AlbastyState.REPELLED
	scared_away.emit()
	_show_scare_window()
	_debug_print("ALBASY: scared away")


func on_horse_zone_reached() -> void:
	if _state == AlbastyState.APPROACHING_HORSE:
		_begin_waiting_at_horse()


func _pick_next_goal() -> void:
	var horse := _choose_next_horse()
	if horse != null:
		_current_horse = horse
		_state = AlbastyState.APPROACHING_HORSE
		_debug_print("ALBASY: targeting horse %s" % horse.name)
		return

	_current_horse = null
	_yurt_target = _get_yurt_entrance()
	if _yurt_target != null:
		_state = AlbastyState.APPROACHING_YURT
		_debug_print("ALBASY: no horses left, approaching yurt")
	else:
		_debug_print("ALBASY: no horses and no yurt entrance marker")


func _update_approach_horse(delta: float) -> void:
	if not _is_valid_horse(_current_horse):
		_current_horse = null
		_state = AlbastyState.IDLE
		return

	if _player != null and global_position.distance_to(_player.global_position) <= auto_repel_distance:
		scare_away(_player)
		return

	var to_horse := _current_horse.global_position - global_position
	to_horse.y = 0.0
	var distance := to_horse.length()
	if distance <= horse_reach_distance:
		_begin_waiting_at_horse()
		return

	var direction := to_horse.normalized()
	global_position += direction * approach_speed * delta
	_slow_look_at(global_position + direction, delta)


func _begin_waiting_at_horse() -> void:
	if not _is_valid_horse(_current_horse):
		_current_horse = null
		_state = AlbastyState.IDLE
		return

	_current_horse_last_position = _current_horse.global_position
	_horse_wait_timer = horse_steal_countdown
	_state = AlbastyState.WAITING_AT_HORSE
	reached_horse_zone.emit()
	_debug_print("ALBASY: waiting near horse, player has %.1f seconds" % horse_steal_countdown)


func _update_waiting_at_horse(delta: float) -> void:
	if not _is_valid_horse(_current_horse):
		_current_horse = null
		_state = AlbastyState.IDLE
		return

	if _player != null and global_position.distance_to(_player.global_position) <= auto_repel_distance:
		_horse_wait_timer = 0.0
		_current_horse = null
		scare_away(_player)
		return

	_slow_look_at(_current_horse.global_position, delta)
	_horse_wait_timer -= delta
	if _horse_wait_timer <= 0.0:
		_begin_stealing_retreat()


func _begin_stealing_retreat() -> void:
	var stolen_name := ""
	if _current_horse != null and is_instance_valid(_current_horse):
		stolen_name = String(_current_horse.name)
		_current_horse_last_position = _current_horse.global_position
	_steal_current_horse()

	var away_dir := global_position - _current_horse_last_position
	away_dir.y = 0.0
	if away_dir.length() < 0.1:
		away_dir = -global_transform.basis.z
	_retreat_dir = away_dir.normalized()
	_retreat_target = global_position + _retreat_dir * steal_retreat_distance
	_steal_retreat_timer = steal_retreat_duration
	_state = AlbastyState.STEALING_RETREAT
	_debug_print("ALBASY: horse stolen %s" % stolen_name)


func _steal_current_horse() -> void:
	if _current_horse == null or not is_instance_valid(_current_horse):
		return

	_current_horse.set_meta("stolen", true)
	_current_horse.visible = false
	_disable_collision_recursive(_current_horse)
	stolen_horse_count += 1
	_current_horse = null


func _update_stealing_retreat(delta: float) -> void:
	global_position = global_position.move_toward(_retreat_target, steal_retreat_speed * delta)
	_slow_look_at(global_position - _retreat_dir, delta)
	_steal_retreat_timer -= delta
	if global_position.distance_to(_retreat_target) <= 0.15 or _steal_retreat_timer <= 0.0:
		_hide_after_steal()


func _hide_after_steal() -> void:
	_state = AlbastyState.HIDDEN_AFTER_STEAL
	_hide_timer = steal_hide_duration
	visible = false
	_set_interaction_enabled(false)
	_set_collision_enabled(false)
	_debug_print("ALBASY: hidden for %.1f seconds" % steal_hide_duration)


func _update_hidden_after_steal(delta: float) -> void:
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		_return_after_steal()


func _return_after_steal() -> void:
	if _has_spawn_position:
		global_position = _spawn_position
	visible = true
	_set_interaction_enabled(true)
	_set_collision_enabled(true)
	_state = AlbastyState.IDLE
	_debug_print("ALBASY: returning")


func _update_approach_yurt(delta: float) -> void:
	if _yurt_target == null or not is_instance_valid(_yurt_target):
		_yurt_target = _get_yurt_entrance()
		if _yurt_target == null:
			_state = AlbastyState.IDLE
			return

	var to_yurt := _yurt_target.global_position - global_position
	to_yurt.y = 0.0
	var distance := to_yurt.length()
	if distance <= yurt_stop_distance:
		_state = AlbastyState.YURT_REACHED
		_debug_print("ALBASY: reached yurt entrance")
		return

	var direction := to_yurt.normalized()
	global_position += direction * yurt_approach_speed * delta
	_slow_look_at(global_position + direction, delta)


func _process_repelled(delta: float) -> void:
	global_position += _retreat_dir * retreat_speed * delta
	_slow_look_at(global_position - _retreat_dir, delta)
	_retreat_timer -= delta
	if _retreat_timer <= 0.0:
		queue_free()


func _process_peaceful_powerline(delta: float) -> void:
	var marker := _get_peaceful_powerline_marker()
	if marker != null:
		global_position = global_position.move_toward(marker.global_position, move_speed * 0.35 * delta)
	_slow_look_at(global_position + Vector3(0.0, 0.0, -1.0), delta)


func _get_available_horses() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("horse"):
		if not is_instance_valid(node):
			continue
		var horse := node as Node3D
		if not _is_valid_horse(horse):
			continue
		result.append(horse)
	return result


func _choose_next_horse() -> Node3D:
	var horses := _get_available_horses()
	if horses.is_empty():
		return null

	var best: Node3D = null
	var best_distance := INF
	for horse in horses:
		var distance := global_position.distance_to(horse.global_position)
		if distance < best_distance:
			best_distance = distance
			best = horse
	return best


func _is_valid_horse(horse: Node3D) -> bool:
	if horse == null or not is_instance_valid(horse):
		return false
	if not horse.visible:
		return false
	if horse.has_meta("stolen") and bool(horse.get_meta("stolen")):
		return false
	return true


func _get_yurt_entrance() -> Node3D:
	for node in get_tree().get_nodes_in_group("yurt_entrance"):
		var marker := node as Node3D
		if marker != null:
			return marker
	return null


func _get_peaceful_powerline_marker() -> Node3D:
	for node in get_tree().get_nodes_in_group("albasty_peace_marker"):
		var marker := node as Node3D
		if marker != null:
			return marker
	return null


func _disable_collision_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	for child in node.get_children():
		_disable_collision_recursive(child)


func _set_interaction_enabled(enabled: bool) -> void:
	for child in get_children():
		_set_interaction_enabled_recursive(child, enabled)


func _set_interaction_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is Area3D:
		var area := node as Area3D
		area.monitoring = enabled
		area.monitorable = enabled
	for child in node.get_children():
		_set_interaction_enabled_recursive(child, enabled)


func _set_collision_enabled(enabled: bool) -> void:
	_set_collision_enabled_recursive(self, enabled)


func _set_collision_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	elif node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 1 if enabled else 0
		collision_object.collision_mask = 1 if enabled else 0

	for child in node.get_children():
		_set_collision_enabled_recursive(child, enabled)


func _slow_look_at(world_target: Vector3, delta: float) -> void:
	var flat_target := world_target
	flat_target.y = global_position.y
	var direction := flat_target - global_position
	if direction.length() < 0.001:
		return
	var desired_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clamp(turn_speed * delta, 0.0, 1.0))


func _show_scare_window() -> void:
	var scare_window := get_tree().get_first_node_in_group("albasty_scare_window")
	if scare_window != null and scare_window.has_method("show_667"):
		scare_window.call("show_667")


func _debug_print(message: String) -> void:
	if debug_albasty_horse_ai:
		print(message)
