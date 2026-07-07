extends StaticBody3D

@export_multiline var dialogue_text: String = "Наверх."
@export_file("*.tscn") var target_scene_path: String = "res://scenes/Main.tscn"
@export var transition_delay: float = 0.25

var _transition_started := false


func interact(dialogue_ui: Node) -> void:
	if _transition_started:
		return

	_transition_started = true
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", dialogue_text)

	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	get_tree().change_scene_to_file(target_scene_path)
