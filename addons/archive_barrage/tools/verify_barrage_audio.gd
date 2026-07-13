extends SceneTree

## Runtime smoke test for the intentional Dummy-driver no-op path.

const AUDIO_DIRECTORY := "res://addons/archive_barrage/assets/generated/audio"


func _initialize() -> void:
	var loaded_stream_count := 0
	for file_name in DirAccess.get_files_at(AUDIO_DIRECTORY):
		if not file_name.ends_with(".wav"):
			continue
		var stream := ResourceLoader.load("%s/%s" % [AUDIO_DIRECTORY, file_name])
		if not stream is AudioStream:
			push_error("Could not load generated barrage stream: %s" % file_name)
			quit(1)
			return
		loaded_stream_count += 1
	if loaded_stream_count != 9:
		push_error("Expected 9 generated barrage streams, loaded %d" % loaded_stream_count)
		quit(1)
		return

	var listener := Node3D.new()
	root.add_child(listener)
	var director := BarrageAudioDirector.new()
	root.add_child(director)
	director.configure(listener)
	director.queue_launch(Vector3(20.0, 1.0, -100.0), 0.8)
	director.queue_impact(Vector3(-40.0, 0.0, -250.0), 1.0)
	director.queue_distant(Vector3(160.0, 0.0, -600.0), 0.4)
	var should_be_silent := (
		DisplayServer.get_name().to_lower() == "headless"
		or AudioServer.get_driver_name().to_lower() == "dummy"
	)
	if should_be_silent and director.get_child_count() != 0:
		push_error("BarrageAudioDirector created voices without a real display/audio driver")
		quit(1)
		return
	print(
		"Barrage audio assets/headless path OK (streams=%d, driver=%s)"
		% [loaded_stream_count, AudioServer.get_driver_name()]
	)
	quit()
