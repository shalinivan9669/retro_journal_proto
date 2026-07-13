class_name BarrageAudioDirector
extends Node3D

## Schedules positional barrage audio against monotonic wall-clock time. This keeps
## the physical speed-of-sound delay independent from Engine.time_scale.

enum EventKind {
	LAUNCH,
	IMPACT,
	DISTANT,
}

const SPEED_OF_SOUND_METERS_PER_SECOND := 343.0
const MAX_VOICES_CINEMATIC := 14
const MAX_VOICES_PERFORMANCE := 8
const MAX_PENDING_CINEMATIC := 96
const MAX_PENDING_PERFORMANCE := 56
const MAX_AUDIBLE_DISTANCE := 1800.0

const LAUNCH_PATHS := [
	"res://addons/archive_barrage/assets/generated/audio/barrage_launch_01.wav",
	"res://addons/archive_barrage/assets/generated/audio/barrage_launch_02.wav",
	"res://addons/archive_barrage/assets/generated/audio/barrage_launch_03.wav",
]
const IMPACT_PATHS := [
	"res://addons/archive_barrage/assets/generated/audio/barrage_impact_01.wav",
	"res://addons/archive_barrage/assets/generated/audio/barrage_impact_02.wav",
	"res://addons/archive_barrage/assets/generated/audio/barrage_impact_03.wav",
]
const DISTANT_PATHS := [
	"res://addons/archive_barrage/assets/generated/audio/barrage_distant_01.wav",
	"res://addons/archive_barrage/assets/generated/audio/barrage_distant_02.wav",
	"res://addons/archive_barrage/assets/generated/audio/barrage_distant_03.wav",
]
const PITCH_VARIANTS := [0.958, 0.976, 0.992, 1.008, 1.026, 1.044]

var _listener: Node3D
var _performance_mode := false
var _playback_enabled := false
var _event_sequence := 0
var _maximum_pending := MAX_PENDING_CINEMATIC
var _audio_bus: StringName = &"Master"

var _launch_streams: Array[AudioStream] = []
var _impact_streams: Array[AudioStream] = []
var _distant_streams: Array[AudioStream] = []
var _pending_events: Array[Dictionary] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_started_usec: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(_playback_enabled)


func configure(listener: Node3D, performance_mode: bool = false) -> void:
	_stop_and_clear()
	_listener = listener
	_performance_mode = performance_mode
	_event_sequence = 0
	_maximum_pending = (
		MAX_PENDING_PERFORMANCE if _performance_mode else MAX_PENDING_CINEMATIC
	)
	_audio_bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"

	_playback_enabled = is_instance_valid(_listener) and _has_real_audio_output()
	if not _playback_enabled:
		set_process(false)
		return

	_load_streams()
	_playback_enabled = (
		not _launch_streams.is_empty()
		and not _impact_streams.is_empty()
		and not _distant_streams.is_empty()
	)
	if not _playback_enabled:
		set_process(false)
		return

	_build_voice_pool(MAX_VOICES_PERFORMANCE if _performance_mode else MAX_VOICES_CINEMATIC)
	set_process(true)


func queue_launch(position: Vector3, strength: float) -> void:
	_queue_event(EventKind.LAUNCH, position, strength)


func queue_impact(position: Vector3, strength: float) -> void:
	_queue_event(EventKind.IMPACT, position, strength)


func queue_distant(position: Vector3, strength: float) -> void:
	_queue_event(EventKind.DISTANT, position, strength)


func _process(_delta: float) -> void:
	if not _playback_enabled:
		return
	if not is_instance_valid(_listener):
		_stop_and_clear()
		set_process(false)
		return

	var now_usec := Time.get_ticks_usec()
	while (
		not _pending_events.is_empty()
		and int(_pending_events[0]["due_usec"]) <= now_usec
	):
		var event: Dictionary = _pending_events.pop_front()
		_play_event(event, now_usec)


func _exit_tree() -> void:
	_stop_and_clear()


func _queue_event(kind: int, position: Vector3, strength: float) -> void:
	if not _playback_enabled or not is_instance_valid(_listener):
		return
	if strength <= 0.0:
		return

	var normalized_strength := clampf(strength, 0.0, 1.0)
	var sequence := _event_sequence
	_event_sequence += 1
	var distance := _listener.global_position.distance_to(position)
	var delay_usec := int(round(distance / SPEED_OF_SOUND_METERS_PER_SECOND * 1000000.0))
	var event := {
		"due_usec": Time.get_ticks_usec() + delay_usec,
		"kind": kind,
		"position": position,
		"strength": normalized_strength,
		"seed": _stable_event_seed(position, kind, sequence),
	}

	if _pending_events.size() >= _maximum_pending and not _make_room_for(event):
		return
	_pending_events.append(event)
	_pending_events.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["due_usec"]) < int(b["due_usec"])
	)


func _make_room_for(incoming: Dictionary) -> bool:
	var weakest_index := 0
	var weakest_strength := float(_pending_events[0]["strength"])
	for index in range(1, _pending_events.size()):
		var candidate_strength := float(_pending_events[index]["strength"])
		if candidate_strength < weakest_strength:
			weakest_strength = candidate_strength
			weakest_index = index
	if float(incoming["strength"]) <= weakest_strength:
		return false
	_pending_events.remove_at(weakest_index)
	return true


func _play_event(event: Dictionary, now_usec: int) -> void:
	var kind := int(event["kind"])
	var streams := _streams_for(kind)
	if streams.is_empty():
		return

	var seed := int(event["seed"])
	var stream_index := seed % streams.size()
	var pitch_index: int = int(seed / maxi(streams.size(), 1)) % PITCH_VARIANTS.size()
	var voice_index := _acquire_voice_index()
	if voice_index < 0:
		return

	var voice := _voices[voice_index]
	voice.stop()
	voice.stream = streams[stream_index]
	voice.global_position = event["position"] as Vector3
	voice.pitch_scale = float(PITCH_VARIANTS[pitch_index])
	voice.volume_db = _volume_for(kind, float(event["strength"]))
	voice.unit_size = _unit_size_for(kind)
	voice.max_distance = MAX_AUDIBLE_DISTANCE
	voice.bus = _audio_bus
	voice.play()
	_voice_started_usec[voice_index] = now_usec


func _acquire_voice_index() -> int:
	for index in range(_voices.size()):
		if not _voices[index].playing:
			return index
	if _voices.is_empty():
		return -1

	var oldest_index := 0
	var oldest_start := _voice_started_usec[0]
	for index in range(1, _voice_started_usec.size()):
		if _voice_started_usec[index] < oldest_start:
			oldest_start = _voice_started_usec[index]
			oldest_index = index
	return oldest_index


func _streams_for(kind: int) -> Array[AudioStream]:
	match kind:
		EventKind.LAUNCH:
			return _launch_streams
		EventKind.IMPACT:
			return _impact_streams
		EventKind.DISTANT:
			return _distant_streams
	return _distant_streams


func _volume_for(kind: int, strength: float) -> float:
	match kind:
		EventKind.LAUNCH:
			return lerpf(-14.0, -7.0, strength)
		EventKind.IMPACT:
			return lerpf(-10.0, -3.5, strength)
		EventKind.DISTANT:
			return lerpf(-17.0, -9.0, strength)
	return -12.0


func _unit_size_for(kind: int) -> float:
	match kind:
		EventKind.LAUNCH:
			return 38.0
		EventKind.IMPACT:
			return 82.0
		EventKind.DISTANT:
			return 125.0
	return 60.0


func _stable_event_seed(position: Vector3, kind: int, sequence: int) -> int:
	var seed := (sequence + 1) * 48271 + (kind + 1) * 69621
	seed = _mix_seed(seed, int(round(position.x * 10.0)))
	seed = _mix_seed(seed, int(round(position.y * 10.0)))
	seed = _mix_seed(seed, int(round(position.z * 10.0)))
	return seed & 0x7fffffff


func _mix_seed(seed: int, value: int) -> int:
	return (seed * 1103515245 + value + 12345) & 0x7fffffff


func _load_streams() -> void:
	_launch_streams.clear()
	_impact_streams.clear()
	_distant_streams.clear()
	_load_stream_group(LAUNCH_PATHS, _launch_streams)
	_load_stream_group(IMPACT_PATHS, _impact_streams)
	_load_stream_group(DISTANT_PATHS, _distant_streams)


func _load_stream_group(paths: Array, destination: Array[AudioStream]) -> void:
	for path: String in paths:
		var resource := ResourceLoader.load(path)
		if resource is AudioStream:
			destination.append(resource as AudioStream)


func _build_voice_pool(voice_count: int) -> void:
	for index in range(voice_count):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "BarrageVoice%02d" % (index + 1)
		voice.bus = _audio_bus
		voice.max_distance = MAX_AUDIBLE_DISTANCE
		voice.unit_size = 60.0
		voice.autoplay = false
		add_child(voice)
		_voices.append(voice)
		_voice_started_usec.append(0)


func _stop_and_clear() -> void:
	_pending_events.clear()
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()
	_voices.clear()
	_voice_started_usec.clear()
	_launch_streams.clear()
	_impact_streams.clear()
	_distant_streams.clear()
	_playback_enabled = false


func _has_real_audio_output() -> bool:
	return (
		DisplayServer.get_name().to_lower() != "headless"
		and AudioServer.get_driver_name().to_lower() != "dummy"
	)
