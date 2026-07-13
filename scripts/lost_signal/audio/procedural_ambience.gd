class_name LostSignalProceduralAmbience
extends RefCounted

enum Kind { ENGINE, ROAD, DINER, FOREST }


static func make_loop(kind: Kind, seconds := 3.0, sample_rate := 22050) -> AudioStreamWAV:
	var count := int(seconds * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 8911 + kind * 1237
	var filtered := 0.0
	for index in count:
		var time := float(index) / float(sample_rate)
		var sample := 0.0
		var noise := random.randf_range(-1.0, 1.0)
		match kind:
			Kind.ENGINE:
				filtered = lerpf(filtered, noise, 0.025)
				sample = sin(TAU * 43.0 * time) * 0.30 + sin(TAU * 86.0 * time) * 0.14 + filtered * 0.16
			Kind.ROAD:
				filtered = lerpf(filtered, noise, 0.12)
				sample = filtered * 0.36 + sin(TAU * 18.0 * time) * 0.06
			Kind.DINER:
				filtered = lerpf(filtered, noise, 0.018)
				sample = sin(TAU * 50.0 * time) * 0.11 + sin(TAU * 100.0 * time) * 0.035 + filtered * 0.11
			Kind.FOREST:
				filtered = lerpf(filtered, noise, 0.008)
				var cricket_gate := pow(maxf(0.0, sin(TAU * 1.7 * time)), 18.0)
				var cricket := sin(TAU * 3650.0 * time) * cricket_gate * 0.07
				sample = filtered * 0.28 + cricket
		var value := clampi(int(sample * 14000.0), -32767, 32767)
		bytes[index * 2] = value & 0xff
		bytes[index * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	stream.data = bytes
	return stream


static func add_player(parent: Node, name: String, kind: Kind, bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := LostSignalLoopPlayer.new()
	player.name = name
	player.bus = bus
	player.volume_db = volume_db
	parent.add_child(player)
	# Dummy/headless and movie-writer runs validate state/rendering without opening
	# mixer playbacks that Godot can report as leaked during forced process exit.
	var arguments := OS.get_cmdline_args()
	if (
		DisplayServer.get_name() == "headless"
		or AudioServer.get_driver_name() == "Dummy"
		or "--write-movie" in arguments
		or ("--audio-driver" in arguments and "Dummy" in arguments)
	):
		return player
	var files := [
		"res://assets/lost_signal/audio/generated/lost_signal_engine_loop.wav",
		"res://assets/lost_signal/audio/generated/lost_signal_road_loop.wav",
		"res://assets/lost_signal/audio/generated/lost_signal_diner_loop.wav",
		"res://assets/lost_signal/audio/generated/lost_signal_forest_loop.wav",
	]
	var imported := load(files[kind]) as AudioStreamWAV
	if imported:
		var loop := imported.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		player.stream = loop
	if player.stream:
		player.play()
	return player


static func play_one_shot(parent: Node, path: String, bus: StringName, volume_db := -8.0) -> AudioStreamPlayer:
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = path.get_file().get_basename()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player
