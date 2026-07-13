class_name ArchivePostProcess
extends CanvasLayer

enum FlashKind {
	LAUNCH,
	IMPACT,
	DISTANT,
}

const FILM_SHADER := preload("res://addons/archive_barrage/shaders/archive_film.gdshader")
const SPOT_COUNT := 4
const FLASH_FADE_TAU := 0.055

var retina_level := 0.0
var _flash_peak := 0.0
var _spots: Array[Vector3] = [
	Vector3(0.5, 0.5, 0.0),
	Vector3(0.5, 0.5, 0.0),
	Vector3(0.5, 0.5, 0.0),
	Vector3(0.5, 0.5, 0.0),
]
var _spot_uvs: Array[Vector2] = [
	Vector2(0.5, 0.5),
	Vector2(0.5, 0.5),
	Vector2(0.5, 0.5),
	Vector2(0.5, 0.5),
]
var _spot_strengths: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _spot_ages: Array[float] = [99.0, 99.0, 99.0, 99.0]
var _spot_kinds: Array[int] = [
	FlashKind.LAUNCH,
	FlashKind.LAUNCH,
	FlashKind.LAUNCH,
	FlashKind.LAUNCH,
]
var _last_wall_time_usec := 0
var _material: ShaderMaterial


func _ready() -> void:
	layer = 100
	_material = ShaderMaterial.new()
	_material.shader = FILM_SHADER

	var rect := ColorRect.new()
	rect.name = "ArchiveFilmPass"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _material
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_update_viewport_aspect)
	_update_viewport_aspect()
	_last_wall_time_usec = Time.get_ticks_usec()
	_push_shader_state(_last_wall_time_usec)


func register_flash(
	camera: Camera3D,
	world_position: Vector3,
	energy: float,
	flash_kind: int = FlashKind.LAUNCH
) -> float:
	if camera == null or not is_instance_valid(camera):
		return 0.0
	if energy <= 0.0 or camera.is_position_behind(world_position):
		return 0.0

	var viewport_size := camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 0.0
	var screen := camera.unproject_position(world_position)
	var uv := Vector2(screen.x / viewport_size.x, screen.y / viewport_size.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return 0.0

	var resolved_kind := clampi(flash_kind, FlashKind.LAUNCH, FlashKind.DISTANT)
	var energy_response := 1.0 - exp(-energy / 24.0)
	var normalized_edge_distance := clampf((uv - Vector2(0.5, 0.5)).length() / 0.7071, 0.0, 1.0)
	var edge_visibility := lerpf(1.0, 0.76, smoothstep(0.45, 1.0, normalized_edge_distance))
	var strength := clampf(
		energy_response * _kind_strength_multiplier(resolved_kind) * edge_visibility,
		0.0,
		1.0
	)
	if strength <= 0.0:
		return 0.0

	var weakest := 0
	var weakest_score := 2.0
	for index in range(SPOT_COUNT):
		var recovery_time := _recovery_time_for_kind(_spot_kinds[index])
		var remaining := maxf(1.0 - _spot_ages[index] / recovery_time, 0.0)
		var score := _spot_strengths[index] * remaining
		if score < weakest_score:
			weakest = index
			weakest_score = score

	_spot_uvs[weakest] = uv
	_spot_strengths[weakest] = strength
	_spot_ages[weakest] = 0.0
	_spot_kinds[weakest] = resolved_kind
	_advance_retina_response(0.0)
	_push_shader_state(Time.get_ticks_usec())
	return strength


func _process(_delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	var wall_delta := maxf(float(now_usec - _last_wall_time_usec) / 1000000.0, 0.0)
	_last_wall_time_usec = now_usec
	_advance_retina_response(wall_delta)
	_push_shader_state(now_usec)


func _advance_retina_response(wall_delta: float) -> void:
	var remaining_sensitivity := 1.0
	_flash_peak = 0.0

	for index in range(SPOT_COUNT):
		var strength := _spot_strengths[index]
		if strength <= 0.0:
			_spots[index] = Vector3(_spot_uvs[index].x, _spot_uvs[index].y, 0.0)
			continue

		_spot_ages[index] += wall_delta
		var age := _spot_ages[index]
		var flash_kind := _spot_kinds[index]
		var peak_duration := _peak_duration_for_kind(flash_kind)
		var recovery_time := _recovery_time_for_kind(flash_kind)
		if age >= recovery_time:
			_spot_strengths[index] = 0.0
			_spots[index] = Vector3(_spot_uvs[index].x, _spot_uvs[index].y, 0.0)
			continue

		var peak_envelope := 1.0
		if age > peak_duration:
			peak_envelope = exp(-(age - peak_duration) / FLASH_FADE_TAU)
		_flash_peak = maxf(_flash_peak, strength * peak_envelope)

		var recovery_progress := smoothstep(peak_duration, recovery_time, age)
		var sensitivity_contraction := strength * (1.0 - recovery_progress)
		remaining_sensitivity *= 1.0 - clampf(sensitivity_contraction * 0.72, 0.0, 0.86)

		var afterimage_rise := smoothstep(peak_duration * 0.55, peak_duration + 0.12, age)
		var afterimage_decay := 1.0 - smoothstep(peak_duration + 0.12, recovery_time, age)
		var afterimage_envelope := afterimage_rise * afterimage_decay
		var local_response := strength * maxf(peak_envelope, afterimage_envelope * 0.72)
		_spots[index] = Vector3(_spot_uvs[index].x, _spot_uvs[index].y, local_response)

	retina_level = clampf(1.0 - remaining_sensitivity, 0.0, 1.0)


func _push_shader_state(now_usec: int) -> void:
	if _material == null:
		return
	var wall_time := fmod(float(now_usec) / 1000000.0, 3600.0)
	_material.set_shader_parameter("wall_time", wall_time)
	_material.set_shader_parameter("retina_level", retina_level)
	_material.set_shader_parameter("flash_peak", _flash_peak)
	for index in range(SPOT_COUNT):
		_material.set_shader_parameter("retina_spot_%d" % index, _spots[index])


func _kind_strength_multiplier(flash_kind: int) -> float:
	match flash_kind:
		FlashKind.IMPACT:
			return 1.16
		FlashKind.DISTANT:
			return 0.48
		_:
			return 0.72


func _peak_duration_for_kind(flash_kind: int) -> float:
	match flash_kind:
		FlashKind.IMPACT:
			return 0.065
		FlashKind.DISTANT:
			return 0.050
		_:
			return 0.045


func _recovery_time_for_kind(flash_kind: int) -> float:
	match flash_kind:
		FlashKind.IMPACT:
			return 2.35
		FlashKind.DISTANT:
			return 1.80
		_:
			return 1.55


func _update_viewport_aspect() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	_material.set_shader_parameter("viewport_aspect", aspect)
