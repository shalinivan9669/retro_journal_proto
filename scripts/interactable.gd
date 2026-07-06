extends StaticBody3D

@export_multiline var dialogue_text: String = "Interactive object."
@export_file("*.tscn") var target_scene_path: String = ""
@export var transition_delay: float = 0.0
@export var starts_cube_memory_cutscene: bool = false

var _transition_started := false


func interact(dialogue_ui: Node) -> void:
	if starts_cube_memory_cutscene:
		if dialogue_ui != null and dialogue_ui.has_method("hide_message"):
			dialogue_ui.call("hide_message")
		var cutscene_ui := get_tree().get_first_node_in_group("cube_memory_cutscene_ui")
		if cutscene_ui != null and cutscene_ui.has_method("play_cutscene"):
			cutscene_ui.call("play_cutscene")
			return

	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", dialogue_text)

	if target_scene_path.is_empty() or _transition_started:
		return

	_transition_started = true
	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	get_tree().change_scene_to_file(target_scene_path)
