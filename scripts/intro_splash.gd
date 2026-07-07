extends CanvasLayer

@export var display_duration: float = 4.6
@export var max_font_size: int = 96
@export var min_font_size: int = 48

@onready var label: Label = $TextMargin/IntroLabel

var _timer := 0.0
var _active := false
var _player: Node = null
var _aim_dot_ui: Node = null
var _previous_player_lock := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("intro_splash")
	get_viewport().size_changed.connect(_resize_text)
	_resize_text()
	call_deferred("show_intro")


func _input(_event: InputEvent) -> void:
	if _active:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return

	_timer -= delta
	if _timer <= 0.0:
		_finish_intro()


func show_intro() -> void:
	_timer = display_duration
	_active = true
	visible = true
	_lock_player()


func _finish_intro() -> void:
	_active = false
	visible = false
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
