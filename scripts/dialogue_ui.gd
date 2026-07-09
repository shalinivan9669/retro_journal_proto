extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var texture_rect: TextureRect = $Panel/TextureRect
@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var label: Label = $Panel/Label
@onready var options_container: VBoxContainer = $Panel/OptionsContainer
@onready var prompt_label: Label = $PromptLabel

var _choice_owner: Node = null
var _choices: Array = []
var _intro_text := ""
var _speaker_name := ""
var _pending_close_choice_index := -1
var _player: Node = null
var _aim_dot_ui: CanvasLayer = null
var _previous_player_lock := false
var _previous_aim_dot_visible := true
var _locked_player_for_dialogue := false


func _ready() -> void:
	add_to_group("dialogue_ui")
	hide_prompt()
	hide_message()


func _unhandled_input(event: InputEvent) -> void:
	if _choice_owner == null or not panel.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_message()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton or event is InputEventKey:
		get_viewport().set_input_as_handled()


func show_message(message: String) -> void:
	_complete_pending_choice_if_needed()
	_unlock_player_after_dialogue()
	_choice_owner = null
	_choices.clear()
	_pending_close_choice_index = -1

	hide_prompt()
	speaker_label.visible = false
	options_container.visible = false
	_clear_options()
	label.text = message
	label.offset_top = 14.0
	label.offset_bottom = -14.0
	texture_rect.modulate = Color(1, 1, 1, 1)
	panel.visible = true
	_sync_root_visibility()


func show_choice_dialogue(owner: Node, speaker_name: String, intro_text: String, choices: Array) -> void:
	_choice_owner = owner
	_speaker_name = speaker_name
	_intro_text = intro_text
	_choices = choices.duplicate(true)
	_pending_close_choice_index = -1

	_lock_player_for_dialogue()
	hide_prompt()
	panel.visible = true
	speaker_label.visible = true
	options_container.visible = true
	speaker_label.text = _speaker_name
	texture_rect.modulate = Color(0.72, 0.58, 0.5, 1)
	_show_intro()
	_sync_root_visibility()


func hide_message() -> void:
	_complete_pending_choice_if_needed()
	panel.visible = false
	speaker_label.visible = false
	options_container.visible = false
	label.text = ""
	_clear_options()
	_choice_owner = null
	_choices.clear()
	_pending_close_choice_index = -1
	_unlock_player_after_dialogue()
	_sync_root_visibility()


func is_open() -> bool:
	return panel.visible


func show_prompt(prompt_text: String) -> void:
	if panel.visible or prompt_text.is_empty():
		hide_prompt()
		return

	prompt_label.text = prompt_text
	prompt_label.visible = true
	_sync_root_visibility()


func hide_prompt() -> void:
	if prompt_label != null:
		prompt_label.visible = false
	_sync_root_visibility()


func _show_intro() -> void:
	_pending_close_choice_index = -1
	label.offset_top = 58.0
	label.offset_bottom = -154.0
	label.text = _intro_text
	_clear_options()

	for index in range(_choices.size()):
		var choice := _choices[index] as Dictionary
		_add_option_button(String(choice.get("label", "")), Callable(self, "_on_choice_pressed").bind(index))


func _on_choice_pressed(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _choices.size():
		return

	var choice := _choices[choice_index] as Dictionary
	label.offset_top = 58.0
	label.offset_bottom = -82.0
	label.text = String(choice.get("response", ""))
	_clear_options()

	if bool(choice.get("close_after_response", false)):
		_pending_close_choice_index = choice_index
		_add_option_button("Закрыть", Callable(self, "_on_close_response_pressed"))
	else:
		_pending_close_choice_index = -1
		_add_option_button("Назад", Callable(self, "_show_intro"))


func _on_close_response_pressed() -> void:
	_complete_pending_choice_if_needed()
	hide_message()


func _add_option_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(callback)
	options_container.add_child(button)


func _clear_options() -> void:
	if options_container == null:
		return

	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()


func _complete_pending_choice_if_needed() -> void:
	if _pending_close_choice_index < 0:
		return

	if _choice_owner != null and _choice_owner.has_method("on_dialogue_choice_completed"):
		_choice_owner.call("on_dialogue_choice_completed", _pending_close_choice_index)
	_pending_close_choice_index = -1


func _lock_player_for_dialogue() -> void:
	if _locked_player_for_dialogue:
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	_player = scene.get_node_or_null("Player")
	if _player != null:
		_previous_player_lock = bool(_player.get("controls_locked"))
		_player.set("controls_locked", true)
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO

	_aim_dot_ui = scene.get_node_or_null("AimDotUI") as CanvasLayer
	if _aim_dot_ui != null:
		_previous_aim_dot_visible = _aim_dot_ui.visible
		_aim_dot_ui.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_locked_player_for_dialogue = true


func _unlock_player_after_dialogue() -> void:
	if not _locked_player_for_dialogue:
		return

	if _player != null:
		_player.set("controls_locked", _previous_player_lock)
	if _aim_dot_ui != null:
		_aim_dot_ui.visible = _previous_aim_dot_visible
	if not _previous_player_lock:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_player = null
	_aim_dot_ui = null
	_locked_player_for_dialogue = false


func _sync_root_visibility() -> void:
	if panel == null or prompt_label == null:
		return
	visible = panel.visible or prompt_label.visible
