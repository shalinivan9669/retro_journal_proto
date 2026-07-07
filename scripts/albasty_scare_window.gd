extends CanvasLayer

@export var display_duration: float = 2.1

@onready var panel: Panel = $Panel

var _hide_timer := 0.0


func _ready() -> void:
	add_to_group("albasty_scare_window")
	hide_667()


func _process(delta: float) -> void:
	if not visible:
		return

	_hide_timer -= delta
	if _hide_timer <= 0.0:
		hide_667()


func show_667() -> void:
	_hide_timer = display_duration
	panel.visible = true
	visible = true


func hide_667() -> void:
	panel.visible = false
	visible = false
