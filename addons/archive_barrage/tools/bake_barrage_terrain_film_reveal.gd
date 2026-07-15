extends SceneTree


func _init() -> void:
	call_deferred("_bake_all_profiles")


func _bake_all_profiles() -> void:
	var failed := false
	failed = not _bake_profile(false) or failed
	failed = not _bake_profile(true) or failed
	quit(1 if failed else 0)


func _bake_profile(performance_mode: bool) -> bool:
	var terrain := BarrageTerrain.new()
	terrain.position = Vector3(0.0, 0.0, -250.0)
	terrain.film_reveal_hill_enabled = true
	root.add_child(terrain)
	terrain.build(performance_mode, true, false)
	var terrain_mesh := terrain.mesh as ArrayMesh
	if terrain_mesh == null:
		push_error("Film-reveal barrage terrain bake did not produce an ArrayMesh")
		terrain.queue_free()
		return false

	var mesh_path := (
		BarrageTerrain.PERFORMANCE_FILM_REVEAL_MESH_PATH
		if performance_mode
		else BarrageTerrain.CINEMATIC_FILM_REVEAL_MESH_PATH
	)
	var collision_path := (
		BarrageTerrain.PERFORMANCE_FILM_REVEAL_COLLISION_PATH
		if performance_mode
		else BarrageTerrain.CINEMATIC_FILM_REVEAL_COLLISION_PATH
	)
	var save_error := ResourceSaver.save(
		terrain_mesh,
		mesh_path,
		ResourceSaver.FLAG_COMPRESS
	)
	if save_error != OK:
		push_error("Could not save film-reveal barrage terrain mesh: %s" % error_string(save_error))
		terrain.queue_free()
		return false

	var collision_shape := terrain_mesh.create_trimesh_shape()
	save_error = ResourceSaver.save(
		collision_shape,
		collision_path,
		ResourceSaver.FLAG_COMPRESS
	)
	terrain.queue_free()
	if save_error != OK:
		push_error(
			"Could not save film-reveal barrage terrain collision: %s"
			% error_string(save_error)
		)
		return false

	print(
		"Baked %s film-reveal barrage terrain: %s"
		% ["Performance" if performance_mode else "Cinematic", mesh_path]
	)
	return true
