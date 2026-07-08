extends Node

## Safe stage-1 visual installer for retro_journal_proto.
## Add scenes/visuals/VisualEffectsRuntime.tscn as a child of Main.tscn.
## It does NOT change gameplay. It only creates runtime materials/lights/overlay.

@export var tune_world_environment := true
@export var apply_tv_radio_emission := true
@export var enable_device_glitch_overlay := true
@export var enable_outdoor_sandstorm := false # Keep off by default. Enable manually after checking it outside the yurt.

@export var glitch_distance := 0.5
@export var tv_light_energy := 0.55
@export var radio_light_energy := 0.16
@export var tv_light_range := 3.0
@export var radio_light_range := 1.4

@export_group("Sandstorm")
@export var sandstorm_position := Vector3(0.0, 1.65, -14.0)
@export var sandstorm_size := Vector3(42.0, 4.5, 30.0)
@export var sandstorm_wind_direction := Vector2(1.0, -0.25).normalized()
@export_range(0.0, 3.0, 0.05) var sandstorm_intensity: float = 0.8
@export_range(0, 40, 1) var sandstorm_sheet_count: int = 18
@export_range(0.0, 4.0, 0.05) var sandstorm_speed: float = 1.25
@export_range(0.2, 3.0, 0.05) var sandstorm_sheet_alpha: float = 0.5

const TV_MATERIAL_PATH := "res://materials/devices/mat_tv_screen_glow.tres"
const RADIO_MATERIAL_PATH := "res://materials/devices/mat_radio_display_glow.tres"
const GLITCH_MATERIAL_PATH := "res://materials/postprocess/mat_glitch_double_vision_soft.tres"
const SANDSTORM_MATERIAL_PATH := "res://materials/fog/mat_sandstorm_fog_soft.tres"

const SANDSTORM_SHEET_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 sand_color : source_color = vec4(0.62, 0.43, 0.25, 0.30);
uniform vec2 wind_direction = vec2(1.0, -0.25);
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float density : hint_range(0.0, 3.0) = 1.0;
uniform float streak_scale : hint_range(1.0, 80.0) = 28.0;
uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.23, 289.17))) * 23143.753);
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
	vec2 dir = wind_direction;
	if (length(dir) < 0.001) {
		dir = vec2(1.0, -0.25);
	}
	dir = normalize(dir);

	float t = TIME * speed + phase;
	vec2 p = UV;
	p.x = p.x * streak_scale + t * 1.85;
	p.y = p.y * 3.0 + sin(t * 0.43 + UV.x * 10.0) * 0.07;

	float broad_gust = noise(vec2(p.x * 0.12, p.y * 1.8 + t * 0.08));
	float fine_streaks = noise(vec2(p.x * 1.9, p.y * 22.0 - t * 0.18));
	float dirty_bands = noise(vec2(UV.y * 3.7 + t * 0.16, UV.x * 1.2));
	float veil = smoothstep(0.20, 0.94, broad_gust) * 0.58;
	veil += smoothstep(0.58, 0.98, fine_streaks) * 0.52;
	veil *= mix(0.55, 1.15, dirty_bands);

	float edge_x = smoothstep(0.0, 0.10, UV.x) * (1.0 - smoothstep(0.90, 1.0, UV.x));
	float edge_y = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.92, 1.0, UV.y));
	float edge = edge_x * edge_y;

	ALBEDO = sand_color.rgb * (0.62 + veil * 0.55);
	ALPHA = clamp(sand_color.a * density * veil * edge, 0.0, 0.78);
}
"""

var _glitch_overlay: ColorRect
var _glitch_targets: Array[Node3D] = []
var _device_points: Array[Node3D] = []
var _sandstorm_root: Node3D
var _sandstorm_records: Array[Dictionary] = []
var _sandstorm_sheet_shader: Shader

func _ready() -> void:
	if tune_world_environment:
		_tune_world_environment()

	if apply_tv_radio_emission:
		_apply_device_materials_and_lights()

	if enable_device_glitch_overlay:
		_create_glitch_overlay()

	if enable_outdoor_sandstorm:
		_create_outdoor_sandstorm()

func _process(delta: float) -> void:
	_update_glitch_overlay()
	_update_sandstorm(delta)

func _tune_world_environment() -> void:
	var world_env := _find_node_by_class(get_tree().current_scene, "WorldEnvironment") as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return

	var env := world_env.environment
	_safe_set(env, "glow_enabled", true)
	_safe_set(env, "glow_intensity", 0.22)
	_safe_set(env, "glow_strength", 0.55)
	_safe_set(env, "adjustment_enabled", true)
	_safe_set(env, "adjustment_saturation", 0.82)
	_safe_set(env, "adjustment_contrast", 1.12)
	_safe_set(env, "ambient_light_energy", 0.34)
	_safe_set(env, "fog_enabled", true)
	_safe_set(env, "fog_density", 0.0035)
	_safe_set(env, "fog_light_color", Color(0.42, 0.40, 0.37, 1.0))
	if enable_outdoor_sandstorm:
		_safe_set(env, "fog_density", 0.0042)
		_safe_set(env, "fog_light_color", Color(0.47, 0.42, 0.34, 1.0))

func _apply_device_materials_and_lights() -> void:
	var tv_root := get_tree().current_scene.find_child("InteractableTV", true, false)
	var radio_root := get_tree().current_scene.find_child("RadioOnBox", true, false)

	if tv_root is Node3D:
		_apply_device(tv_root, TV_MATERIAL_PATH, Color(0.17, 0.78, 0.68), tv_light_energy, tv_light_range, "TVColdScreenLight", false)

	if radio_root is Node3D:
		_apply_device(radio_root, RADIO_MATERIAL_PATH, Color(1.0, 0.32, 0.08), radio_light_energy, radio_light_range, "RadioAmberDisplayLight", true)

func _apply_device(root: Node, material_path: String, light_color: Color, energy: float, light_range: float, light_name: String, override_screen_material: bool) -> void:
	if not ResourceLoader.exists(material_path):
		push_warning("Visual material not found: " + material_path)
		return

	var mat := load(material_path) as Material
	var screen_mesh := _find_screen_mesh(root)
	if screen_mesh:
		if override_screen_material:
			screen_mesh.material_override = mat
		if screen_mesh is Node3D:
			_device_points.append(screen_mesh)

	if root is Node3D:
		root.add_to_group("glitch_device")
		_glitch_targets.append(root)

		if root.find_child(light_name, false, false) == null:
			var light := OmniLight3D.new()
			light.name = light_name
			light.light_color = light_color
			light.light_energy = energy
			light.omni_range = light_range
			light.shadow_enabled = false
			root.add_child(light)

			if screen_mesh and screen_mesh is Node3D:
				light.global_position = (screen_mesh as Node3D).global_position
			else:
				light.position = Vector3(0.0, 0.25, 0.0)

func _create_glitch_overlay() -> void:
	if not ResourceLoader.exists(GLITCH_MATERIAL_PATH):
		push_warning("Glitch material not found: " + GLITCH_MATERIAL_PATH)
		return

	var layer := CanvasLayer.new()
	layer.name = "DeviceGlitchOverlayLayer"
	layer.layer = 80
	add_child(layer)

	_glitch_overlay = ColorRect.new()
	_glitch_overlay.name = "DeviceGlitchOverlay"
	_glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_overlay.offset_left = 0
	_glitch_overlay.offset_top = 0
	_glitch_overlay.offset_right = 0
	_glitch_overlay.offset_bottom = 0
	_glitch_overlay.material = load(GLITCH_MATERIAL_PATH)
	_glitch_overlay.visible = false
	layer.add_child(_glitch_overlay)

func _update_glitch_overlay() -> void:
	if _glitch_overlay == null:
		return

	var camera := _find_active_camera(get_tree().current_scene)
	if camera == null:
		_glitch_overlay.visible = false
		return

	var active := false
	for point in _device_points:
		if is_instance_valid(point):
			var d := camera.global_position.distance_to(point.global_position)
			if d <= glitch_distance:
				active = true
				break

	if not active:
		for target in _glitch_targets:
			if is_instance_valid(target):
				var d2 := camera.global_position.distance_to(target.global_position)
				if d2 <= glitch_distance:
					active = true
					break

	_glitch_overlay.visible = active

func _create_outdoor_sandstorm() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var old_root := scene.find_child("OutdoorSandstormRuntime", true, false)
	if old_root != null:
		return

	var old_fog := scene.find_child("OutdoorSandstormFogVolume", true, false)
	if old_fog != null:
		old_fog.queue_free()

	_sandstorm_records.clear()
	_sandstorm_root = Node3D.new()
	_sandstorm_root.name = "OutdoorSandstormRuntime"
	_sandstorm_root.position = sandstorm_position

	if ClassDB.class_exists("FogVolume") and ResourceLoader.exists(SANDSTORM_MATERIAL_PATH):
		var fog := FogVolume.new()
		fog.name = "OutdoorSandstormFogVolume"
		fog.size = sandstorm_size
		fog.material = _make_sandstorm_fog_material()
		_sandstorm_root.add_child(fog)
	elif not ClassDB.class_exists("FogVolume"):
		push_warning("FogVolume class is not available in this renderer/build; using mesh sandstorm sheets only.")
	else:
		push_warning("Sandstorm material not found: " + SANDSTORM_MATERIAL_PATH)

	_build_sandstorm_sheets(_sandstorm_root)
	scene.add_child.call_deferred(_sandstorm_root)


func _build_sandstorm_sheets(parent: Node3D) -> void:
	var count := maxi(0, sandstorm_sheet_count)
	if count == 0:
		return

	var wind := _sandstorm_wind_direction_3d()
	var crosswind := _sandstorm_crosswind_direction()
	var half_width := maxf(sandstorm_size.x, 18.0) * 0.5
	var half_depth := maxf(sandstorm_size.z, 18.0) * 0.5
	var base_height := maxf(sandstorm_size.y, 3.0)

	var sheets := Node3D.new()
	sheets.name = "SandstormMovingDustSheets"
	parent.add_child(sheets)

	for index in range(count):
		var sheet := MeshInstance3D.new()
		sheet.name = "SandstormDustSheet_%02d" % (index + 1)
		var mesh := QuadMesh.new()
		var wide_factor := 0.72 + fposmod(float(index * 17), 31.0) / 100.0
		var tall_factor := 0.72 + fposmod(float(index * 23), 25.0) / 100.0
		mesh.size = Vector2(maxf(12.0, sandstorm_size.x * wide_factor), maxf(2.4, base_height * tall_factor))
		sheet.mesh = mesh
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.rotation.y = _sandstorm_yaw() + deg_to_rad(-8.0 + fposmod(float(index * 13), 16.0))
		sheet.set_surface_override_material(0, _make_sandstorm_sheet_material(index, false))

		var side_t := 0.0
		if count > 1:
			side_t = float(index) / float(count - 1)
		var side: float = lerpf(-half_width, half_width, side_t)
		var forward: float = -half_depth + fposmod(float(index * 29), maxf(1.0, half_depth * 2.0))
		var y: float = -sandstorm_position.y + 0.85 + fposmod(float(index * 11), 90.0) / 100.0
		var local_position: Vector3 = crosswind * side + wind * forward + Vector3(0.0, y, 0.0)
		sheet.position = local_position
		sheets.add_child(sheet)

		_sandstorm_records.append({
			"node": sheet,
			"position": local_position,
			"wind_factor": 0.78 + fposmod(float(index * 19), 48.0) / 100.0,
			"phase": float(index) * 0.91,
			"side_amount": 0.22 + fposmod(float(index * 7), 13.0) / 50.0,
			"side_speed": 0.38 + fposmod(float(index * 5), 19.0) / 100.0,
			"vertical_amount": 0.08 + fposmod(float(index * 3), 11.0) / 100.0,
			"vertical_speed": 0.42 + fposmod(float(index * 11), 17.0) / 100.0
		})

	var low_count := maxi(4, int(round(float(count) * 0.45)))
	for index in range(low_count):
		var streak := MeshInstance3D.new()
		streak.name = "SandstormLowGroundStreak_%02d" % (index + 1)
		var streak_mesh := QuadMesh.new()
		streak_mesh.size = Vector2(maxf(10.0, sandstorm_size.x * 0.42), maxf(0.9, base_height * 0.24))
		streak.mesh = streak_mesh
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.rotation.y = _sandstorm_yaw() + deg_to_rad(-12.0 + fposmod(float(index * 17), 24.0))
		streak.set_surface_override_material(0, _make_sandstorm_sheet_material(index + count, true))

		var side: float = -half_width + fposmod(float(index * 31), maxf(1.0, half_width * 2.0))
		var forward: float = -half_depth + fposmod(float(index * 43 + 9), maxf(1.0, half_depth * 2.0))
		var local_position: Vector3 = crosswind * side + wind * forward + Vector3(0.0, -sandstorm_position.y + 0.42, 0.0)
		streak.position = local_position
		sheets.add_child(streak)

		_sandstorm_records.append({
			"node": streak,
			"position": local_position,
			"wind_factor": 1.18 + fposmod(float(index * 13), 40.0) / 100.0,
			"phase": float(index + count) * 0.77,
			"side_amount": 0.16 + fposmod(float(index * 5), 9.0) / 60.0,
			"side_speed": 0.62 + fposmod(float(index * 7), 16.0) / 100.0,
			"vertical_amount": 0.025,
			"vertical_speed": 0.36
		})


func _update_sandstorm(delta: float) -> void:
	if _sandstorm_root == null or _sandstorm_records.is_empty():
		return

	var time := Time.get_ticks_msec() * 0.001
	var wind := _sandstorm_wind_direction_3d()
	var crosswind := _sandstorm_crosswind_direction()
	for record in _sandstorm_records:
		var sheet := record["node"] as Node3D
		if sheet == null or not is_instance_valid(sheet):
			continue

		var local_position: Vector3 = record["position"]
		local_position += wind * sandstorm_speed * sandstorm_intensity * record["wind_factor"] * delta
		local_position = _wrap_sandstorm_position(local_position)
		record["position"] = local_position

		var side_speed: float = record["side_speed"]
		var phase: float = record["phase"]
		var side_amount: float = record["side_amount"]
		var vertical_speed: float = record["vertical_speed"]
		var vertical_amount: float = record["vertical_amount"]
		var side_sway: Vector3 = crosswind * sin(time * side_speed + phase) * side_amount * sandstorm_intensity
		var vertical_sway := Vector3(0.0, sin(time * vertical_speed + phase * 1.3) * vertical_amount, 0.0)
		sheet.position = local_position + side_sway + vertical_sway


func _wrap_sandstorm_position(position: Vector3) -> Vector3:
	var wind := _sandstorm_wind_direction_3d()
	var crosswind := _sandstorm_crosswind_direction()
	var half_width := maxf(sandstorm_size.x, 18.0) * 0.5
	var half_depth := maxf(sandstorm_size.z, 18.0) * 0.5
	var forward := position.dot(wind)
	var side := position.dot(crosswind)
	var y := position.y

	if forward > half_depth:
		forward = -half_depth
	elif forward < -half_depth:
		forward = half_depth

	if side > half_width:
		side = -half_width
	elif side < -half_width:
		side = half_width

	return wind * forward + crosswind * side + Vector3(0.0, y, 0.0)


func _make_sandstorm_fog_material() -> Material:
	var material := load(SANDSTORM_MATERIAL_PATH) as ShaderMaterial
	if material == null:
		return null

	var instance := material.duplicate() as ShaderMaterial
	instance.set_shader_parameter("fog_color", Vector3(0.62, 0.46, 0.28))
	instance.set_shader_parameter("density_multiplier", clampf(0.24 * sandstorm_intensity, 0.0, 2.0))
	instance.set_shader_parameter("noise_scale", 0.14)
	instance.set_shader_parameter("vertical_fade", maxf(3.2, sandstorm_size.y * 0.92))
	instance.set_shader_parameter("speed", 0.18 * sandstorm_speed)
	instance.set_shader_parameter("contrast", 1.18)
	return instance


func _make_sandstorm_sheet_material(index: int, low_ground: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_sandstorm_sheet_shader()
	material.render_priority = 12

	var alpha := clampf((0.24 + fposmod(float(index * 5), 10.0) / 100.0) * sandstorm_sheet_alpha, 0.04, 0.55)
	var color := Color(0.64, 0.44, 0.25, alpha)
	if low_ground:
		color = Color(0.72, 0.50, 0.28, clampf(alpha * 1.15, 0.05, 0.62))

	material.set_shader_parameter("sand_color", color)
	material.set_shader_parameter("wind_direction", _sandstorm_wind_direction_2d())
	material.set_shader_parameter("speed", sandstorm_speed * (0.85 + fposmod(float(index * 3), 28.0) / 100.0))
	material.set_shader_parameter("density", sandstorm_intensity * (0.78 if low_ground else 1.0))
	material.set_shader_parameter("streak_scale", 32.0 if low_ground else 24.0 + fposmod(float(index * 7), 16.0))
	material.set_shader_parameter("phase", float(index) * 1.137)
	return material


func _get_sandstorm_sheet_shader() -> Shader:
	if _sandstorm_sheet_shader == null:
		_sandstorm_sheet_shader = Shader.new()
		_sandstorm_sheet_shader.code = SANDSTORM_SHEET_SHADER_CODE
	return _sandstorm_sheet_shader


func _sandstorm_wind_direction_2d() -> Vector2:
	var direction := sandstorm_wind_direction
	if direction.length_squared() < 0.0001:
		direction = Vector2(1.0, -0.25)
	return direction.normalized()


func _sandstorm_wind_direction_3d() -> Vector3:
	var direction := _sandstorm_wind_direction_2d()
	return Vector3(direction.x, 0.0, direction.y).normalized()


func _sandstorm_crosswind_direction() -> Vector3:
	var wind := _sandstorm_wind_direction_3d()
	return Vector3(-wind.z, 0.0, wind.x).normalized()


func _sandstorm_yaw() -> float:
	var wind := _sandstorm_wind_direction_3d()
	return atan2(wind.x, wind.z)

func _find_screen_mesh(root: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var stack: Array[Node] = [root]

	while stack.size() > 0:
		var node: Node = stack.pop_back()
		var lower: String = node.name.to_lower()
		if node is MeshInstance3D:
			if lower.contains("screen") or lower.contains("display") or lower.contains("monitor") or lower.contains("crt"):
				return node as MeshInstance3D
			if best == null:
				best = node as MeshInstance3D
		for child in node.get_children():
			stack.append(child)

	return best

func _find_active_camera(root: Node) -> Camera3D:
	if root == null:
		return null

	var fallback: Camera3D = null
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is Camera3D:
			var cam := node as Camera3D
			if cam.current:
				return cam
			if fallback == null:
				fallback = cam
		for child in node.get_children():
			stack.append(child)
	return fallback

func _find_node_by_class(root: Node, target_class_name: String) -> Node:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node.get_class() == target_class_name or node.is_class(target_class_name):
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _safe_set(obj: Object, property_name: String, property_value: Variant) -> void:
	if obj == null:
		return
	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == property_name:
			obj.set(property_name, property_value)
			return
