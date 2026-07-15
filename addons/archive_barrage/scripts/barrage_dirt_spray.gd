class_name BarrageDirtSpray
extends MeshInstance3D

const SPRAY_SHADER := preload(
	"res://addons/archive_barrage/shaders/barrage_dirt_spray.gdshader"
)
const SPRAY_GRAVITY := Vector3(0.0, -18.0, 0.0)
const SPRAY_WIND := Vector3(2.2, 0.0, 0.6)

var camera: Camera3D
var terrain: BarrageTerrain
var age := 0.0
var lifetime := 2.0
var importance := 1.0
var impact_angle_degrees := 90.0
var fan_half_angle_degrees := 180.0

var _active := false
var _origin := Vector3.ZERO
var _jet_count := 0
var _performance_mode := false
var _rng := RandomNumberGenerator.new()
var _velocities: Array[Vector3] = []
var _delays := PackedFloat32Array()
var _drags := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _trail_spans := PackedFloat32Array()
var _widths := PackedFloat32Array()
var _pixel_widths := PackedFloat32Array()
var _brightness := PackedFloat32Array()
var _phases := PackedFloat32Array()
var _clods := PackedByteArray()
var _immediate_mesh := ImmediateMesh.new()
var _material: ShaderMaterial


func configure(
	view_camera: Camera3D,
	target_terrain: BarrageTerrain,
	world_position: Vector3,
	incoming_velocity: Vector3,
	surface_normal: Vector3,
	visual_importance: float,
	seed_value: int,
	use_performance_profile: bool = false
) -> void:
	camera = view_camera
	terrain = target_terrain
	_origin = world_position + surface_normal.normalized() * 0.10
	importance = clampf(visual_importance, 0.0, 1.0)
	_performance_mode = use_performance_profile
	age = 0.0
	_active = true
	visible = true
	_rng.seed = seed_value
	_ensure_material()

	mesh = _immediate_mesh
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 72.0

	_prepare_jets(incoming_velocity, surface_normal)
	_update_material()
	_rebuild_mesh()


func advance(fx_delta: float) -> void:
	if not _active:
		return
	age += maxf(fx_delta, 0.0)
	if age >= lifetime:
		_active = false
		visible = false
		_immediate_mesh.clear_surfaces()
		return
	_update_material()
	_rebuild_mesh()


func is_finished() -> bool:
	return not _active or age >= lifetime


func recycle() -> void:
	camera = null
	terrain = null
	age = 0.0
	_active = false
	visible = false
	_immediate_mesh.clear_surfaces()


func _ensure_material() -> void:
	if _material != null:
		return
	_material = ShaderMaterial.new()
	_material.shader = SPRAY_SHADER
	_material.set_shader_parameter("dirt_color", Color(0.040, 0.037, 0.034, 1.0))
	_material.set_shader_parameter("flash_tint", Color(0.72, 0.78, 0.88, 1.0))
	material_override = _material


func _prepare_jets(incoming_velocity: Vector3, surface_normal: Vector3) -> void:
	_velocities.clear()
	_delays.clear()
	_drags.clear()
	_lifetimes.clear()
	_trail_spans.clear()
	_widths.clear()
	_pixel_widths.clear()
	_brightness.clear()
	_phases.clear()
	_clods.clear()

	var normal := surface_normal.normalized()
	if normal.length_squared() < 0.5:
		normal = Vector3.UP
	var incoming := incoming_velocity.normalized()
	if incoming.length_squared() < 0.5:
		incoming = Vector3.DOWN
	var steepness := clampf(-incoming.dot(normal), 0.0, 1.0)
	impact_angle_degrees = rad_to_deg(asin(steepness))
	var downrange := incoming.slide(normal)
	if downrange.length_squared() < 0.0001:
		downrange = normal.cross(Vector3.RIGHT)
		if downrange.length_squared() < 0.0001:
			downrange = normal.cross(Vector3.FORWARD)
	downrange = downrange.normalized()
	var crossrange := normal.cross(downrange).normalized()
	var reflected := (incoming - 2.0 * incoming.dot(normal) * normal).normalized()

	var minimum_jets := 14 if _performance_mode else 26
	var maximum_jets := 30 if _performance_mode else 54
	_jet_count = maxi(1, int(round(lerpf(float(minimum_jets), float(maximum_jets), importance))))
	var steep_blend := smoothstep(0.30, 0.94, steepness)
	var fan_half_angle := lerpf(deg_to_rad(42.0), deg_to_rad(176.0), steep_blend)
	fan_half_angle_degrees = rad_to_deg(fan_half_angle)
	# A full-importance impact throws the fastest narrow streams at roughly
	# 45 m/s.  Together with the 18 m/s^2 effective gravity this produces the
	# 10-25 m early plume seen in large wet-soil impacts without turning the
	# debris into the much larger shell tracer arcs.
	var speed_scale := lerpf(18.0, 46.0, importance)
	lifetime = 0.0

	for index in range(_jet_count):
		var stratum := (float(index) + _rng.randf_range(0.18, 0.82)) / float(_jet_count)
		var signed_fan := stratum * 2.0 - 1.0
		var centrality := 1.0 - absf(signed_fan)
		var azimuth := signed_fan * fan_half_angle + _rng.randf_range(-0.085, 0.085)
		var horizontal := (
			downrange * cos(azimuth) + crossrange * sin(azimuth)
		).normalized()
		# Steep shells excavate a broad crown: some soil skims the surface while
		# other jets rise almost vertically.  A shallow hit keeps a lower,
		# downrange-biased cone.  The exponent avoids an artificial even fan.
		var elevation_floor := lerpf(deg_to_rad(8.0), deg_to_rad(12.0), steepness)
		var elevation_ceiling := lerpf(deg_to_rad(56.0), deg_to_rad(84.0), steepness)
		var elevation_sample := pow(
			_rng.randf(), lerpf(1.35, 0.72, steepness)
		)
		var elevation := lerpf(elevation_floor, elevation_ceiling, elevation_sample)
		elevation += deg_to_rad(lerpf(7.0, 3.0, steepness)) * pow(centrality, 0.72)
		elevation += deg_to_rad(_rng.randf_range(-4.0, 5.0))
		elevation = clampf(elevation, deg_to_rad(11.0), deg_to_rad(79.0))
		var direction := (
			horizontal * cos(elevation) + normal * sin(elevation)
		).normalized()
		var reflection_bias := (1.0 - steepness) * lerpf(0.22, 0.42, centrality)
		direction = (direction * (1.0 - reflection_bias) + reflected * reflection_bias).normalized()

		var fine_stream := _rng.randf() > 0.24
		var speed_variation := _rng.randf_range(0.78, 1.18)
		var central_speed := lerpf(0.72, 1.30, pow(centrality, 0.60))
		var stream_speed := speed_scale * speed_variation * central_speed
		if not fine_stream:
			stream_speed *= _rng.randf_range(0.58, 0.82)
		_velocities.append(direction * stream_speed + normal * _rng.randf_range(0.8, 3.1))
		_delays.append(_rng.randf_range(0.0, 0.075))
		_drags.append(_rng.randf_range(0.34, 0.92) if fine_stream else _rng.randf_range(0.75, 1.28))
		var jet_lifetime := lerpf(1.15, 2.20, importance) * _rng.randf_range(0.80, 1.16)
		if not fine_stream:
			jet_lifetime *= _rng.randf_range(0.58, 0.78)
		_lifetimes.append(jet_lifetime)
		_trail_spans.append(
			_rng.randf_range(0.28, 0.62) if fine_stream else _rng.randf_range(0.11, 0.28)
		)
		_widths.append(
			_rng.randf_range(0.045, 0.13) if fine_stream else _rng.randf_range(0.12, 0.30)
		)
		_pixel_widths.append(
			_rng.randf_range(1.45, 2.85) if fine_stream else _rng.randf_range(2.2, 4.2)
		)
		_brightness.append(_rng.randf_range(0.62, 1.0))
		_phases.append(_rng.randf())
		_clods.append(0 if fine_stream else 1)
		lifetime = maxf(lifetime, _delays[index] + jet_lifetime)


func _update_material() -> void:
	# Mirror the local impact light: a hard ignition peak followed by a weaker
	# illumination tail.  The material remains black once this envelope dies.
	var peak_width := lerpf(0.075, 0.11, importance)
	var white_flash := exp(-pow(age / peak_width, 2.0))
	var hot_dust := 0.46 * exp(-age / lerpf(0.28, 0.40, importance))
	_material.set_shader_parameter(
		"flash_energy", lerpf(2.8, 6.2, importance) * (white_flash + hot_dust)
	)


func _position_with_drag(index: int, local_age: float) -> Vector3:
	if local_age <= 0.0:
		return _origin
	var drag := maxf(_drags[index], 0.001)
	var terminal_velocity := SPRAY_WIND + SPRAY_GRAVITY / drag
	var decay := exp(-drag * local_age)
	return (
		_origin
		+ terminal_velocity * local_age
		+ (_velocities[index] - terminal_velocity) * ((1.0 - decay) / drag)
	)


func _world_width(point: Vector3, physical_width: float, pixels: float) -> float:
	if camera == null:
		return physical_width
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var distance := camera.global_position.distance_to(point)
	var pixel_width := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5) * pixels / viewport_height
	return maxf(physical_width, pixel_width)


func _rebuild_mesh() -> void:
	_immediate_mesh.clear_surfaces()
	if camera == null or _jet_count <= 0:
		return

	var surface_started := false
	for index in range(_jet_count):
		var local_age := age - _delays[index]
		var jet_lifetime := _lifetimes[index]
		if local_age <= 0.0 or local_age >= jet_lifetime:
			continue

		var head := _position_with_drag(index, local_age)
		if terrain != null and local_age > 0.12:
			var ground_y := terrain.height_at_world(head.x, head.z) + 0.055
			if head.y <= ground_y:
				continue
		var previous_age := maxf(local_age - _trail_spans[index], 0.0)
		var tail := _position_with_drag(index, previous_age)
		if head.distance_squared_to(tail) < 0.0001:
			continue
		var progress := local_age / maxf(jet_lifetime, 0.001)
		var spawn := smoothstep(0.0, 0.055, local_age)
		var fade := 1.0 - smoothstep(0.56, 1.0, progress)
		var opacity := spawn * fade * lerpf(0.62, 0.94, importance)
		var vertex_color := Color(_brightness[index], _phases[index], 0.0, opacity)

		# Sample the closed-form trajectory into a short ribbon.  Five pieces are
		# enough for visible gravity/drag curvature at cinematic quality; the
		# performance profile uses three.
		var segment_count := 3 if _performance_mode else 5
		for segment in range(segment_count):
			var u0 := float(segment) / float(segment_count)
			var u1 := float(segment + 1) / float(segment_count)
			var time0 := lerpf(previous_age, local_age, u0)
			var time1 := lerpf(previous_age, local_age, u1)
			var point0 := _position_with_drag(index, time0)
			var point1 := _position_with_drag(index, time1)
			var tangent := point1 - point0
			if tangent.length_squared() < 0.0001:
				continue
			tangent = tangent.normalized()
			var midpoint := (point0 + point1) * 0.5
			var view := (camera.global_position - midpoint).normalized()
			var side := tangent.cross(view).normalized()
			if side.length_squared() < 0.001:
				side = camera.global_basis.x
			var face_normal := side.cross(tangent).normalized()
			var width := _world_width(midpoint, _widths[index], _pixel_widths[index])
			var width0 := width * (0.20 + 0.80 * pow(sin(PI * u0), 0.55))
			var width1 := width * (0.20 + 0.80 * pow(sin(PI * u1), 0.55))
			var point0_left := point0 - side * width0
			var point0_right := point0 + side * width0
			var point1_left := point1 - side * width1
			var point1_right := point1 + side * width1
			if not surface_started:
				_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
				surface_started = true
			_emit_vertex(point0_left, face_normal, Vector2(u0, 0.0), vertex_color)
			_emit_vertex(point0_right, face_normal, Vector2(u0, 1.0), vertex_color)
			_emit_vertex(point1_right, face_normal, Vector2(u1, 1.0), vertex_color)
			_emit_vertex(point0_left, face_normal, Vector2(u0, 0.0), vertex_color)
			_emit_vertex(point1_right, face_normal, Vector2(u1, 1.0), vertex_color)
			_emit_vertex(point1_left, face_normal, Vector2(u1, 0.0), vertex_color)

		# The high-drag population represents coherent wet clods.  A small
		# camera-facing head makes those masses read as droplets rather than a
		# second family of perfectly straight light streaks.
		if _clods[index] != 0:
			var clod_radius := _world_width(
				head, _widths[index] * 1.45, _pixel_widths[index] * 1.18
			)
			var camera_right := camera.global_basis.x.normalized()
			var camera_up := camera.global_basis.y.normalized()
			var clod_normal := (camera.global_position - head).normalized()
			var clod_color := Color(
				_brightness[index], _phases[index], 1.0, opacity
			)
			var bottom_left := head - camera_right * clod_radius - camera_up * clod_radius
			var bottom_right := head + camera_right * clod_radius - camera_up * clod_radius
			var top_left := head - camera_right * clod_radius + camera_up * clod_radius
			var top_right := head + camera_right * clod_radius + camera_up * clod_radius
			_emit_vertex(bottom_left, clod_normal, Vector2(0.0, 1.0), clod_color)
			_emit_vertex(bottom_right, clod_normal, Vector2(1.0, 1.0), clod_color)
			_emit_vertex(top_right, clod_normal, Vector2(1.0, 0.0), clod_color)
			_emit_vertex(bottom_left, clod_normal, Vector2(0.0, 1.0), clod_color)
			_emit_vertex(top_right, clod_normal, Vector2(1.0, 0.0), clod_color)
			_emit_vertex(top_left, clod_normal, Vector2(0.0, 0.0), clod_color)
	if surface_started:
		_immediate_mesh.surface_end()


func _emit_vertex(position: Vector3, normal: Vector3, uv: Vector2, color: Color) -> void:
	_immediate_mesh.surface_set_normal(normal)
	_immediate_mesh.surface_set_uv(uv)
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_add_vertex(position)
