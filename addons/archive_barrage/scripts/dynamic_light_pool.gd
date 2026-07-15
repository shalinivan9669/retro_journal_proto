class_name DynamicLightPool
extends Node3D

var _tracer_lights: Array[OmniLight3D] = []
var _launch_lights: Array[OmniLight3D] = []
var _launch_state: Array[Dictionary] = []
var _impact_lights: Array[OmniLight3D] = []
var _impact_state: Array[Dictionary] = []
var _tracer_light_count := 10
var _launch_light_count := 6
var _impact_light_count := 6
var _max_shadowed_tracers := 3
var _max_shadowed_launches := 1
var _max_shadowed_impacts := 2
var _tracer_fog_energy := 0.06
var _terrain: BarrageTerrain
var _atmospheric_flash_level := 0.0


func configure_quality(
	use_performance_profile: bool, target_terrain: BarrageTerrain = null
) -> void:
	_terrain = target_terrain
	_tracer_light_count = 6 if use_performance_profile else 10
	_launch_light_count = 4 if use_performance_profile else 6
	_impact_light_count = 4 if use_performance_profile else 6
	# Dynamic omni shadows are the largest impact-time spike in this scene.
	# The performance profile keeps the flashes themselves but makes them
	# shadowless; the moon remains the stable shadow-casting key light.
	_max_shadowed_tracers = 0 if use_performance_profile else 3
	_max_shadowed_launches = 0 if use_performance_profile else 1
	_max_shadowed_impacts = 0 if use_performance_profile else 2
	_tracer_fog_energy = 0.035 if use_performance_profile else 0.06


func _ready() -> void:
	for index in range(_tracer_light_count):
		var light := OmniLight3D.new()
		light.name = "TracerLight_%02d" % index
		light.light_color = Color(0.96, 0.975, 1.0)
		light.omni_range = 90.0
		light.light_size = 1.8
		light.light_energy = 0.0
		light.light_volumetric_fog_energy = _tracer_fog_energy
		light.shadow_enabled = false
		add_child(light)
		_tracer_lights.append(light)

	for index in range(_launch_light_count):
		var light := OmniLight3D.new()
		light.name = "LaunchFlash_%02d" % index
		light.light_color = Color(1.0, 0.99, 0.965)
		light.omni_range = 105.0
		light.light_size = 1.8
		light.light_energy = 0.0
		light.light_volumetric_fog_energy = 0.10
		light.shadow_enabled = false
		add_child(light)
		_launch_lights.append(light)
		_launch_state.append({"age": 99.0, "energy": 0.0, "range": 105.0})

	for index in range(_impact_light_count):
		var light := OmniLight3D.new()
		light.name = "ImpactFlash_%02d" % index
		light.light_color = Color(1.0, 0.985, 0.95)
		light.omni_range = 210.0
		light.light_size = 3.2
		light.light_energy = 0.0
		light.light_volumetric_fog_energy = 0.16
		light.shadow_enabled = false
		add_child(light)
		_impact_lights.append(light)
		_impact_state.append(
			{"age": 99.0, "energy": 0.0, "range": 210.0, "distant": false}
		)


func spawn_launch_flash(position: Vector3, energy: float) -> void:
	var oldest := _oldest_state_index(_launch_state)
	if oldest < 0:
		return
	var normalized := clampf((energy - 8.0) / 24.0, 0.0, 1.0)
	_launch_state[oldest] = {
		"age": 0.0,
		"energy": energy,
		"range": lerpf(72.0, 118.0, normalized),
	}
	_launch_lights[oldest].global_position = position + Vector3.UP * 1.8


func spawn_impact_flash(position: Vector3, energy: float) -> void:
	_spawn_impact_like_flash(position, energy, false)


func spawn_distant_flash(position: Vector3, energy: float) -> void:
	_spawn_impact_like_flash(position, energy, true)


func advance(fx_delta: float, trails: Array, camera: Camera3D) -> void:
	_update_launch_lights(fx_delta)
	_update_impact_lights(fx_delta)
	_update_tracer_lights(trails, camera)
	_update_atmospheric_level()


func atmospheric_flash_level() -> float:
	return _atmospheric_flash_level


func _update_launch_lights(fx_delta: float) -> void:
	var active_flashes: Array[Dictionary] = []
	for index in range(_launch_lights.size()):
		var age := float(_launch_state[index]["age"]) + fx_delta
		_launch_state[index]["age"] = age
		var base_energy := float(_launch_state[index]["energy"])
		var envelope := exp(-pow(age / 0.042, 2.0))
		envelope += 0.24 * exp(-pow((age - 0.10) / 0.17, 2.0))
		var light := _launch_lights[index]
		light.light_energy = base_energy * envelope
		light.omni_range = float(_launch_state[index]["range"])
		light.visible = envelope > 0.002
		light.shadow_enabled = false
		if envelope > 0.002:
			active_flashes.append({"index": index, "energy": light.light_energy})
	active_flashes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["energy"]) > float(b["energy"])
	)
	for rank in range(mini(_max_shadowed_launches, active_flashes.size())):
		var light_index := int(active_flashes[rank]["index"])
		_launch_lights[light_index].shadow_enabled = true


func _update_impact_lights(fx_delta: float) -> void:
	var active_flashes: Array[Dictionary] = []
	for index in range(_impact_lights.size()):
		var age := float(_impact_state[index]["age"]) + fx_delta
		_impact_state[index]["age"] = age
		var base_energy := float(_impact_state[index]["energy"])
		var distant := bool(_impact_state[index]["distant"])
		var peak_width := 0.065 if distant else 0.052
		var tail_width := 0.46 if distant else 0.34
		var envelope := exp(-pow(age / peak_width, 2.0))
		envelope += (0.26 if distant else 0.42) * exp(-age / tail_width)
		var light := _impact_lights[index]
		light.light_energy = base_energy * envelope
		light.omni_range = float(_impact_state[index]["range"])
		light.light_volumetric_fog_energy = 0.08 if distant else 0.16
		light.visible = envelope > 0.002
		light.shadow_enabled = false
		if envelope > 0.002 and not distant:
			active_flashes.append({"index": index, "energy": light.light_energy})
	active_flashes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["energy"]) > float(b["energy"])
	)
	for rank in range(mini(_max_shadowed_impacts, active_flashes.size())):
		var light_index := int(active_flashes[rank]["index"])
		_impact_lights[light_index].shadow_enabled = true


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
		var head_position := trail.head_position()
		light.global_position = head_position
		var normalized_intensity := clampf(intensity, 0.0, 1.0)
		var altitude := 40.0
		if _terrain != null:
			altitude = maxf(
				head_position.y - _terrain.height_at_world(head_position.x, head_position.z),
				0.0
			)
		light.light_energy = lerpf(4.8, 14.0, normalized_intensity)
		light.omni_range = clampf(altitude + 62.0, 88.0, 285.0)
		light.shadow_enabled = index < _max_shadowed_tracers
		light.visible = true


func _spawn_impact_like_flash(position: Vector3, energy: float, distant: bool) -> void:
	var oldest := _oldest_state_index(_impact_state)
	if oldest < 0:
		return
	var normalized := clampf((energy - 12.0) / 92.0, 0.0, 1.0)
	var target_range := (
		lerpf(120.0, 175.0, normalized)
		if distant
		else lerpf(175.0, 265.0, normalized)
	)
	_impact_state[oldest] = {
		"age": 0.0,
		"energy": energy,
		"range": target_range,
		"distant": distant,
	}
	_impact_lights[oldest].global_position = position + Vector3.UP * (5.0 if distant else 3.2)


func _oldest_state_index(states: Array[Dictionary]) -> int:
	if states.is_empty():
		return -1
	var oldest := 0
	for index in range(1, states.size()):
		if float(states[index]["age"]) > float(states[oldest]["age"]):
			oldest = index
	return oldest


func _update_atmospheric_level() -> void:
	var strongest := 0.0
	for light in _impact_lights:
		if light.visible:
			strongest = maxf(strongest, light.light_energy / 110.0)
	for light in _launch_lights:
		if light.visible:
			strongest = maxf(strongest, light.light_energy / 75.0)
	_atmospheric_flash_level = clampf(strongest, 0.0, 1.0)
