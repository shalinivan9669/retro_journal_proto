@tool
extends EditorScript

## Optional helper. Run from Godot Script Editor: File -> Run.
## It adds scenes/visuals/VisualEffectsRuntime.tscn as a child of res://scenes/Main.tscn.
## Make a git commit/back-up before running any editor script that saves a scene.

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const VISUAL_SCENE_PATH := "res://scenes/visuals/VisualEffectsRuntime.tscn"

func _run() -> void:
	var main_res := load(MAIN_SCENE_PATH) as PackedScene
	var visual_res := load(VISUAL_SCENE_PATH) as PackedScene
	if main_res == null:
		push_error("Cannot load " + MAIN_SCENE_PATH)
		return
	if visual_res == null:
		push_error("Cannot load " + VISUAL_SCENE_PATH)
		return

	var root := main_res.instantiate()
	if root == null:
		push_error("Cannot instantiate Main.tscn")
		return

	if root.find_child("VisualEffectsRuntime", false, false) != null:
		print("VisualEffectsRuntime already exists in Main.tscn")
		root.free()
		return

	var visual := visual_res.instantiate()
	visual.name = "VisualEffectsRuntime"
	root.add_child(visual)
	visual.owner = root

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("PackedScene.pack failed: " + str(pack_err))
		root.free()
		return

	var save_err := ResourceSaver.save(packed, MAIN_SCENE_PATH)
	root.free()

	if save_err == OK:
		print("Installed VisualEffectsRuntime into " + MAIN_SCENE_PATH)
	else:
		push_error("Saving Main.tscn failed: " + str(save_err))
