extends Node3D

@export var return_scene_path: String = "res://scenes/Main.tscn"
@export var rush_timeout: float = 4.5

var soldiers: Array[Node3D] = []
var _player: Node3D
var _triggered := false
var _finishing := false
var _rush_elapsed := -1.0


func setup(spawned_soldiers: Array[Node3D], trigger_size: Vector3, target_scene: String) -> void:
	soldiers = spawned_soldiers
	return_scene_path = target_scene
	_player = get_tree().get_first_node_in_group("player") as Node3D

	for soldier in soldiers:
		if soldier == null:
			continue
		if soldier.has_method("set_target"):
			soldier.call("set_target", _player)
		if soldier.has_signal("caught_player"):
			soldier.connect("caught_player", Callable(self, "_finish_event"))

	_build_trigger(trigger_size)


func _process(delta: float) -> void:
	if _rush_elapsed < 0.0 or _finishing:
		return

	_rush_elapsed += delta
	if _rush_elapsed >= rush_timeout:
		_finish_event()


func _build_trigger(trigger_size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "FinalSoldierRoomTrigger"
	area.monitoring = true
	area.body_entered.connect(_on_trigger_body_entered)
	add_child(area)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = trigger_size
	collision.shape = shape
	area.add_child(collision)


func _on_trigger_body_entered(body: Node) -> void:
	if _triggered:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if body != _player:
		return

	_triggered = true
	_begin_rush_sequence()


func _begin_rush_sequence() -> void:
	await get_tree().create_timer(1.1).timeout
	if _finishing:
		return

	var delays := [0.0, 0.12, 0.22, 0.31, 0.4]
	for index in range(soldiers.size()):
		var soldier := soldiers[index]
		if soldier == null or not is_instance_valid(soldier):
			continue
		if soldier.has_method("start_rush"):
			soldier.call("start_rush", delays[index % delays.size()])

	_rush_elapsed = 0.0


func _finish_event() -> void:
	if _finishing:
		return

	_finishing = true
	if _player != null:
		_player.set("controls_locked", true)

	var layer := CanvasLayer.new()
	layer.name = "FinalSoldierHardCut"
	layer.layer = 100
	add_child(layer)

	var rect := ColorRect.new()
	rect.name = "Blackout"
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

	var tween := create_tween()
	tween.tween_property(rect, "color", Color(0.0, 0.0, 0.0, 1.0), 0.28)
	await tween.finished
	get_tree().change_scene_to_file(return_scene_path)
