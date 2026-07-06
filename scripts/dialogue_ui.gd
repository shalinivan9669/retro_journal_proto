extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label


func _ready() -> void:
	add_to_group("dialogue_ui")
	hide_message()


func show_message(message: String) -> void:
	label.text = message
	panel.visible = true
	visible = true


func hide_message() -> void:
	panel.visible = false
	visible = false


func is_open() -> bool:
	return visible and panel.visible
