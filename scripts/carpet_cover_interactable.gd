extends StaticBody3D

@export_multiline var dialogue_text: String = "Ковер сдвинулся. Под ним был люк."
@export var removed_offset: Vector3 = Vector3(1.15, 0.03, 0.42)
@export var removed_rotation_degrees: float = -9.0
@export var move_seconds: float = 0.42

@onready var cover_visual: Node3D = $CoverVisual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _removed := false
var _moving := false


func _ready() -> void:
	add_to_group("hatch_cover")


func interact(dialogue_ui: Node) -> void:
	if _removed or _moving:
		_show_dialogue(dialogue_ui, "Люк уже открыт.")
		return

	_moving = true
	_removed = true
	if collision_shape != null:
		collision_shape.disabled = true
	_show_dialogue(dialogue_ui, dialogue_text)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cover_visual, "position", removed_offset, move_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cover_visual, "rotation:y", deg_to_rad(removed_rotation_degrees), move_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	_moving = false


func is_cover_removed() -> bool:
	return _removed


func _show_dialogue(dialogue_ui: Node, text: String) -> void:
	if dialogue_ui != null and dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", text)
