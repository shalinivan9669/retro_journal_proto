extends Node3D
class_name AlbastySpawner

@export var albasty_model: PackedScene = preload("res://assets/models/albasty_lowpoly.glb")
@export var spawn_point_path: NodePath
@export var target_path: NodePath
@export var player_path: NodePath
@export var spawn_delay: float = 2.0
@export var respawn_delay: float = 35.0
@export var max_alive: int = 1
@export var spawn_on_ready: bool = true
@export var repeat_spawn: bool = true
@export var model_scale: float = 3.5

var _timer := 0.0
var _active_albasty: Node3D


func _ready() -> void:
	_timer = spawn_delay
	if spawn_on_ready and spawn_delay <= 0.0:
		spawn_albasty()


func _process(delta: float) -> void:
	if not spawn_on_ready:
		return
	if _active_albasty != null and not is_instance_valid(_active_albasty):
		_active_albasty = null
		_timer = respawn_delay

	if _count_alive() >= max_alive or _active_albasty != null:
		return
	_timer -= delta
	if _timer <= 0.0:
		var spawned := spawn_albasty()
		if spawned == null:
			_timer = respawn_delay
		elif not repeat_spawn:
			spawn_on_ready = false


func spawn_albasty() -> Node3D:
	if _count_alive() >= max_alive:
		return null

	var parent_node := get_parent()
	if parent_node == null:
		parent_node = self

	var albasty := Node3D.new()
	albasty.name = "Albasty"
	albasty.set_script(preload("res://scripts/albasty_controller.gd"))
	albasty.set("target_path", target_path)
	albasty.set("player_path", player_path)
	parent_node.add_child(albasty)
	_active_albasty = albasty
	if albasty.has_signal("scared_away"):
		albasty.scared_away.connect(_on_albasty_finished)
	if albasty.has_signal("reached_horse_zone"):
		albasty.reached_horse_zone.connect(_on_albasty_finished)
	albasty.tree_exited.connect(_on_albasty_tree_exited.bind(albasty))

	var spawn_point := get_node_or_null(spawn_point_path) as Node3D
	if spawn_point != null:
		albasty.global_transform = spawn_point.global_transform
	else:
		albasty.global_position = global_position

	var model := albasty_model.instantiate()
	model.name = "AlbastyModel"
	if model is Node3D:
		(model as Node3D).scale = Vector3.ONE * model_scale
	albasty.add_child(model)

	var detection_area := Area3D.new()
	detection_area.name = "AlbastyInteractionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	albasty.add_child(detection_area)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8.0
	capsule.height = 12.0
	shape.shape = capsule
	shape.position = Vector3(0.0, 5.0, 0.0)
	detection_area.add_child(shape)

	return albasty


func _on_albasty_finished() -> void:
	if repeat_spawn:
		_timer = respawn_delay


func _on_albasty_tree_exited(albasty: Node3D) -> void:
	if _active_albasty == albasty:
		_active_albasty = null
	if repeat_spawn and spawn_on_ready:
		_timer = respawn_delay


func _count_alive() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("albasty"):
		if is_instance_valid(node):
			count += 1
	return count
