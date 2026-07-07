extends StaticBody3D

@export_file("*.tscn") var target_scene_path: String = "res://scenes/levels/InfiniteRoad.tscn"
@export var transition_delay: float = 0.2

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _transition_started := false


func _ready() -> void:
	add_to_group("temporary_signal_door")
	deactivate_door()


func activate_door() -> void:
	_transition_started = false
	visible = true
	collision_shape.disabled = false


func deactivate_door() -> void:
	visible = false
	collision_shape.disabled = true


func interact(dialogue_ui: Node) -> void:
	if _transition_started or not visible:
		return

	_transition_started = true
	deactivate_door()
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", "Дверь открылась. За ней дорога, которая не заканчивается.")

	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	get_tree().change_scene_to_file(target_scene_path)
