extends Node3D

@export_file("*.tscn") var target_scene_path := "res://scenes/levels/TextureVoid.tscn"


func interact(_dialogue_ui: Node = null) -> void:
	get_tree().change_scene_to_file(target_scene_path)


func get_interaction_prompt() -> String:
	return "E: лечь на кровать"
