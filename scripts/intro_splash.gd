extends CanvasLayer

@export var display_duration: float = 0.8
@export var max_font_size: int = 96
@export var min_font_size: int = 48

@onready var label: Label = $TextMargin/IntroLabel

var _timer := 0.0
var _active := false
var _player: Node = null
var _aim_dot_ui: Node = null
var _previous_player_lock := false
var _video_player: VideoStreamPlayer
var _overlay: ColorRect
var _video_finished_callback: Callable
var _sequence_running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("intro_splash")
	get_viewport().size_changed.connect(_resize_text)
	_resize_text()
	call_deferred("show_intro")


func _input(_event: InputEvent) -> void:
	if _active or _sequence_running:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active or _sequence_running:
		return

	_timer -= delta
	if _timer <= 0.0:
		_finish_intro()


func show_intro() -> void:
	if _sequence_running:
		return
	_sequence_running = true
	_active = true
	visible = true
	_lock_player()
	_run_intro_sequence()

func _run_intro_sequence() -> void:
	await _flash_frame(Color.BLACK, Color.WHITE, 0.34)
	await _flash_frame(Color.WHITE, Color.BLACK, 0.34)
	await _flash_frame(Color.BLACK, Color.WHITE, 0.34)
	await _play_video_sequence("res://assets/videos/cutscenes/menu.ogv")
	await _play_video_sequence("res://assets/videos/cutscenes/road.ogv")
	_finish_intro()

func _flash_frame(background: Color, foreground: Color, duration: float) -> void:
	if _overlay == null:
		_overlay = ColorRect.new()
		overlay_setup()
	_overlay.color = background
	_overlay.visible = true
	$TextMargin.visible = false
	var flash_label := _overlay.get_node_or_null("FlashLabel") as Label
	if flash_label == null:
		flash_label = Label.new()
		flash_label.name = "FlashLabel"
		flash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		flash_label.add_theme_font_size_override("font_size", 72)
		_overlay.add_child(flash_label)
	flash_label.modulate = foreground
	flash_label.text = "FLASH WARNING !"
	await get_tree().create_timer(duration).timeout

func overlay_setup() -> void:
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _play_video_sequence(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	if _overlay == null:
		_overlay = ColorRect.new()
		overlay_setup()
	_overlay.color = Color.BLACK
	_overlay.visible = true
	$TextMargin.visible = false
	if _video_player == null:
		_video_player = VideoStreamPlayer.new()
		_video_player.name = "IntroVideoPlayer"
		_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_video_player.expand = true
		_video_player.loop = false
		_overlay.add_child(_video_player)
	if _video_player.is_connected("finished", _on_video_finished):
		_video_player.disconnect("finished", _on_video_finished)
	_video_player.stream = load(path) as VideoStream
	if _video_player.stream == null:
		return
	_video_finished_callback = Callable()
	_video_player.finished.connect(_on_video_finished)
	_video_player.play()
	await _video_player.finished

func _on_video_finished() -> void:
	pass

func play_cutscene(path: String, callback: Callable = Callable()) -> void:
	if _sequence_running:
		return
	_sequence_running = true
	_active = true
	visible = true
	_lock_player()
	await _flash_frame(Color.BLACK, Color.WHITE, 0.26)
	await _flash_frame(Color.WHITE, Color.BLACK, 0.26)
	await _flash_frame(Color.BLACK, Color.WHITE, 0.26)
	await _play_video_sequence(path)
	_finish_intro()
	if callback.is_valid():
		callback.call()


func _finish_intro() -> void:
	_active = false
	_sequence_running = false
	visible = false
	if _video_player != null:
		_video_player.stop()
	if _overlay != null:
		_overlay.visible = false
	$TextMargin.visible = true
	_unlock_player()


func _lock_player() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	_player = scene.get_node_or_null("Player")
	if _player != null:
		_previous_player_lock = bool(_player.get("controls_locked"))
		_player.set("controls_locked", true)
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO

	_aim_dot_ui = scene.get_node_or_null("AimDotUI")
	if _aim_dot_ui != null:
		_aim_dot_ui.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _unlock_player() -> void:
	if _player != null:
		_player.set("controls_locked", _previous_player_lock)
	if _aim_dot_ui != null:
		_aim_dot_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _resize_text() -> void:
	if label == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var max_line_chars := 43.0
	var target_width := viewport_size.x * 0.9
	var font_size := int(floor(target_width / (max_line_chars * 0.52)))
	font_size = clampi(font_size, min_font_size, max_font_size)
	label.label_settings.font_size = font_size
	label.label_settings.line_spacing = int(round(float(font_size) * 0.24))
