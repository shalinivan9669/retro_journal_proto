extends SceneTree

const SCENES := [
	["NightDrive", "res://scenes/lost_signal/road/NightDrive.tscn"],
	["Diner", "res://scenes/lost_signal/diner/DinerSequence.tscn"],
	["Restroom", "res://scenes/lost_signal/restroom/Restroom.tscn"],
	["Forest", "res://scenes/lost_signal/forest/ForestRoad.tscn"],
]


func _initialize() -> void:
	call_deferred("run_benchmark")


func run_benchmark() -> void:
	print("LOST_SIGNAL_BENCH_DRIVER display=", DisplayServer.get_name(), " audio=", AudioServer.get_driver_name())
	for entry in SCENES:
		var error := change_scene_to_file(entry[1])
		if error != OK:
			print("LOST_SIGNAL_BENCH_FAIL scene=", entry[0], " error=", error)
			continue
		await create_timer(2.2).timeout
		for _frame in 12:
			await process_frame
		var scene := current_scene
		var lights := scene.find_children("*", "Light3D", true, false).size()
		var shadow_lights := 0
		for node in scene.find_children("*", "Light3D", true, false):
			if (node as Light3D).shadow_enabled:
				shadow_lights += 1
		var active_viewports := 0
		for node in scene.find_children("*", "SubViewport", true, false):
			if (node as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
				active_viewports += 1
		print(
			"LOST_SIGNAL_BENCH scene=", entry[0],
			" fps=", snappedf(Performance.get_monitor(Performance.TIME_FPS), 0.1),
			" process_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
			" draw_calls=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			" objects=", int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			" primitives=", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			" lights=", lights,
			" shadow_lights=", shadow_lights,
			" active_subviewports=", active_viewports
		)
		_stop_audio(scene)
		await process_frame
		await process_frame
	quit()


func _stop_audio(scene: Node) -> void:
	for node in scene.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		player.stop()
		player.stream = null
	for node in scene.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := node as AudioStreamPlayer3D
		player.stop()
		player.stream = null
