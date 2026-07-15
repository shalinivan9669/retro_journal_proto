class_name GeigerClickEmitter
extends Node

## Poisson-distributed Geiger clicks. A random interval is mathematically less
## artificial than looping a fixed click pattern.

const CLICK_MIX_RATE := 22050
const CLICK_DURATION_S := 0.012
const CLICK_IMPULSE_HZ := 2400.0
const SYNTHESIZED_VOLUME_DB := -20.0
const MAX_OUTPUT_VOLUME_DB := -6.0

@export var click_player: AudioStreamPlayer
@export_range(0.1, 30.0, 0.1) var base_rate_hz: float = 4.5
@export_range(0.1, 50.0, 0.1) var peak_rate_hz: float = 22.0
@export_range(0.0, 8.0, 0.1) var peak_volume_boost_db: float = 5.8
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)

var _rng := RandomNumberGenerator.new()
var _next_click_deadline_usec: int = 0
var _base_volume_db: float = 0.0


func _ready() -> void:
	_rng.randomize()
	if is_instance_valid(click_player):
		click_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		if click_player.stream == null:
			click_player.stream = _build_procedural_click()
			click_player.volume_db = SYNTHESIZED_VOLUME_DB
		_base_volume_db = click_player.volume_db
	_schedule_next_click(Time.get_ticks_usec())


func _process(_delta: float) -> void:
	if not is_instance_valid(click_player):
		return
	if click_player.stream == null:
		click_player.stream = _build_procedural_click()
		click_player.volume_db = SYNTHESIZED_VOLUME_DB
		_base_volume_db = click_player.volume_db
	var now_usec := Time.get_ticks_usec()
	if _next_click_deadline_usec <= 0:
		_schedule_next_click(now_usec)
		return
	if now_usec < _next_click_deadline_usec:
		return
	click_player.pitch_scale = _rng.randf_range(0.93, 1.08)
	click_player.volume_db = minf(
		_base_volume_db + peak_volume_boost_db * intensity,
		MAX_OUTPUT_VOLUME_DB
	)
	click_player.play()
	_schedule_next_click(now_usec)


func _schedule_next_click(now_usec: int) -> void:
	_next_click_deadline_usec = now_usec + int(round(_next_interval_s() * 1000000.0))


func _next_interval_s() -> float:
	var rate_hz := lerpf(base_rate_hz, peak_rate_hz, intensity)
	var uniform_sample := maxf(_rng.randf(), 0.0001)
	return clampf(-log(uniform_sample) / rate_hz, 0.035, 0.85)


func _build_procedural_click() -> AudioStreamWAV:
	var sample_count := maxi(2, int(round(CLICK_MIX_RATE * CLICK_DURATION_S)))
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count * 2)
	var waveform_rng := RandomNumberGenerator.new()
	waveform_rng.seed = 0x57484954

	for sample_index in range(sample_count):
		var sample_value := 0.0
		if sample_index > 0 and sample_index < sample_count - 1:
			var normalized := float(sample_index) / float(sample_count - 1)
			var time_s := float(sample_index) / float(CLICK_MIX_RATE)
			var endpoint_taper := sin(PI * normalized)
			var decay := exp(-time_s * 260.0)
			var impulse := sin(TAU * CLICK_IMPULSE_HZ * time_s) * 0.68
			var bipolar_noise := waveform_rng.randf_range(-1.0, 1.0) * 0.32
			sample_value = clampf((impulse + bipolar_noise) * decay * endpoint_taper, -1.0, 1.0)
		var encoded_sample := clampi(int(round(sample_value * 32767.0)), -32768, 32767)
		sample_data.encode_s16(sample_index * 2, encoded_sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = CLICK_MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = sample_data
	return stream
