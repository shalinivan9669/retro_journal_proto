extends StaticBody3D

@export_multiline var dialogue_text: String = "Под полом влажно."
@export_file("*.tscn") var target_scene_path: String = "res://scenes/levels/UndergroundSteppe.tscn"
@export var transition_delay: float = 0.55
@export var locked_by_cover_text: String = "Под ковром что-то твердое. Сначала нужно убрать ткань."
@export var cover_group_name: String = "hatch_cover"

var _transition_started := false


func interact(dialogue_ui: Node) -> void:
	if _transition_started:
		return
	if _is_locked_by_cover():
		if dialogue_ui != null and dialogue_ui.has_method("show_message"):
			dialogue_ui.call("show_message", locked_by_cover_text)
		return

	_transition_started = true
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", dialogue_text)

	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	get_tree().change_scene_to_file(target_scene_path)


func _is_locked_by_cover() -> bool:
	for cover: Node in get_tree().get_nodes_in_group(cover_group_name):
		if cover.has_method("is_cover_removed") and not bool(cover.call("is_cover_removed")):
			return true
	return false
