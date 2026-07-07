extends Node

const TV_CHANNEL_COUNT := 6
const RADIO_FREQUENCY_COUNT := 9

const SOURCE_TV := "TV"
const SOURCE_RADIO := "RADIO"

var current_tv_channel: int = 1
var current_radio_frequency: int = 1
var temporary_door_available: bool = false


func _ready() -> void:
	add_to_group("signal_state_manager")


func set_tv_channel(value: int) -> void:
	current_tv_channel = wrapi(value - 1, 0, TV_CHANNEL_COUNT) + 1


func set_radio_frequency(value: int) -> void:
	current_radio_frequency = wrapi(value - 1, 0, RADIO_FREQUENCY_COUNT) + 1


func get_tv_channel() -> int:
	return current_tv_channel


func get_radio_frequency() -> int:
	return current_radio_frequency


func trigger_from_tv() -> bool:
	return evaluate_combo(SOURCE_TV)


func trigger_from_radio() -> bool:
	return evaluate_combo(SOURCE_RADIO)


func evaluate_combo(trigger_source: String) -> bool:
	var source := trigger_source.to_upper()

	if source == SOURCE_TV and current_tv_channel == 5 and current_radio_frequency == 2:
		_play_cube_memory_cutscene()
		return true

	if source == SOURCE_RADIO and current_tv_channel == 2 and current_radio_frequency == 3:
		_activate_temporary_door()
		return true

	if source == SOURCE_TV and current_tv_channel == 1 and current_radio_frequency == 7:
		_show_signal_dialogue("Сигнал уже был здесь.")
		return true

	if source == SOURCE_TV and current_tv_channel == 3 and current_radio_frequency == 5:
		_show_signal_dialogue("Степь слышит небо.")
		return true

	if source == SOURCE_TV and current_tv_channel == 4 and current_radio_frequency == 8:
		_show_signal_dialogue("Под полом есть влага.")
		return true

	if source == SOURCE_RADIO and current_tv_channel == 6 and current_radio_frequency == 9:
		_show_signal_dialogue("Не все двери стоят в стенах.")
		return true

	return false


func get_tv_status_text() -> String:
	match current_tv_channel:
		1:
			return "TV CH 01\nСнег на экране складывается в старую рябь.\nF - подтвердить сигнал."
		2:
			return "TV CH 02\nСтепь, ЛЭП и пепельная линия горизонта.\nF - подтвердить сигнал."
		3:
			return "TV CH 03\nПлохой сигнал похож на память.\nF - подтвердить сигнал."
		4:
			return "TV CH 04\nПочти пустой канал. Внизу слышится влага.\nF - подтвердить сигнал."
		5:
			return "TV CH 05\nКанал ждёт правильную радиочастоту.\nF - подтвердить сигнал."
		6:
			return "TV CH 06\nТёмная несущая частота дрожит без изображения.\nF - подтвердить сигнал."
	return "TV CH %02d\nF - подтвердить сигнал." % current_tv_channel


func get_radio_status_text() -> String:
	match current_radio_frequency:
		1:
			return "RADIO FR 01\nБелый шум."
		2:
			return "RADIO FR 02\nСкрипка идёт через динамик слишком близко."
		3:
			return "RADIO FR 03\nНизкое радио с Нуркена Абдирова держит дверь на краю."
		4:
			return "RADIO FR 04\nКапли. Подземная влага."
		5:
			return "RADIO FR 05\nДревний гул почти совпал."
		6:
			return "RADIO FR 06\nЧистый неприятный тон."
		7:
			return "RADIO FR 07\nЧистая запись проступает сквозь скрытую частоту."
		8:
			return "RADIO FR 08\nСигнал идёт из-под пола."
		9:
			return "RADIO FR 09\nПустота не совсем молчит."
	return "RADIO FR %02d" % current_radio_frequency


func _play_cube_memory_cutscene() -> void:
	var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui != null and dialogue_ui.has_method("hide_message"):
		dialogue_ui.call("hide_message")

	var cutscene_ui := get_tree().get_first_node_in_group("cube_memory_cutscene_ui")
	if cutscene_ui != null and cutscene_ui.has_method("play_cutscene"):
		cutscene_ui.call("play_cutscene")


func _activate_temporary_door() -> void:
	temporary_door_available = true
	var door := get_tree().get_first_node_in_group("temporary_signal_door")
	if door != null and door.has_method("activate_door"):
		door.call("activate_door")

	var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", "RADIO FR 03\nДверь появилась у стены.")


func _show_signal_dialogue(text: String) -> void:
	var signal_window := get_tree().get_first_node_in_group("signal_dialogue_window")
	if signal_window == null or not signal_window.has_method("show_signal_message"):
		return
	if signal_window.has_method("is_open") and bool(signal_window.call("is_open")):
		return
	signal_window.call("show_signal_message", text)
