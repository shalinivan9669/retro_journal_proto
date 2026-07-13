extends Node

signal state_changed(previous: FlowState, current: FlowState)
signal run_reset

enum FlowState {
	NIGHT_DRIVE,
	DINER_ARRIVAL,
	DINER_ENTERING,
	DINER_AT_COUNTER,
	DINER_MENU,
	DINER_GOING_TO_TABLE,
	DINER_WAITING_FOR_FOOD,
	DINER_FOOD_DELIVERED,
	DINER_EATING,
	DINER_AFTER_MEAL,
	RESTROOM_INSIDE,
	BACK_IN_CAR,
	FOREST_DRIVE,
	RABBIT_EVENT,
	DEMO_COMPLETE,
}

const NIGHT_DRIVE_SCENE := "res://scenes/lost_signal/road/NightDrive.tscn"
const DINER_SCENE := "res://scenes/lost_signal/diner/DinerSequence.tscn"
const RESTROOM_SCENE := "res://scenes/lost_signal/restroom/Restroom.tscn"
const FOREST_SCENE := "res://scenes/lost_signal/forest/ForestRoad.tscn"

var state: FlowState = FlowState.NIGHT_DRIVE
var selected_order: StringName = &""
var meal_finished := false
var restroom_visited := false
var washed_face := false
var dashcam_viewed := false
var rabbit_event_seen := false
var transition_in_progress := false
var run_started_msec := 0
var qa_enabled := false
var qa_run := 0
var _transition_previous_state: FlowState = FlowState.NIGHT_DRIVE


func _ready() -> void:
	_read_qa_arguments()
	_ensure_audio_buses()
	LostSignalSceneLoader.load_finished.connect(_on_load_finished)
	LostSignalSceneLoader.load_failed.connect(_on_load_failed)


func start_new_run() -> void:
	selected_order = &""
	meal_finished = false
	restroom_visited = false
	washed_face = false
	dashcam_viewed = false
	rabbit_event_seen = false
	transition_in_progress = false
	run_started_msec = Time.get_ticks_msec()
	LostSignalInputLock.clear()
	set_state(FlowState.NIGHT_DRIVE)
	run_reset.emit()


func set_state(next_state: FlowState) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	if qa_enabled:
		print("LOST_SIGNAL_QA_STATE ", FlowState.keys()[previous], " -> ", FlowState.keys()[state])
	state_changed.emit(previous, state)


func transition_to(path: String, next_state: FlowState) -> bool:
	if transition_in_progress or LostSignalSceneLoader.is_loading():
		return false
	transition_in_progress = true
	_transition_previous_state = state
	set_state(next_state)
	if not LostSignalSceneLoader.transition_to(path):
		transition_in_progress = false
		return false
	return true


func select_order(order_id: StringName) -> bool:
	if selected_order != &"" or order_id not in [&"lagman", &"cutlet", &"eggs"]:
		return false
	selected_order = order_id
	return true


func order_display_name() -> String:
	match selected_order:
		&"lagman": return "Лагман"
		&"cutlet": return "Котлета с картофелем"
		&"eggs": return "Яичница с колбасой"
		_: return ""


func elapsed_seconds() -> float:
	if run_started_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - run_started_msec) / 1000.0


func _on_load_finished(_path: String) -> void:
	transition_in_progress = false
	_transition_previous_state = state


func _on_load_failed(_path: String, _message: String) -> void:
	transition_in_progress = false
	set_state(_transition_previous_state)


func _ensure_audio_buses() -> void:
	for bus_name in [&"Ambience", &"Vehicle", &"InteriorRoom", &"SFX", &"UI", &"Dialogue"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var room_index := AudioServer.get_bus_index(&"InteriorRoom")
	if room_index >= 0 and AudioServer.get_bus_effect_count(room_index) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.38
		reverb.damping = 0.72
		reverb.wet = 0.16
		reverb.dry = 0.92
		AudioServer.add_bus_effect(room_index, reverb)


func _read_qa_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--lost-signal-qa="):
			qa_run = int(argument.get_slice("=", 1))
			qa_enabled = qa_run in [1, 2, 3]
	if qa_enabled:
		Engine.time_scale = 4.0
		print("LOST_SIGNAL_QA_START run=", qa_run)
