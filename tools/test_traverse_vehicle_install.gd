extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed := load("res://scenes/lost_signal/road/VehicleInterior.tscn") as PackedScene
	var vehicle := packed.instantiate() as LostSignalVehicleInterior
	root.add_child(vehicle)
	await process_frame
	var model := vehicle.get_node_or_null("ChevroletTraverseRS2023") as Node3D
	var procedural_shell := vehicle.get_node_or_null("DetailedVehicleInterior")
	var model_bounds := AABB()
	var first_mesh := true
	if model:
		for candidate in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var world_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
			model_bounds = world_bounds if first_mesh else model_bounds.merge(world_bounds)
			first_mesh = false
	var eye := vehicle.camera.global_position if vehicle.camera else Vector3.INF
	var eye_inside := model_bounds.has_point(eye)
	var spot_count := vehicle.find_children("*", "SpotLight3D", true, false).size()
	var passed := (
		model != null
		and procedural_shell == null
		and not first_mesh
		and model_bounds.size.x > 2.0 and model_bounds.size.x < 2.3
		and model_bounds.size.y > 1.7 and model_bounds.size.y < 1.9
		and model_bounds.size.z > 4.9 and model_bounds.size.z < 5.2
		and eye_inside
		and eye.x < 0.0
		and spot_count == 6
	)
	print(
		"TRAVERSE_VEHICLE_", "PASS" if passed else "FAIL",
		" bounds=", model_bounds,
		" eye=", eye,
		" eye_inside=", eye_inside,
		" spots=", spot_count,
		" fallback_present=", procedural_shell != null
	)
	vehicle.free()
	quit(0 if passed else 1)
