extends Node

const NIGHT_DRIVE_SCENE := "res://scenes/lost_signal/road/NightDrive.tscn"
const DINER_SCENE := "res://scenes/lost_signal/diner/DinerSequence.tscn"
const RESTROOM_SCENE := "res://scenes/lost_signal/restroom/Restroom.tscn"
const FOREST_SCENE := "res://scenes/lost_signal/forest/ForestRoad.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"
const STEPPE_WOLF_SCENE := "res://scenes/cutscenes/SteppeWolf.tscn"
const BARRAGE_SCENE := "res://addons/archive_barrage/scenes/ArchiveNightBarrage.tscn"
const QUMRAN_SCENE := "res://scenes/debug/qumran_location_test.tscn"
const DEBUG_OPEN_QUMRAN_ACTION := &"debug_open_qumran_location"
const DEBUG_RETURN_ACTION := &"debug_return_from_test_scene"

const SCENE_BY_KEY := {
	KEY_F1: NIGHT_DRIVE_SCENE,
	KEY_F2: DINER_SCENE,
	KEY_F3: RESTROOM_SCENE,
	KEY_F4: FOREST_SCENE,
	KEY_F5: MAIN_SCENE,
	KEY_F6: STEPPE_WOLF_SCENE,
	KEY_F9: BARRAGE_SCENE,
}

var _pending_keycode: Key = KEY_NONE
var _pending_scene_path := ""
var _debug_previous_scene_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LostSignalSceneLoader.load_finished.connect(_on_scene_load_finished)


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed(DEBUG_OPEN_QUMRAN_ACTION):
		get_viewport().set_input_as_handled()
		_open_qumran_scene()
		return
	if key_event.is_action_pressed(DEBUG_RETURN_ACTION) and _is_qumran_scene_active():
		get_viewport().set_input_as_handled()
		_return_from_qumran_scene()
		return
	if not SCENE_BY_KEY.has(key_event.keycode):
		return
	get_viewport().set_input_as_handled()
	_switch_scene(key_event.keycode, String(SCENE_BY_KEY[key_event.keycode]))


func _switch_scene(keycode: Key, scene_path: String) -> void:
	if LostSignalSceneLoader.is_loading():
		_pending_keycode = keycode
		_pending_scene_path = scene_path
		return
	_prepare_flow_for_scene(keycode)
	LostSignalInputLock.clear()
	LostSignalFlow.transition_in_progress = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if keycode == KEY_F6 else Input.MOUSE_MODE_CAPTURED
	if not LostSignalSceneLoader.transition_to(scene_path):
		push_error("SceneHotkeySwitcher: could not load " + scene_path)


func _on_scene_load_finished(_loaded_path: String) -> void:
	if _pending_scene_path.is_empty():
		return
	var keycode := _pending_keycode
	var scene_path := _pending_scene_path
	_pending_keycode = KEY_NONE
	_pending_scene_path = ""
	_switch_scene.call_deferred(keycode, scene_path)


func _open_qumran_scene() -> void:
	if not ResourceLoader.exists(QUMRAN_SCENE, "PackedScene"):
		push_error("SceneHotkeySwitcher: Qumran scene is missing: " + QUMRAN_SCENE)
		return
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var current_path := current_scene.scene_file_path
		if not current_path.is_empty() and current_path != QUMRAN_SCENE:
			_debug_previous_scene_path = current_path
	_switch_scene(KEY_F12, QUMRAN_SCENE)


func _return_from_qumran_scene() -> void:
	var target_path := _debug_previous_scene_path
	if target_path.is_empty() or not ResourceLoader.exists(target_path, "PackedScene"):
		target_path = MAIN_SCENE
	_switch_scene(KEY_F11, target_path)


func _is_qumran_scene_active() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.scene_file_path == QUMRAN_SCENE


func _prepare_flow_for_scene(keycode: Key) -> void:
	match keycode:
		KEY_F1:
			LostSignalFlow.start_new_run()
		KEY_F2:
			LostSignalFlow.start_new_run()
			LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_ENTERING)
		KEY_F3:
			LostSignalFlow.start_new_run()
			LostSignalFlow.select_order(&"lagman")
			LostSignalFlow.meal_finished = true
			LostSignalFlow.set_state(LostSignalFlow.FlowState.RESTROOM_INSIDE)
		KEY_F4:
			LostSignalFlow.start_new_run()
			LostSignalFlow.set_state(LostSignalFlow.FlowState.FOREST_DRIVE)
