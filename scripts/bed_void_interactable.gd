extends Node3D

@export_file("*.tscn") var target_scene_path := "res://scenes/levels/TextureVoid.tscn"


func interact(_dialogue_ui: Node = null) -> void:
	var splash := get_tree().get_first_node_in_group("intro_splash")
	if splash != null and splash.has_method("play_cutscene"):
		splash.call("play_cutscene", "res://assets/videos/cutscenes/dream.ogv", Callable(self, "_change_scene"))
	else:
		_change_scene()

func _change_scene() -> void:
	get_tree().change_scene_to_file(target_scene_path)


func get_interaction_prompt() -> String:
	return "E: лечь на кровать"
