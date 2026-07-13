class_name BarrageFlashBurst
extends Node3D

const MAX_RAYS := 12
const DEFAULT_FLASH_TEXTURE: Texture2D = preload(
	"res://addons/archive_barrage/assets/generated/fx/flash_radial_1k.png"
)
const FLASH_SHADER: Shader = preload(
	"res://addons/archive_barrage/shaders/barrage_flash_billboard.gdshader"
)
const GROUND_SHADER: Shader = preload(
	"res://addons/archive_barrage/shaders/barrage_impact_ground.gdshader"
)

var camera: Camera3D
var age := 0.0
var lifetime := 0.5
var importance := 1.0

var _active := false
var _is_impact := false
var _world_position := Vector3.ZERO
var _ray_count := 0
var _rng := RandomNumberGenerator.new()
var _ray_angles := PackedFloat32Array()
var _ray_lengths := PackedFloat32Array()
var _ray_thickness := PackedFloat32Array()
var _ray_delays := PackedFloat32Array()

var _quad_mesh: QuadMesh
var _flare_material: ShaderMaterial
var _ground_material: ShaderMaterial
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _ground_effect: MeshInstance3D
var _rays: Array[MeshInstance3D] = []


func _ready() -> void:
	_ensure_visuals()
	if _active:
		set_as_top_level(true)
		global_position = _world_position


func configure(
	view_camera: Camera3D,
	texture: Texture2D,
	world_position: Vector3,
	visual_importance: float,
	impact: bool,
	seed_value: int
) -> void:
	_ensure_visuals()
	camera = view_camera
	_world_position = world_position
	importance = clampf(visual_importance, 0.0, 1.0)
	_is_impact = impact
	age = 0.0
	lifetime = lerpf(0.92, 1.22, importance) if _is_impact else lerpf(0.36, 0.52, importance)
	_active = true
	visible = true

	var flash_texture := texture if texture != null else DEFAULT_FLASH_TEXTURE
	_flare_material.set_shader_parameter("flare_texture", flash_texture)
	if is_inside_tree():
		set_as_top_level(true)
		global_position = _world_position
	else:
		position = _world_position

	_prepare_rays(seed_value)
	_configure_static_parameters(seed_value)
	_update_visuals()


func advance(fx_delta: float) -> void:
	if not _active:
		return
	age += maxf(fx_delta, 0.0)
	if age >= lifetime:
		_active = false
		_hide_visuals()
		return
	_update_visuals()


func is_finished() -> bool:
	return not _active or age >= lifetime


func recycle() -> void:
	camera = null
	age = 0.0
	_active = false
	visible = false
	_hide_visuals()


func _ensure_visuals() -> void:
	if _core != null:
		return

	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2.ONE

	_flare_material = ShaderMaterial.new()
	_flare_material.shader = FLASH_SHADER
	_flare_material.set_shader_parameter("flare_texture", DEFAULT_FLASH_TEXTURE)

	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER

	_halo = _create_billboard("WideHalo")
	_core = _create_billboard("WhiteCore")
	for index in range(MAX_RAYS):
		var ray := _create_billboard("RadialRay_%02d" % index)
		ray.visible = false
		_rays.append(ray)

	_ground_effect = MeshInstance3D.new()
	_ground_effect.name = "ImpactRingAndDust"
	_ground_effect.mesh = _quad_mesh
	_ground_effect.material_override = _ground_material
	_ground_effect.position = Vector3.UP * 0.075
	_ground_effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_effect.extra_cull_margin = 48.0
	_ground_effect.visible = false
	add_child(_ground_effect)

	_ray_angles.resize(MAX_RAYS)
	_ray_lengths.resize(MAX_RAYS)
	_ray_thickness.resize(MAX_RAYS)
	_ray_delays.resize(MAX_RAYS)
	_hide_visuals()


func _create_billboard(node_name: String) -> MeshInstance3D:
	var billboard := MeshInstance3D.new()
	billboard.name = node_name
	billboard.mesh = _quad_mesh
	billboard.material_override = _flare_material
	billboard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	billboard.extra_cull_margin = 48.0
	add_child(billboard)
	return billboard


func _prepare_rays(seed_value: int) -> void:
	_rng.seed = seed_value
	var minimum_rays := 7 if _is_impact else 4
	var maximum_rays := MAX_RAYS if _is_impact else 7
	_ray_count = clampi(int(round(lerpf(float(minimum_rays), float(maximum_rays), importance))), 1, MAX_RAYS)
	var angular_step := PI / float(_ray_count)
	var angular_offset := _rng.randf_range(-PI, PI)

	for index in range(MAX_RAYS):
		if index >= _ray_count:
			_rays[index].visible = false
			continue
		_ray_angles[index] = angular_offset + angular_step * float(index) + _rng.randf_range(-0.16, 0.16)
		_ray_lengths[index] = _rng.randf_range(0.72, 1.28)
		_ray_thickness[index] = _rng.randf_range(0.72, 1.34)
		_ray_delays[index] = _rng.randf_range(0.0, 0.035 if _is_impact else 0.022)
		_rays[index].position = Vector3.UP * _rng.randf_range(-0.16, 0.38)


func _configure_static_parameters(seed_value: int) -> void:
	_set_flare_static(_halo, 0.0, 0.76)
	_set_flare_static(_core, 0.0, 1.22)
	for index in range(_ray_count):
		_set_flare_static(_rays[index], 1.0, 1.0)
		_rays[index].set_instance_shader_parameter("burst_rotation", _ray_angles[index])

	_ground_effect.set_instance_shader_parameter("ground_color", Color(0.84, 0.86, 0.89, 1.0))
	_ground_effect.set_instance_shader_parameter("burst_seed", float(posmod(seed_value, 8192)))
	_ground_effect.set_instance_shader_parameter(
		"ground_diameter", lerpf(25.0, 44.0, importance)
	)


func _set_flare_static(target: MeshInstance3D, shape: float, softness: float) -> void:
	target.set_instance_shader_parameter("burst_color", Color.WHITE)
	target.set_instance_shader_parameter("burst_shape", shape)
	target.set_instance_shader_parameter("burst_softness", softness)


func _update_visuals() -> void:
	if _is_impact:
		_update_impact()
	else:
		_update_launch()


func _update_launch() -> void:
	var peak_width := lerpf(0.035, 0.052, importance)
	var white_peak := exp(-pow(age / peak_width, 2.0))
	var afterglow := 0.28 * exp(-pow((age - 0.095) / 0.13, 2.0))
	var envelope := white_peak + afterglow
	var expansion := smoothstep(0.0, 0.22, age)

	_set_flare_frame(
		_core,
		lerpf(20.0, 46.0, importance) * envelope,
		clampf(envelope * 1.4, 0.0, 1.0),
		lerpf(1.5, 2.8, importance) * lerpf(0.72, 1.7, expansion),
		lerpf(1.5, 2.8, importance) * lerpf(0.72, 1.7, expansion)
	)
	_set_flare_frame(
		_halo,
		lerpf(3.8, 8.5, importance) * (white_peak + afterglow * 0.55),
		clampf(envelope * 0.72, 0.0, 0.88),
		lerpf(6.0, 13.0, importance) * lerpf(0.72, 1.25, expansion),
		lerpf(6.0, 13.0, importance) * lerpf(0.72, 1.25, expansion)
	)
	_update_rays(false)
	_ground_effect.visible = false


func _update_impact() -> void:
	var peak_width := lerpf(0.042, 0.067, importance)
	var white_peak := exp(-pow(age / peak_width, 2.0))
	var retinal_echo := 0.32 * exp(-pow((age - 0.14) / 0.19, 2.0))
	var envelope := white_peak + retinal_echo
	var expansion := smoothstep(0.0, 0.30, age)

	_set_flare_frame(
		_core,
		lerpf(58.0, 118.0, importance) * envelope,
		clampf(envelope * 1.55, 0.0, 1.0),
		lerpf(4.2, 8.5, importance) * lerpf(0.58, 1.62, expansion),
		lerpf(4.2, 8.5, importance) * lerpf(0.58, 1.62, expansion)
	)
	_set_flare_frame(
		_halo,
		lerpf(8.0, 19.0, importance) * (white_peak + retinal_echo * 0.44),
		clampf(envelope * 0.82, 0.0, 0.92),
		lerpf(15.0, 32.0, importance) * lerpf(0.62, 1.35, expansion),
		lerpf(15.0, 32.0, importance) * lerpf(0.62, 1.35, expansion)
	)
	_update_rays(true)
	_update_ground_effect(white_peak)


func _update_rays(impact: bool) -> void:
	var base_length := lerpf(15.0, 36.0, importance) if impact else lerpf(4.0, 10.0, importance)
	var base_thickness := lerpf(0.22, 0.58, importance) if impact else lerpf(0.10, 0.28, importance)
	var base_energy := lerpf(23.0, 54.0, importance) if impact else lerpf(9.0, 24.0, importance)
	var decay_time := lerpf(0.085, 0.14, importance) if impact else lerpf(0.065, 0.11, importance)

	for index in range(_ray_count):
		var ray := _rays[index]
		var local_age := age - _ray_delays[index]
		if local_age < 0.0:
			ray.visible = false
			continue
		var envelope := exp(-local_age / decay_time)
		envelope *= 1.0 - smoothstep(decay_time * 1.35, decay_time * 3.4, local_age)
		var growth := lerpf(0.38, 1.0, smoothstep(0.0, 0.075, local_age))
		_set_flare_frame(
			ray,
			base_energy * envelope,
			clampf(envelope * 1.3, 0.0, 0.92),
			base_length * _ray_lengths[index] * growth,
			base_thickness * _ray_thickness[index]
		)


func _update_ground_effect(white_peak: float) -> void:
	var ring_progress_value := smoothstep(0.0, lerpf(0.46, 0.68, importance), age)
	var dust_progress_value := smoothstep(0.025, lerpf(0.70, 0.96, importance), age)
	var fade := 1.0 - smoothstep(lifetime * 0.54, lifetime, age)
	var ring_afterglow := exp(-age / lerpf(0.24, 0.38, importance))
	_ground_effect.visible = fade > 0.002
	_ground_effect.set_instance_shader_parameter("ring_progress", ring_progress_value)
	_ground_effect.set_instance_shader_parameter("dust_progress", dust_progress_value)
	_ground_effect.set_instance_shader_parameter(
		"ground_energy", lerpf(2.8, 7.2, importance) * (white_peak + ring_afterglow * 0.46)
	)
	_ground_effect.set_instance_shader_parameter(
		"ground_opacity", clampf(fade * lerpf(0.48, 0.82, importance), 0.0, 0.86)
	)


func _set_flare_frame(
	target: MeshInstance3D,
	energy: float,
	opacity: float,
	width: float,
	height: float
) -> void:
	target.visible = opacity > 0.002 and energy > 0.002
	target.set_instance_shader_parameter("burst_energy", maxf(energy, 0.0))
	target.set_instance_shader_parameter("burst_opacity", clampf(opacity, 0.0, 1.0))
	target.set_instance_shader_parameter("burst_width", maxf(width, 0.001))
	target.set_instance_shader_parameter("burst_height", maxf(height, 0.001))


func _hide_visuals() -> void:
	if _core == null:
		return
	_core.visible = false
	_halo.visible = false
	_ground_effect.visible = false
	for ray in _rays:
		ray.visible = false
