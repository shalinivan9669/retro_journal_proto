extends Area3D

@export var prompt_text := "E — поднять плёнку"
@export var picked_up_text := "F — посмотреть плёнку"

var _picked_up := false


func _ready() -> void:
	if GameState.film_01_collected:
		queue_free()


func interact(dialogue_ui: Node = null) -> void:
	if _picked_up or GameState.film_01_collected:
		return
	_picked_up = true
	GameState.film_01_collected = true
	var viewer := get_tree().get_first_node_in_group("film_viewer")
	if viewer != null and viewer.has_method("show_hint"):
		viewer.call("show_hint", picked_up_text)
	queue_free()


func get_interaction_prompt() -> String:
	return "" if _picked_up or GameState.film_01_collected else prompt_text
