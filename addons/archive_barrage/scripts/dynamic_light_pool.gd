class_name DynamicLightPool
extends Node3D

var _tracer_lights: Array[OmniLight3D] = []
var _flash_lights: Array[OmniLight3D] = []
var _flash_state: Array[Dictionary] = []
var _tracer_light_count := 10
var _flash_light_count := 6
var _max_shadowed_tracers := 3
var _max_shadowed_flashes := 2
var _tracer_fog_energy := 0.11


func configure_quality(use_performance_profile: bool) -> void:
	_tracer_light_count = 6 if use_performance_profile else 10
	_flash_light_count = 4 if use_performance_profile else 6
	_max_shadowed_tracers = 1 if use_performance_profile else 3
	_max_shadowed_flashes = 1 if use_performance_profile else 2
	_tracer_fog_energy = 0.07 if use_performance_profile else 0.11


func _ready() -> void:
	for index in range(_tracer_light_count):
		var light := OmniLight3D.new()
		light.name = "TracerLight_%02d" % index
		light.light_color = Color(0.95, 0.975, 1.0)
		light.omni_range = 62.0
		light.light_size = 1.2
		light.light_energy = 0.0
		light.light_volumetric_fog_energy = _tracer_fog_energy
		light.shadow_enabled = false
		add_child(light)
		_tracer_lights.append(light)

	for index in range(_flash_light_count):
		var light := OmniLight3D.new()
		light.name = "LaunchFlash_%02d" % index
		light.light_color = Color(1.0, 0.975, 0.92)
		light.omni_range = 105.0
		light.light_size = 1.4
		light.light_energy = 0.0
		light.light_volumetric_fog_energy = 0.32
		light.shadow_enabled = false
		add_child(light)
		_flash_lights.append(light)
		_flash_state.append({"age": 99.0, "energy": 0.0})


func spawn_launch_flash(position: Vector3, energy: float) -> void:
	var oldest := 0
	for index in range(1, _flash_state.size()):
		if float(_flash_state[index]["age"]) > float(_flash_state[oldest]["age"]):
			oldest = index
	_flash_state[oldest] = {"age": 0.0, "energy": energy}
	_flash_lights[oldest].global_position = position + Vector3.UP * 2.2


func advance(fx_delta: float, trails: Array, camera: Camera3D) -> void:
	_update_flash_lights(fx_delta)
	_update_tracer_lights(trails, camera)


func _update_flash_lights(fx_delta: float) -> void:
	var active_flashes: Array[Dictionary] = []
	for index in range(_flash_lights.size()):
		var age := float(_flash_state[index]["age"]) + fx_delta
		_flash_state[index]["age"] = age
		var base_energy := float(_flash_state[index]["energy"])
		var envelope := exp(-pow(age / 0.045, 2.0))
		envelope += 0.35 * exp(-pow((age - 0.12) / 0.18, 2.0))
		_flash_lights[index].light_energy = base_energy * envelope
		_flash_lights[index].visible = envelope > 0.002
		_flash_lights[index].shadow_enabled = false
		if envelope > 0.002:
			active_flashes.append(
				{"index": index, "energy": _flash_lights[index].light_energy}
			)
	active_flashes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["energy"]) > float(b["energy"])
	)
	for rank in range(mini(_max_shadowed_flashes, active_flashes.size())):
		var light_index := int(active_flashes[rank]["index"])
		_flash_lights[light_index].shadow_enabled = true


func _update_tracer_lights(trails: Array, camera: Camera3D) -> void:
	var candidates: Array[Dictionary] = []
	for trail in trails:
		if not is_instance_valid(trail):
			continue
		var intensity: float = trail.head_intensity()
		if intensity <= 0.001:
			continue
		var position: Vector3 = trail.head_position()
		var distance := camera.global_position.distance_to(position)
		var score := intensity / (distance * distance + 64.0)
		candidates.append({"trail": trail, "score": score, "intensity": intensity})

	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"])
	)

	for index in range(_tracer_lights.size()):
		var light := _tracer_lights[index]
		if index >= candidates.size():
			light.light_energy = 0.0
			light.visible = false
			continue
		var trail: BallisticTrail3D = candidates[index]["trail"]
		var intensity := float(candidates[index]["intensity"])
		light.global_position = trail.head_position()
		var normalized_intensity := clampf(intensity, 0.0, 1.0)
		light.light_energy = lerpf(2.4, 8.5, normalized_intensity)
		light.omni_range = lerpf(42.0, 86.0, normalized_intensity)
		light.shadow_enabled = index < _max_shadowed_tracers
		light.visible = true
