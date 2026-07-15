extends SceneTree


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load("res://scenes/lost_signal/road/LoopingRoad.tscn") as PackedScene
	var road := packed.instantiate() as LostSignalLoopingRoad
	get_root().add_child(road)
	await process_frame
	road.set_physics_process(false)
	var original_ids: Array[int] = []
	for segment in road.segments:
		original_ids.append(segment.get_instance_id())
	var original_child_count := road.get_child_count()
	for _step in 10_800:
		road._physics_process(1.0 / 60.0)
	var positions: Array[float] = []
	var final_ids: Array[int] = []
	for segment in road.segments:
		positions.append(segment.position.z)
		final_ids.append(segment.get_instance_id())
	positions.sort()
	var spacing_ok := true
	for index in positions.size() - 1:
		if absf((positions[index + 1] - positions[index]) - 120.0) > 0.02:
			spacing_ok = false
	var passed := (
		road.segments.size() == 5
		and original_child_count == road.get_child_count()
		and original_ids == final_ids
		and spacing_ok
		and road.total_distance >= 3779.0
	)
	print(
		"LOST_SIGNAL_ROAD_3MIN_", "PASS" if passed else "FAIL",
		" distance=", snappedf(road.total_distance, 0.01),
		" segments=", road.segments.size(),
		" nodes_stable=", original_ids == final_ids,
		" spacing_ok=", spacing_ok,
		" positions=", positions
	)
	road.free()
	quit(0 if passed else 1)
