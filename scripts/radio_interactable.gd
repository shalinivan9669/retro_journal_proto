extends StaticBody3D

const RADIO_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/radio/radio_fr_01_white_noise.wav"),
	preload("res://assets/audio/radio/radio_fr_02_wind.wav"),
	preload("res://assets/audio/radio/radio_fr_03_electric_hum.wav"),
	preload("res://assets/audio/radio/radio_fr_04_drops.wav"),
	preload("res://assets/audio/radio/radio_fr_05_far_voices.wav"),
	preload("res://assets/audio/radio/radio_fr_06_clean_tone.wav"),
	preload("res://assets/audio/radio/radio_fr_07_hidden.wav"),
	preload("res://assets/audio/radio/radio_fr_08_subfloor.wav"),
	preload("res://assets/audio/radio/radio_fr_09_empty.wav")
]

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D


func interact(dialogue_ui: Node) -> void:
	var manager := _get_signal_manager()
	if manager == null:
		_show_dialogue(dialogue_ui, "Radio signal manager is missing.")
		return

	var current: int = int(manager.call("get_radio_frequency"))
	manager.call("set_radio_frequency", current + 1)
	_play_frequency(int(manager.call("get_radio_frequency")))
	var triggered: bool = bool(manager.call("trigger_from_radio"))
	if not triggered:
		_show_dialogue(dialogue_ui, String(manager.call("get_radio_status_text")))


func _get_signal_manager() -> Node:
	return get_tree().get_first_node_in_group("signal_state_manager")


func _show_dialogue(dialogue_ui: Node, text: String) -> void:
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", text)


func _play_frequency(frequency: int) -> void:
	var index := clampi(frequency - 1, 0, RADIO_STREAMS.size() - 1)
	audio_player.stream = RADIO_STREAMS[index]
	audio_player.play()
