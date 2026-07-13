extends CanvasLayer

signal load_started(path: String)
signal load_progress(path: String, progress: float)
signal load_failed(path: String, message: String)
signal load_finished(path: String)

const LOCK_OWNER: StringName = &"lost_signal_scene_loader"

var _path := ""
var _loading := false
var _overlay: ColorRect
var _title: Label
var _progress_bar: ProgressBar


func _ready() -> void:
	layer = 190
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(false)


func transition_to(path: String) -> bool:
	if _loading or path.is_empty():
		return false
	var error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if error != OK:
		load_failed.emit(path, "ResourceLoader error %d" % error)
		return false
	_loading = true
	_path = path
	LostSignalInputLock.acquire(LOCK_OWNER)
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_progress_bar.value = 0.0
	_title.text = "ЗАГРУЗКА СИГНАЛА"
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.16)
	load_started.emit(path)
	set_process(true)
	return true


func _process(_delta: float) -> void:
	if not _loading:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress)
	var amount := float(progress[0]) if not progress.is_empty() else 0.0
	_progress_bar.value = amount * 100.0
	load_progress.emit(_path, amount)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish_load()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_load("Threaded load failed for %s" % _path)


func _finish_load() -> void:
	set_process(false)
	var scene := ResourceLoader.load_threaded_get(_path) as PackedScene
	if scene == null:
		_fail_load("Loaded resource is not a PackedScene: %s" % _path)
		return
	var completed_path := _path
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		_fail_load("Scene change error %d: %s" % [error, completed_path])
		return
	# Scene changes are applied at frame boundaries. Keep the transition lock and
	# loading cover until the new root has completed _ready().
	await get_tree().process_frame
	await get_tree().process_frame
	_loading = false
	_path = ""
	LostSignalInputLock.release_all(LOCK_OWNER)
	load_finished.emit(completed_path)
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.24)
	await tween.finished
	_overlay.visible = false


func _fail_load(message: String) -> void:
	var failed_path := _path
	_loading = false
	_path = ""
	set_process(false)
	LostSignalInputLock.release_all(LOCK_OWNER)
	_title.text = "ОШИБКА ЗАГРУЗКИ"
	load_failed.emit(failed_path, message)
	push_error(message)
	await get_tree().create_timer(1.4).timeout
	_overlay.visible = false


func is_loading() -> bool:
	return _loading


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "LostSignalLoadingOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.008, 0.012, 0.021, 1.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-210.0, -35.0)
	center.size = Vector2(420.0, 90.0)
	center.add_theme_constant_override("separation", 14)
	_overlay.add_child(center)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.74, 0.86, 0.92))
	center.add_child(_title)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(420.0, 8.0)
	_progress_bar.show_percentage = false
	center.add_child(_progress_bar)
