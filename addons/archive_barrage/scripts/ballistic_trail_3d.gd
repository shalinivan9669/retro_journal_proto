class_name BallisticTrail3D
extends MeshInstance3D

const TRAIL_SHADER := preload("res://addons/archive_barrage/shaders/tracer_trail.gdshader")

var camera: Camera3D
var launch_position := Vector3.ZERO
var initial_velocity := Vector3.ZERO
var gravity := Vector3(0.0, -7.2, 0.0)
var wind := Vector3(2.2, 0.0, 0.6)
var flight_time := 12.0
var trail_lifetime := 10.5
var sample_step := 1.0 / 32.0
var halo_pixels := 11.0
var importance := 1.0
var elapsed := 0.0

var _immediate_mesh := ImmediateMesh.new()
var _trail_material: ShaderMaterial


func configure(
	view_camera: Camera3D,
	start: Vector3,
	velocity: Vector3,
	duration: float,
	trail_duration: float,
	visual_importance: float,
	trail_seed: float
) -> void:
	camera = view_camera
	launch_position = start
	initial_velocity = velocity
	flight_time = duration
	trail_lifetime = trail_duration
	importance = visual_importance
	elapsed = 0.0
	visible = true
	halo_pixels = lerpf(7.5, 15.0, clampf(importance, 0.0, 1.0))

	if _trail_material == null:
		_trail_material = ShaderMaterial.new()
		_trail_material.shader = TRAIL_SHADER
	_trail_material.set_shader_parameter("seed", trail_seed)
	_trail_material.set_shader_parameter("core_energy", lerpf(18.0, 42.0, importance))
	_trail_material.set_shader_parameter("halo_energy", lerpf(2.7, 7.0, importance))
	_trail_material.set_shader_parameter("head_energy", lerpf(38.0, 108.0, importance))

	mesh = _immediate_mesh
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild_mesh()


func recycle() -> void:
	camera = null
	elapsed = 0.0
	visible = false
	_immediate_mesh.clear_surfaces()


func advance(fx_delta: float) -> void:
	elapsed += fx_delta
	_rebuild_mesh()


func is_finished() -> bool:
	return elapsed > flight_time + trail_lifetime


func head_position() -> Vector3:
	return _ballistic_position(minf(elapsed, flight_time), 0.0)


func head_intensity() -> float:
	if elapsed > flight_time:
		return 0.0
	var end_fade := 1.0 - smoothstep(0.82, 1.0, elapsed / maxf(flight_time, 0.001))
	return importance * end_fade


func _ballistic_position(sample_time: float, smoke_age: float) -> Vector3:
	var p := launch_position
	p += initial_velocity * sample_time
	p += gravity * (0.5 * sample_time * sample_time)

	var drag_tau := 1.4
	var drift_factor := smoke_age - drag_tau * (1.0 - exp(-smoke_age / drag_tau))
	var drift := wind * maxf(drift_factor, 0.0)

	var curl := (
		Vector3(
			sin(sample_time * 3.7 + smoke_age * 1.3),
			0.25 * sin(sample_time * 2.1),
			cos(sample_time * 3.1 - smoke_age)
		)
		* minf(smoke_age * 0.12, 0.8)
	)

	return p + drift + curl


func _world_width(point: Vector3, pixels: float) -> float:
	var distance := camera.global_position.distance_to(point)
	var viewport_height := get_viewport().get_visible_rect().size.y
	var fov_y := deg_to_rad(camera.fov)
	var pixel_width := 2.0 * distance * tan(fov_y * 0.5) * pixels / viewport_height
	return maxf(0.20, pixel_width)


func _rebuild_mesh() -> void:
	_immediate_mesh.clear_surfaces()
	if camera == null:
		return

	var end_time := minf(elapsed, flight_time)
	var begin_time := maxf(0.0, elapsed - trail_lifetime)
	if begin_time >= end_time:
		return

	var count := maxi(2, int(ceil((end_time - begin_time) / sample_step)) + 1)
	var points := PackedVector3Array()
	var ages := PackedFloat32Array()

	for index in range(count):
		var fraction := float(index) / float(count - 1)
		var sample_time := lerpf(begin_time, end_time, fraction)
		var smoke_age := elapsed - sample_time
		points.append(_ballistic_position(sample_time, smoke_age))
		ages.append(clampf(smoke_age / trail_lifetime, 0.0, 1.0))

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_material)
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var next := points[mini(index + 1, points.size() - 1)]
		var tangent := (next - previous).normalized()
		var view := (camera.global_position - points[index]).normalized()
		var side := tangent.cross(view).normalized()
		if side.length_squared() < 0.001:
			side = camera.global_basis.x

		var age := ages[index]
		var pixels := lerpf(halo_pixels, halo_pixels * 1.35, age)
		var half_width := _world_width(points[index], pixels) * 0.5

		_immediate_mesh.surface_set_uv(Vector2(age, 0.0))
		_immediate_mesh.surface_add_vertex(points[index] - side * half_width)
		_immediate_mesh.surface_set_uv(Vector2(age, 1.0))
		_immediate_mesh.surface_add_vertex(points[index] + side * half_width)
	_immediate_mesh.surface_end()
