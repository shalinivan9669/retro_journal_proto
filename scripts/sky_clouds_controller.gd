extends Node

const CLOUD_TEXTURE_DIR := "res://assets/textures/sky/clouds_runtime_clean"
const FIELD_HALF_EXTENTS := Vector2(430.0, 320.0)
const FOLLOW_PLAYER := true

const FAR_CLOUDS := "FAR_CLOUDS"
const MID_CLOUDS := "MID_CLOUDS"
const ACCENT_CLOUDS := "ACCENT_CLOUDS"

const CLOUD_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint_color : source_color = vec4(0.82, 0.34, 0.28, 0.82);
uniform vec2 uv_flow_direction = vec2(1.0, -0.25);
uniform float uv_flow_speed : hint_range(0.0, 0.12) = 0.026;
uniform float distortion_strength : hint_range(0.0, 0.06) = 0.012;
uniform float distortion_phase = 0.0;
uniform float opacity_boost : hint_range(0.0, 2.5) = 1.35;
uniform float color_boost : hint_range(0.2, 2.5) = 1.18;
uniform float contrast_boost : hint_range(0.2, 2.5) = 1.22;
uniform float alpha_power : hint_range(0.25, 1.4) = 0.68;
uniform float alpha_cutoff : hint_range(0.0, 0.08) = 0.012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 dir = uv_flow_direction;
	if (length(dir) < 0.001) {
		dir = vec2(1.0, -0.25);
	}
	dir = normalize(dir);

	// Two internal flows moving at different angles. This keeps the PNG card,
	// but makes the cloud mass feel pulled by wind instead of frozen.
	float t = TIME * uv_flow_speed + distortion_phase;
	float n1 = noise(UV * 2.9 + dir * t * 1.35 + vec2(t * 0.28, -t * 0.19));
	float n2 = noise(UV * 5.8 - dir.yx * t * 0.92 + vec2(-t * 0.16, t * 0.31));
	float n3 = noise(UV * 9.7 + vec2(t * 0.07, t * 0.11));

	vec2 uv_distortion = (vec2(n1, n2) - vec2(0.5)) * distortion_strength;
	uv_distortion += dir * (n3 - 0.5) * distortion_strength * 0.38;

	vec2 cloud_uv = clamp(UV + uv_distortion, vec2(0.001), vec2(0.999));
	vec4 cloud = texture(cloud_texture, cloud_uv);

	if (cloud.a < alpha_cutoff) {
		discard;
	}

	float shaped_alpha = pow(max(cloud.a, 0.0), alpha_power);
	float final_alpha = clamp(shaped_alpha * tint_color.a * opacity_boost, 0.0, 0.97);
	if (final_alpha <= 0.001) {
		discard;
	}

	float luma = dot(cloud.rgb, vec3(0.31, 0.34, 0.35));
	vec3 detail = mix(vec3(luma), cloud.rgb, 0.42);
	vec3 tinted = mix(detail, tint_color.rgb, 0.68);
	tinted = (tinted - vec3(0.5)) * contrast_boost + vec3(0.5);
	tinted *= color_boost;

	ALBEDO = clamp(tinted, vec3(0.0), vec3(1.25));
	ALPHA = final_alpha;
}
"""

@export_range(0.1, 3.0, 0.1) var speed_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.1) var chaos_multiplier: float = 0.75
@export_range(0.25, 2.0, 0.05) var density_multiplier: float = 1.0
@export var cloud_height_offset: float = 0.0

@export_group("Wind Flow")
@export var wind_direction: Vector2 = Vector2(1.0, -0.25).normalized()
@export_range(0.0, 5.0, 0.05) var wind_strength: float = 2.35
@export_range(0.0, 4.0, 0.05) var far_layer_speed: float = 0.72
@export_range(0.0, 4.0, 0.05) var mid_layer_speed: float = 1.55
@export_range(0.0, 4.0, 0.05) var accent_layer_speed: float = 2.25
@export_range(0.0, 4.0, 0.05) var secondary_current_strength: float = 1.35
@export_range(0.0, 4.0, 0.05) var high_current_strength: float = 0.75
@export_range(0.0, 3.0, 0.01) var turbulence_strength: float = 1.25
@export_range(0.0, 2.0, 0.01) var rotation_drift_strength: float = 1.0
@export_range(0.0, 2.0, 0.01) var scale_breath_strength: float = 1.0

@export_group("Cloud Visibility")
@export_range(0.25, 2.5, 0.05) var cloud_opacity_multiplier: float = 1.45
@export_range(0.25, 2.5, 0.05) var cloud_color_multiplier: float = 1.22
@export_range(0.25, 2.5, 0.05) var cloud_contrast_multiplier: float = 1.28
@export_range(0.25, 1.4, 0.01) var cloud_alpha_power: float = 0.66
@export_range(0.0, 0.08, 0.001) var cloud_alpha_cutoff: float = 0.012

@export_group("References")
@export var player_path: NodePath = NodePath("../Player")

var _cloud_root: Node3D
var _player: Node3D
var _cloud_records: Array[Dictionary] = []
var _cloud_shader: Shader


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	if _player == null and get_tree().current_scene != null:
		_player = get_tree().current_scene.find_child("Player", true, false) as Node3D

	_rebuild_clouds.call_deferred()


func _process(delta: float) -> void:
	if _cloud_root == null:
		return

	if FOLLOW_PLAYER and _player != null:
		_cloud_root.global_position.x = _player.global_position.x
		_cloud_root.global_position.z = _player.global_position.z

	var time := Time.get_ticks_msec() * 0.001
	var wind_axis := _shared_wind_direction()
	var crosswind_axis := _crosswind_direction()

	for record in _cloud_records:
		var cloud := record["node"] as Node3D
		if cloud == null:
			continue

		_update_cloud_material(record)

		var layer_speed: float = record["layer_speed"]
		var wind_factor: float = record["wind_factor"]

		# Main steppe wind: persistent directional travel.
		var base_wind_velocity: Vector3 = wind_axis * layer_speed * wind_factor * wind_strength

		# Stream A: lower, broad side flow. This creates visible parallax instead of a flat scroll.
		var stream_a_wave: float = sin(time * record["stream_a_speed"] + record["stream_a_phase"])
		var stream_a_velocity: Vector3 = crosswind_axis * stream_a_wave * record["stream_a_amount"] * secondary_current_strength

		# Stream B: higher-altitude shear moving partly against the side flow.
		var stream_b_wave: float = cos(time * record["stream_b_speed"] + record["stream_b_phase"])
		var stream_b_axis: Vector3 = (wind_axis * 0.58 + crosswind_axis * record["stream_b_side"]).normalized()
		var stream_b_velocity: Vector3 = stream_b_axis * stream_b_wave * record["stream_b_amount"] * high_current_strength

		# Small personal variation per cloud so the cards do not lock into one formation.
		var local_velocity: Vector3 = record["velocity"]

		var velocity: Vector3 = (base_wind_velocity + stream_a_velocity + stream_b_velocity + local_velocity) * speed_multiplier
		var motion_position: Vector3 = record["motion_position"]
		motion_position += velocity * delta
		motion_position = _wrap_position(motion_position)
		record["motion_position"] = motion_position

		var turbulence_axis: Vector3 = record["turbulence_axis"]
		var turbulence_wave: float = sin(time * record["turbulence_speed"] + record["turbulence_phase"])
		var wind_pulse: float = sin(time * record["turbulence_speed"] * 0.43 + record["turbulence_phase"] * 0.37)
		var flow_wave: float = sin(time * record["flow_speed"] + record["flow_phase"])
		var flow_curve: float = cos(time * record["flow_speed"] * 0.63 + record["flow_phase"] * 0.71)

		var flow_amount: float = record["flow_amount"]
		var flow_offset: Vector3 = crosswind_axis * flow_wave * flow_amount
		flow_offset += wind_axis * flow_curve * flow_amount * 0.28

		var drift_offset: Vector3 = turbulence_axis * turbulence_wave * record["turbulence_amount"] * chaos_multiplier * turbulence_strength
		drift_offset += wind_axis * wind_pulse * record["wind_pulse_amount"] * chaos_multiplier * turbulence_strength
		drift_offset += flow_offset * turbulence_strength

		var vertical_breath: float = sin(time * record["vertical_speed"] + record["vertical_phase"]) * record["vertical_amount"] * chaos_multiplier * turbulence_strength
		cloud.position = motion_position + drift_offset
		cloud.position.y = record["base_y"] + vertical_breath

		var rotation_wave: float = sin(time * record["rotation_speed"] + record["rotation_phase"])
		var base_rotation: Vector3 = record["base_rotation"]
		cloud.rotation_degrees = base_rotation + Vector3(0.0, rotation_wave * record["rotation_amount"] * rotation_drift_strength, 0.0)

		var scale_wave: float = sin(time * record["scale_speed"] + record["scale_phase"])
		var scale_factor: float = 1.0 + scale_wave * record["scale_amount"] * scale_breath_strength
		cloud.scale = record["base_scale"] * scale_factor


func _rebuild_clouds() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var old_root := scene.get_node_or_null("SkyClouds")
	if old_root != null:
		old_root.queue_free()

	_cloud_records.clear()
	_cloud_root = Node3D.new()
	_cloud_root.name = "SkyClouds"
	scene.add_child(_cloud_root)

	var far_layer := _make_layer(FAR_CLOUDS)
	var mid_layer := _make_layer(MID_CLOUDS)
	var accent_layer := _make_layer(ACCENT_CLOUDS)
	var cloud_paths := _discover_cloud_pngs()

	for index in range(cloud_paths.size()):
		var layer_name := _layer_name_for_index(index, cloud_paths.size())
		var layer_node := far_layer
		if layer_name == MID_CLOUDS:
			layer_node = mid_layer
		elif layer_name == ACCENT_CLOUDS:
			layer_node = accent_layer

		var layer_index := _count_existing_clouds(layer_node)
		_create_cloud(layer_node, cloud_paths[index], layer_name, layer_index, index)


func _make_layer(layer_name: String) -> Node3D:
	var layer := Node3D.new()
	layer.name = layer_name
	_cloud_root.add_child(layer)
	return layer


func _discover_cloud_pngs() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(CLOUD_TEXTURE_DIR)
	if dir == null:
		return paths

	for file_name in dir.get_files():
		var lower := file_name.to_lower()
		if file_name.get_extension().to_lower() != "png":
			continue
		if lower.contains("checkerboard") or lower.contains("source") or lower.contains("tonemap") or lower.contains("preview"):
			continue
		paths.append("%s/%s" % [CLOUD_TEXTURE_DIR, file_name])

	paths.sort()
	return paths


func _layer_name_for_index(index: int, total: int) -> String:
	var accent_count := mini(4, maxi(2, int(ceil(float(total) * 0.25))))
	var far_count := maxi(3, int(floor(float(total) * 0.34)))
	if index < far_count:
		return FAR_CLOUDS
	if index >= total - accent_count:
		return ACCENT_CLOUDS
	return MID_CLOUDS


func _count_existing_clouds(layer: Node) -> int:
	var count := 0
	for child in layer.get_children():
		if child is MeshInstance3D:
			count += 1
	return count


func _create_cloud(layer: Node3D, texture_path: String, layer_name: String, layer_index: int, global_index: int) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return

	var layout := _layout_for(layer_name, layer_index)
	var cloud := MeshInstance3D.new()
	cloud.name = "Cloud_%02d_%s" % [global_index + 1, texture_path.get_file().get_basename()]
	cloud.mesh = _make_cloud_mesh(layout["size"] * density_multiplier)
	cloud.position = layout["position"] + Vector3(0.0, cloud_height_offset, 0.0)
	cloud.rotation_degrees = layout["rotation"]
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := _make_cloud_material(texture, layout["color"], layer_name, global_index)
	cloud.set_surface_override_material(0, material)
	layer.add_child(cloud)

	var turbulence_scale := _layer_turbulence_multiplier(layer_name)
	var phase_seed := float(global_index) * 1.37 + float(layer_index) * 0.61
	var stream_side := -1.0
	if global_index % 2 == 0:
		stream_side = 1.0

	_cloud_records.append({
		"node": cloud,
		"material": material,
		"layer_name": layer_name,
		"global_index": global_index,
		"motion_position": cloud.position,
		"velocity": _cloud_velocity(layer_name, global_index),
		"base_y": cloud.position.y,
		"base_rotation": cloud.rotation_degrees,
		"base_scale": cloud.scale,
		"layer_speed": _layer_speed(layer_name),
		"wind_factor": 0.95 + fposmod(float(global_index * 23), 27.0) / 100.0,
		"turbulence_axis": _turbulence_axis(global_index),
		"turbulence_phase": phase_seed,
		"turbulence_speed": (0.050 + fposmod(float(global_index) * 0.0091, 0.045)) * turbulence_scale,
		"turbulence_amount": (4.6 + fposmod(float(global_index * 17), 7.4)) * turbulence_scale,
		"wind_pulse_amount": (2.2 + fposmod(float(global_index * 13), 2.25)) * turbulence_scale,
		"rotation_phase": phase_seed * 0.83 + 0.4,
		"rotation_speed": (0.018 + fposmod(float(global_index * 7), 11.0) / 1000.0) * turbulence_scale,
		"rotation_amount": _layer_rotation_amount(layer_name, global_index),
		"scale_phase": phase_seed * 1.19 + 1.6,
		"scale_speed": (0.030 + fposmod(float(global_index * 5), 13.0) / 1000.0) * turbulence_scale,
		"scale_amount": _layer_scale_amount(layer_name, global_index),
		"flow_phase": phase_seed * 0.57 + 2.1,
		"flow_speed": (0.066 + fposmod(float(global_index * 3), 19.0) / 1000.0) * turbulence_scale,
		"flow_amount": _layer_flow_amount(layer_name, global_index),
		"vertical_phase": phase_seed * 1.41,
		"vertical_speed": (0.055 + fposmod(float(global_index * 11), 17.0) / 1000.0) * turbulence_scale,
		"vertical_amount": _layer_vertical_amount(layer_name, global_index),
		"stream_a_phase": phase_seed * 0.44 + 0.9,
		"stream_a_speed": (0.032 + fposmod(float(global_index * 13), 15.0) / 1000.0) * turbulence_scale,
		"stream_a_amount": _layer_stream_a_amount(layer_name, global_index),
		"stream_b_phase": phase_seed * 0.72 + 2.8,
		"stream_b_speed": (0.019 + fposmod(float(global_index * 19), 12.0) / 1000.0) * turbulence_scale,
		"stream_b_amount": _layer_stream_b_amount(layer_name, global_index),
		"stream_b_side": stream_side
	})


func _make_cloud_mesh(size: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1
	return mesh


func _make_cloud_material(texture: Texture2D, color: Color, layer_name: String, global_index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_cloud_shader()
	material.render_priority = _layer_render_priority(layer_name)
	material.set_shader_parameter("cloud_texture", texture)
	material.set_shader_parameter("tint_color", _cloud_tint(color))
	material.set_shader_parameter("uv_flow_direction", _shared_wind_direction_uv())
	material.set_shader_parameter("uv_flow_speed", _layer_shader_flow_speed(layer_name, global_index))
	material.set_shader_parameter("distortion_strength", _layer_shader_distortion(layer_name) * turbulence_strength)
	material.set_shader_parameter("distortion_phase", float(global_index) * 1.917)
	material.set_shader_parameter("opacity_boost", _layer_opacity_boost(layer_name) * cloud_opacity_multiplier)
	material.set_shader_parameter("color_boost", _layer_color_boost(layer_name) * cloud_color_multiplier)
	material.set_shader_parameter("contrast_boost", cloud_contrast_multiplier)
	material.set_shader_parameter("alpha_power", cloud_alpha_power)
	material.set_shader_parameter("alpha_cutoff", cloud_alpha_cutoff)
	return material


func _update_cloud_material(record: Dictionary) -> void:
	var material := record["material"] as ShaderMaterial
	if material == null:
		return

	var layer_name: String = record["layer_name"]
	var global_index: int = record["global_index"]
	material.set_shader_parameter("uv_flow_direction", _shared_wind_direction_uv())
	material.set_shader_parameter("uv_flow_speed", _layer_shader_flow_speed(layer_name, global_index))
	material.set_shader_parameter("distortion_strength", _layer_shader_distortion(layer_name) * turbulence_strength)
	material.set_shader_parameter("opacity_boost", _layer_opacity_boost(layer_name) * cloud_opacity_multiplier)
	material.set_shader_parameter("color_boost", _layer_color_boost(layer_name) * cloud_color_multiplier)
	material.set_shader_parameter("contrast_boost", cloud_contrast_multiplier)
	material.set_shader_parameter("alpha_power", cloud_alpha_power)
	material.set_shader_parameter("alpha_cutoff", cloud_alpha_cutoff)


func _get_cloud_shader() -> Shader:
	if _cloud_shader == null:
		_cloud_shader = Shader.new()
		_cloud_shader.code = CLOUD_SHADER_CODE
	return _cloud_shader


func _cloud_tint(color: Color) -> Color:
	return Color(
		minf(color.r * 1.28 + 0.10, 1.0),
		minf(color.g * 0.92 + 0.06, 0.72),
		minf(color.b * 0.86 + 0.05, 0.64),
		minf(color.a * 1.72 + 0.12, 0.94)
	)


func _layout_for(layer_name: String, layer_index: int) -> Dictionary:
	if layer_name == FAR_CLOUDS:
		return _far_layout(layer_index)
	if layer_name == ACCENT_CLOUDS:
		return _accent_layout(layer_index)
	return _mid_layout(layer_index)


func _far_layout(index: int) -> Dictionary:
	var layouts := [
		{"position": Vector3(-365.0, 112.0, -250.0), "size": Vector2(320.0, 178.0), "rotation": Vector3(0.0, -24.0, 0.0), "color": Color(0.64, 0.34, 0.30, 0.50)},
		{"position": Vector3(-105.0, 106.0, -308.0), "size": Vector2(284.0, 156.0), "rotation": Vector3(0.0, 11.0, 0.0), "color": Color(0.58, 0.31, 0.28, 0.46)},
		{"position": Vector3(212.0, 118.0, -224.0), "size": Vector2(340.0, 172.0), "rotation": Vector3(0.0, 32.0, 0.0), "color": Color(0.68, 0.33, 0.30, 0.52)},
		{"position": Vector3(385.0, 124.0, -72.0), "size": Vector2(268.0, 142.0), "rotation": Vector3(0.0, -37.0, 0.0), "color": Color(0.56, 0.30, 0.27, 0.44)}
	]
	return _layout_from_table(layouts, index, Vector3(-42.0, 5.0, 118.0))


func _mid_layout(index: int) -> Dictionary:
	var layouts := [
		{"position": Vector3(-315.0, 88.0, -126.0), "size": Vector2(238.0, 128.0), "rotation": Vector3(0.0, -13.0, 0.0), "color": Color(0.86, 0.38, 0.32, 0.68)},
		{"position": Vector3(-68.0, 80.0, -214.0), "size": Vector2(222.0, 120.0), "rotation": Vector3(0.0, 24.0, 0.0), "color": Color(0.92, 0.38, 0.32, 0.70)},
		{"position": Vector3(232.0, 92.0, -110.0), "size": Vector2(260.0, 134.0), "rotation": Vector3(0.0, 39.0, 0.0), "color": Color(0.78, 0.34, 0.30, 0.66)},
		{"position": Vector3(-398.0, 94.0, 72.0), "size": Vector2(206.0, 112.0), "rotation": Vector3(0.0, -32.0, 0.0), "color": Color(0.80, 0.36, 0.31, 0.64)},
		{"position": Vector3(92.0, 84.0, 158.0), "size": Vector2(198.0, 106.0), "rotation": Vector3(0.0, -7.0, 0.0), "color": Color(0.98, 0.40, 0.34, 0.66)}
	]
	return _layout_from_table(layouts, index, Vector3(74.0, 4.0, 96.0))


func _accent_layout(index: int) -> Dictionary:
	var layouts := [
		{"position": Vector3(-212.0, 74.0, -18.0), "size": Vector2(142.0, 78.0), "rotation": Vector3(0.0, 17.0, 0.0), "color": Color(1.00, 0.38, 0.32, 0.76)},
		{"position": Vector3(24.0, 70.0, -166.0), "size": Vector2(124.0, 74.0), "rotation": Vector3(0.0, -24.0, 0.0), "color": Color(0.98, 0.35, 0.31, 0.74)},
		{"position": Vector3(304.0, 82.0, 64.0), "size": Vector2(156.0, 84.0), "rotation": Vector3(0.0, 35.0, 0.0), "color": Color(0.94, 0.32, 0.29, 0.70)},
		{"position": Vector3(-362.0, 84.0, 214.0), "size": Vector2(132.0, 76.0), "rotation": Vector3(0.0, -41.0, 0.0), "color": Color(1.00, 0.37, 0.32, 0.72)}
	]
	return _layout_from_table(layouts, index, Vector3(-86.0, 3.0, 88.0))


func _layout_from_table(layouts: Array, index: int, repeat_offset: Vector3) -> Dictionary:
	var layout: Dictionary = layouts[index % layouts.size()].duplicate(true)
	var repeat := int(floor(float(index) / float(layouts.size())))
	if repeat > 0:
		layout["position"] = layout["position"] + repeat_offset * repeat
		layout["size"] = layout["size"] * maxf(0.72, 1.0 - float(repeat) * 0.08)
	return layout


func _cloud_velocity(layer_name: String, global_index: int) -> Vector3:
	var wind := _shared_wind_direction()
	var crosswind := _crosswind_direction()
	var side := -1.0
	if global_index % 2 == 0:
		side = 1.0
	var layer_scale := _layer_turbulence_multiplier(layer_name)
	var lateral_speed := 0.11 + fposmod(float(global_index * 23), 14.0) / 100.0
	var headwind_variation := -0.06 + fposmod(float(global_index * 11), 13.0) / 100.0
	return (crosswind * side * lateral_speed + wind * headwind_variation) * layer_scale


func _layer_speed(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return far_layer_speed
	if layer_name == ACCENT_CLOUDS:
		return accent_layer_speed
	return mid_layer_speed


func _layer_turbulence_multiplier(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return 0.70
	if layer_name == ACCENT_CLOUDS:
		return 1.25
	return 1.0


func _shared_wind_direction() -> Vector3:
	var direction := wind_direction
	if direction.length_squared() < 0.0001:
		direction = Vector2(1.0, -0.25)
	direction = direction.normalized()
	return Vector3(direction.x, 0.0, direction.y).normalized()


func _shared_wind_direction_uv() -> Vector2:
	var direction := wind_direction
	if direction.length_squared() < 0.0001:
		direction = Vector2(1.0, -0.25)
	return direction.normalized()


func _crosswind_direction() -> Vector3:
	var wind := _shared_wind_direction()
	return Vector3(-wind.z, 0.0, wind.x).normalized()


func _turbulence_axis(index: int) -> Vector3:
	var wind := _shared_wind_direction()
	var crosswind := _crosswind_direction()
	var side := 1.0
	if index % 2 == 0:
		side = -1.0
	return (crosswind * side * 0.82 + wind * 0.18).normalized()


func _layer_rotation_amount(layer_name: String, global_index: int) -> float:
	var base := 1.05
	if layer_name == FAR_CLOUDS:
		base = 0.48
	elif layer_name == ACCENT_CLOUDS:
		base = 1.65
	return base + fposmod(float(global_index * 5), 7.0) / 20.0


func _layer_scale_amount(layer_name: String, global_index: int) -> float:
	var base := 0.020
	if layer_name == FAR_CLOUDS:
		base = 0.012
	elif layer_name == ACCENT_CLOUDS:
		base = 0.028
	return base + fposmod(float(global_index * 3), 6.0) / 1000.0


func _layer_flow_amount(layer_name: String, global_index: int) -> float:
	var base := 8.6
	if layer_name == FAR_CLOUDS:
		base = 4.8
	elif layer_name == ACCENT_CLOUDS:
		base = 11.5
	return base + fposmod(float(global_index * 29), 19.0) / 10.0


func _layer_vertical_amount(layer_name: String, global_index: int) -> float:
	var base := 1.25
	if layer_name == FAR_CLOUDS:
		base = 0.62
	elif layer_name == ACCENT_CLOUDS:
		base = 1.65
	return base + fposmod(float(global_index * 17), 9.0) / 20.0


func _layer_stream_a_amount(layer_name: String, global_index: int) -> float:
	var base := 0.42
	if layer_name == FAR_CLOUDS:
		base = 0.22
	elif layer_name == ACCENT_CLOUDS:
		base = 0.66
	return base + fposmod(float(global_index * 31), 12.0) / 100.0


func _layer_stream_b_amount(layer_name: String, global_index: int) -> float:
	var base := 0.34
	if layer_name == FAR_CLOUDS:
		base = 0.16
	elif layer_name == ACCENT_CLOUDS:
		base = 0.54
	return base + fposmod(float(global_index * 17), 10.0) / 100.0


func _layer_shader_flow_speed(layer_name: String, global_index: int) -> float:
	var base := 0.030
	if layer_name == FAR_CLOUDS:
		base = 0.016
	elif layer_name == ACCENT_CLOUDS:
		base = 0.042
	return base + fposmod(float(global_index * 7), 8.0) / 1000.0


func _layer_shader_distortion(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return 0.0065
	if layer_name == ACCENT_CLOUDS:
		return 0.015
	return 0.0105


func _layer_opacity_boost(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return 1.05
	if layer_name == ACCENT_CLOUDS:
		return 1.22
	return 1.14


func _layer_color_boost(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return 1.05
	if layer_name == ACCENT_CLOUDS:
		return 1.18
	return 1.12


func _layer_render_priority(layer_name: String) -> int:
	if layer_name == FAR_CLOUDS:
		return -2
	if layer_name == ACCENT_CLOUDS:
		return 0
	return -1


func _wrap_position(position: Vector3) -> Vector3:
	var wrapped := position
	if wrapped.x > FIELD_HALF_EXTENTS.x:
		wrapped.x = -FIELD_HALF_EXTENTS.x
	elif wrapped.x < -FIELD_HALF_EXTENTS.x:
		wrapped.x = FIELD_HALF_EXTENTS.x

	if wrapped.z > FIELD_HALF_EXTENTS.y:
		wrapped.z = -FIELD_HALF_EXTENTS.y
	elif wrapped.z < -FIELD_HALF_EXTENTS.y:
		wrapped.z = FIELD_HALF_EXTENTS.y

	return wrapped
