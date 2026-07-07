extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/MarginContainer/Label


func _ready() -> void:
	add_to_group("signal_dialogue_window")
	hide_signal_message()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			hide_signal_message()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		hide_signal_message()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()


func show_signal_message(text: String) -> void:
	label.text = text
	panel.visible = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_signal_message() -> void:
	panel.visible = false
	visible = false


func is_open() -> bool:
	return visible and panel.visible
