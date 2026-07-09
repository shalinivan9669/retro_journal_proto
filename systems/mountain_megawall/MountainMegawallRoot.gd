extends Node3D
class_name MountainMegawallRoot


enum PerformancePreset { LOW, MEDIUM, HIGH, CINEMATIC }

const PRODUCTION_TEXTURE_DIR := "res://art/backdrops/mountains/megawall/textures/production"
const PLACEHOLDER_TEXTURE_DIR := "res://art/backdrops/mountains/megawall/textures/placeholder"
const REFERENCE_LAYER_YAW_DEGREES := 90.0

@export_group("Camera Follow")
@export var camera_path: NodePath
@export var fixed_y: float = 0.0
@export var follow_camera_xz: bool = true

@export_group("Look")
@export_range(0.0, 1.0, 0.01) var day_night: float = 0.18
@export_range(0.0, 2.0, 0.01) var haze_strength: float = 0.86
@export var mountain_direction_yaw_degrees: float = 90.0:
	set(value):
		mountain_direction_yaw_degrees = value
		if is_inside_tree():
			_apply_mountain_direction()

@export_group("Runtime")
@export var freeze_backdrop_time: bool = false
@export var performance_preset: PerformancePreset = PerformancePreset.HIGH:
	set(value):
		performance_preset = value
		if is_inside_tree():
			_apply_performance_preset()

@export_group("Debug")
@export var debug_print_direction: bool = false
@export var debug_show_layer_radii: bool = false:
	set(value):
		debug_show_layer_radii = value
		if is_inside_tree():
			_update_debug_radii()
@export var debug_show_layers: bool = false
@export var warn_when_using_placeholder_textures: bool = true
@export var debug_force_day_night_enabled: bool = false
@export_range(0.0, 1.0, 0.01) var debug_forced_day_night: float = 0.18
@export var debug_force_haze_enabled: bool = false
@export_range(0.0, 2.0, 0.01) var debug_forced_haze_strength: float = 0.86

@export_group("Layer Visibility")
@export var show_foreground_ridge: bool = true:
	set(value):
		show_foreground_ridge = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_foothills_layer: bool = true:
	set(value):
		show_foothills_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_main_wall_layer: bool = true:
	set(value):
		show_main_wall_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_snow_peak_overlay_layer: bool = true:
	set(value):
		show_snow_peak_overlay_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_rear_peak_layer: bool = true:
	set(value):
		show_rear_peak_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_low_haze_layer: bool = true:
	set(value):
		show_low_haze_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_mid_haze_layer: bool = true:
	set(value):
		show_mid_haze_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_low_cloud_layer: bool = true:
	set(value):
		show_low_cloud_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_cloud_shadow_layer: bool = true:
	set(value):
		show_cloud_shadow_layer = value
		if is_inside_tree():
			_apply_layer_visibility()
@export var show_night_lights_layer: bool = true:
	set(value):
		show_night_lights_layer = value
		if is_inside_tree():
			_apply_layer_visibility()

var _camera: Camera3D
var _time := 0.0
var _layers: Array[MountainArcLayer] = []
var _layer_yaw_offsets: Dictionary = {}
var _base_layer_segments: Dictionary = {}
var _placeholder_warning_printed := false


func _ready() -> void:
	_resolve_camera()
	_collect_layers()
	_apply_mountain_direction()
	_apply_performance_preset()
	_apply_layer_visibility()
	_update_debug_radii()
	_warn_if_using_placeholder_textures()
	if debug_print_direction:
		print_current_mountain_direction()


func _process(delta: float) -> void:
	if _camera == null:
		_resolve_camera()
		if _camera != null:
			for layer in _layers:
				layer.capture_start_camera(_camera.global_position)
		else:
			return

	if not freeze_backdrop_time:
		_time += delta

	if follow_camera_xz:
		global_position.x = _camera.global_position.x
		global_position.z = _camera.global_position.z
		global_position.y = fixed_y

	var active_day_night := _current_day_night()
	var active_haze_strength := _current_haze_strength()
	for layer in _layers:
		if is_instance_valid(layer):
			layer.update_layer(_camera.global_position, active_day_night, active_haze_strength, _time)

	var events := get_node_or_null("MicroEventController")
	if events != null:
		events.set("day_night", active_day_night)


func set_day_night(value: float) -> void:
	day_night = clampf(value, 0.0, 1.0)


func set_haze_strength(value: float) -> void:
	haze_strength = maxf(0.0, value)


func set_performance_preset(value: PerformancePreset) -> void:
	performance_preset = value


func set_mountain_direction_yaw_degrees(value: float) -> void:
	mountain_direction_yaw_degrees = value


func debug_force_event(event_name: String = "industrial_flash") -> void:
	var events := get_node_or_null("MicroEventController")
	if events != null and events.has_method("debug_force_event"):
		events.debug_force_event(event_name)


func print_current_mountain_direction() -> void:
	var direction := get_mountain_direction_vector()
	print("MountainMegawall direction yaw=", mountain_direction_yaw_degrees, " vector=", direction)


func get_mountain_direction_vector() -> Vector3:
	var yaw := deg_to_rad(mountain_direction_yaw_degrees)
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


func _resolve_camera() -> void:
	if camera_path != NodePath():
		_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null and get_viewport() != null:
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		_camera = _find_first_camera(get_tree().current_scene)


func _find_first_camera(node: Node) -> Camera3D:
	if node == null:
		return null
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_first_camera(child)
		if found != null:
			return found
	return null


func _collect_layers() -> void:
	_layers.clear()
	_layer_yaw_offsets.clear()
	_base_layer_segments.clear()

	for child in get_children():
		if child is MountainArcLayer:
			var layer := child as MountainArcLayer
			_layers.append(layer)
			_layer_yaw_offsets[layer.get_path()] = layer.center_yaw_degrees - REFERENCE_LAYER_YAW_DEGREES
			_base_layer_segments[layer.get_path()] = layer.segments
			if _camera != null:
				layer.capture_start_camera(_camera.global_position)

	if debug_show_layers:
		print("MountainMegawallRoot layers: ", _layers.size())


func _apply_mountain_direction() -> void:
	for layer in _layers:
		if not is_instance_valid(layer):
			continue
		var offset := float(_layer_yaw_offsets.get(layer.get_path(), 0.0))
		layer.set_center_yaw_degrees(mountain_direction_yaw_degrees + offset)

	var ridge := get_node_or_null("RealForegroundRidge")
	if ridge != null and ridge.has_method("set_center_yaw_degrees"):
		ridge.set_center_yaw_degrees(mountain_direction_yaw_degrees)

	var events := get_node_or_null("MicroEventController")
	if events != null:
		events.set("center_yaw_degrees", mountain_direction_yaw_degrees)

	_update_debug_radii()


func _apply_performance_preset() -> void:
	var clouds := get_node_or_null("LowCloudLayer")
	var cloud_shadow := get_node_or_null("CloudShadowLayer")
	var night_lights := get_node_or_null("NightLightsLayer")
	var events := get_node_or_null("MicroEventController")

	var segment_scale := 1.0
	match performance_preset:
		PerformancePreset.LOW:
			segment_scale = 0.55
			if clouds: clouds.visible = false
			if cloud_shadow: cloud_shadow.visible = false
			if night_lights: night_lights.visible = false
			if events: events.set("enable_events", false)
		PerformancePreset.MEDIUM:
			segment_scale = 0.75
			if clouds: clouds.visible = true
			if cloud_shadow: cloud_shadow.visible = false
			if night_lights: night_lights.visible = false
			if events: events.set("enable_events", false)
		PerformancePreset.HIGH:
			segment_scale = 1.0
			if clouds: clouds.visible = true
			if cloud_shadow: cloud_shadow.visible = true
			if night_lights: night_lights.visible = true
			if events: events.set("enable_events", true)
		PerformancePreset.CINEMATIC:
			segment_scale = 1.25
			if clouds: clouds.visible = true
			if cloud_shadow: cloud_shadow.visible = true
			if night_lights: night_lights.visible = true
			if events: events.set("enable_events", true)

	for layer in _layers:
		if not is_instance_valid(layer):
			continue
		var base_segments := int(_base_layer_segments.get(layer.get_path(), layer.segments))
		layer.apply_segment_count(maxi(12, int(round(float(base_segments) * segment_scale))))

	_apply_layer_visibility()


func _apply_layer_visibility() -> void:
	_set_child_visibility("RealForegroundRidge", show_foreground_ridge)
	_set_child_visibility("FoothillsLayer", show_foothills_layer)
	_set_child_visibility("MainWallLayer", show_main_wall_layer)
	_set_child_visibility("SnowPeakOverlayLayer", show_snow_peak_overlay_layer)
	_set_child_visibility("RearPeakLayer", show_rear_peak_layer)
	_set_child_visibility("LowHazeLayer", show_low_haze_layer)
	_set_child_visibility("MidHazeLayer", show_mid_haze_layer)
	_set_child_visibility("LowCloudLayer", show_low_cloud_layer and _preset_allows_layer("LowCloudLayer"))
	_set_child_visibility("CloudShadowLayer", show_cloud_shadow_layer and _preset_allows_layer("CloudShadowLayer"))
	_set_child_visibility("NightLightsLayer", show_night_lights_layer and _preset_allows_layer("NightLightsLayer"))


func _set_child_visibility(child_name: String, enabled: bool) -> void:
	var child := get_node_or_null(NodePath(child_name)) as Node3D
	if child != null:
		child.visible = enabled


func _preset_allows_layer(layer_name: String) -> bool:
	match performance_preset:
		PerformancePreset.LOW:
			return not layer_name in ["LowCloudLayer", "CloudShadowLayer", "NightLightsLayer"]
		PerformancePreset.MEDIUM:
			return not layer_name in ["CloudShadowLayer", "NightLightsLayer"]
	return true


func _current_day_night() -> float:
	if debug_force_day_night_enabled:
		return clampf(debug_forced_day_night, 0.0, 1.0)
	return clampf(day_night, 0.0, 1.0)


func _current_haze_strength() -> float:
	if debug_force_haze_enabled:
		return maxf(0.0, debug_forced_haze_strength)
	return maxf(0.0, haze_strength)


func _warn_if_using_placeholder_textures() -> void:
	if _placeholder_warning_printed or not warn_when_using_placeholder_textures:
		return

	var production_exists := ResourceLoader.exists(PRODUCTION_TEXTURE_DIR + "/mountain_wall_day_8k.png")
	var placeholder_exists := ResourceLoader.exists(PLACEHOLDER_TEXTURE_DIR + "/mountain_megawall_day_4k.png")
	if not production_exists and placeholder_exists:
		push_warning("MountainMegawall is using placeholder textures. Replace with production DEM/CC0 render textures.")
		_placeholder_warning_printed = true


func _update_debug_radii() -> void:
	var existing := get_node_or_null("DebugLayerRadii")
	if existing != null:
		existing.queue_free()
	if not debug_show_layer_radii:
		return

	var debug_root := Node3D.new()
	debug_root.name = "DebugLayerRadii"
	add_child(debug_root)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.55, 0.72, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for layer in _layers:
		if not is_instance_valid(layer):
			continue
		var line := MeshInstance3D.new()
		line.name = "DebugRadius_%s" % layer.name
		line.mesh = _make_debug_arc_mesh(layer.radius, layer.arc_degrees, layer.center_yaw_degrees)
		line.material_override = material
		debug_root.add_child(line)


func _make_debug_arc_mesh(radius: float, arc_degrees: float, yaw_degrees: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	var center := deg_to_rad(yaw_degrees)
	var segments := 64
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := center - half_arc + t * half_arc * 2.0
		mesh.surface_add_vertex(Vector3(sin(angle) * radius, 0.15, cos(angle) * radius))
	mesh.surface_end()
	return mesh
