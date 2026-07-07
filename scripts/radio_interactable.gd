extends StaticBody3D

const RADIO_STREAM_PATHS: Array[String] = [
	"res://assets/audio/radio/radio_fr_01_white_noise.wav",
	"res://assets/audio/radio/radio_custom_cinematic_violin.ogg",
	"res://assets/audio/radio/radio_custom_nurken_abdirov_13_radio_lq.ogg",
	"res://assets/audio/radio/radio_fr_04_drops.wav",
	"res://assets/audio/radio/radio_custom_ancient_ambient.ogg",
	"res://assets/audio/radio/radio_fr_06_clean_tone.wav",
	"res://assets/audio/radio/radio_custom_nurken_abdirov_13.ogg",
	"res://assets/audio/radio/radio_fr_08_subfloor.wav",
	"res://assets/audio/radio/radio_fr_09_empty.wav"
]

const RADIO_FALLBACK_STREAM_PATHS: Array[String] = [
	"res://assets/audio/radio/radio_fr_01_white_noise.wav",
	"res://assets/audio/radio/radio_fr_02_wind.wav",
	"res://assets/audio/radio/radio_fr_03_electric_hum.wav",
	"res://assets/audio/radio/radio_fr_04_drops.wav",
	"res://assets/audio/radio/radio_fr_05_far_voices.wav",
	"res://assets/audio/radio/radio_fr_06_clean_tone.wav",
	"res://assets/audio/radio/radio_fr_07_hidden.wav",
	"res://assets/audio/radio/radio_fr_08_subfloor.wav",
	"res://assets/audio/radio/radio_fr_09_empty.wav"
]

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D


func _ready() -> void:
	audio_player.finished.connect(_on_audio_finished)
	if not _is_headless():
		call_deferred("_play_initial_frequency")


func _exit_tree() -> void:
	if audio_player != null:
		audio_player.stop()
		audio_player.stream = null


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
	if _is_headless():
		return
	var index := clampi(frequency - 1, 0, RADIO_STREAM_PATHS.size() - 1)
	var stream := _load_stream_for_index(index)
	if stream == null:
		return
	audio_player.stream = stream
	audio_player.play()


func _play_initial_frequency() -> void:
	var manager := _get_signal_manager()
	var frequency := 1
	if manager != null:
		frequency = int(manager.call("get_radio_frequency"))
	_play_frequency(frequency)


func _load_stream_for_index(index: int) -> AudioStream:
	var path := RADIO_STREAM_PATHS[index]
	if not ResourceLoader.exists(path):
		push_warning("Radio stream missing, using fallback: " + path)
		path = RADIO_FALLBACK_STREAM_PATHS[index]

	if not ResourceLoader.exists(path):
		push_warning("Radio fallback stream missing: " + path)
		return null

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Radio stream failed to load: " + path)
	return stream


func _on_audio_finished() -> void:
	if audio_player.stream != null:
		audio_player.play()


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
