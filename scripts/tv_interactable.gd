extends StaticBody3D

@export_multiline var dialogue_text: String = "Interactive television."


func interact(dialogue_ui: Node) -> void:
	var manager := _get_signal_manager()
	if manager == null:
		_show_dialogue(dialogue_ui, "TV signal manager is missing.")
		return

	var current: int = int(manager.call("get_tv_channel"))
	manager.call("set_tv_channel", current + 1)
	_show_dialogue(dialogue_ui, String(manager.call("get_tv_status_text")))


func trigger_signal(dialogue_ui: Node) -> void:
	var manager := _get_signal_manager()
	if manager == null:
		_show_dialogue(dialogue_ui, "TV signal manager is missing.")
		return

	var triggered: bool = bool(manager.call("trigger_from_tv"))
	if not triggered:
		_show_dialogue(dialogue_ui, "TV CH %02d + RADIO FR %02d\nСигнал не совпал." % [
			int(manager.call("get_tv_channel")),
			int(manager.call("get_radio_frequency"))
		])


func _get_signal_manager() -> Node:
	return get_tree().get_first_node_in_group("signal_state_manager")


func _show_dialogue(dialogue_ui: Node, text: String) -> void:
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", text)
