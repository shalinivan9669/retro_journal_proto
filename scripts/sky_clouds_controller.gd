extends Node

const CLOUD_TEXTURE_DIR := "res://assets/textures/sky/clouds_runtime_clean"
const FIELD_HALF_EXTENTS := Vector2(430.0, 320.0)
const FOLLOW_PLAYER := true

const FAR_CLOUDS := "FAR_CLOUDS"
const MID_CLOUDS := "MID_CLOUDS"
const ACCENT_CLOUDS := "ACCENT_CLOUDS"

@export_range(0.1, 3.0, 0.1) var speed_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.1) var chaos_multiplier: float = 0.35
@export_range(0.25, 2.0, 0.05) var density_multiplier: float = 1.0
@export var cloud_height_offset: float = 0.0
@export_range(-180.0, 180.0, 1.0) var wind_direction_degrees: float = -22.0
@export var player_path: NodePath = NodePath("../Player")

var _cloud_root: Node3D
var _player: Node3D
var _cloud_records: Array[Dictionary] = []


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
	for record in _cloud_records:
		var cloud := record["node"] as Node3D
		if cloud == null:
			continue

		var velocity: Vector3 = record["velocity"] * speed_multiplier
		var motion_position: Vector3 = record["motion_position"]
		motion_position += velocity * delta
		motion_position = _wrap_position(motion_position)
		record["motion_position"] = motion_position

		var turbulence_axis: Vector3 = record["turbulence_axis"]
		var wind_axis: Vector3 = record["wind_axis"]
		var turbulence_wave: float = sin(time * record["turbulence_speed"] + record["turbulence_phase"])
		var wind_pulse: float = sin(time * record["turbulence_speed"] * 0.43 + record["turbulence_phase"] * 0.37)
		var drift_offset: Vector3 = turbulence_axis * turbulence_wave * record["turbulence_amount"] * chaos_multiplier
		drift_offset += wind_axis * wind_pulse * record["wind_pulse_amount"] * chaos_multiplier
		cloud.position = motion_position + drift_offset
		cloud.position.y = record["base_y"]


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
	cloud.set_surface_override_material(0, _make_cloud_material(texture, layout["color"]))
	layer.add_child(cloud)

	var turbulence_scale := _layer_turbulence_multiplier(layer_name)

	_cloud_records.append({
		"node": cloud,
		"motion_position": cloud.position,
		"velocity": _cloud_velocity(layer_name, global_index),
		"base_y": cloud.position.y,
		"wind_axis": _shared_wind_direction(),
		"turbulence_axis": _turbulence_axis(global_index),
		"turbulence_phase": float(global_index) * 1.37 + float(layer_index) * 0.61,
		"turbulence_speed": (0.018 + fposmod(float(global_index) * 0.0047, 0.022)) * turbulence_scale,
		"turbulence_amount": (1.4 + fposmod(float(global_index * 17), 2.3)) * turbulence_scale,
		"wind_pulse_amount": (0.5 + fposmod(float(global_index * 13), 0.7)) * turbulence_scale
	})


func _make_cloud_mesh(size: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1
	return mesh


func _make_cloud_material(texture: Texture2D, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color(color.r, color.g, color.b, minf(color.a * 1.35, 0.78))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = true
	return material


func _layout_for(layer_name: String, layer_index: int) -> Dictionary:
	if layer_name == FAR_CLOUDS:
		return _far_layout(layer_index)
	if layer_name == ACCENT_CLOUDS:
		return _accent_layout(layer_index)
	return _mid_layout(layer_index)


func _far_layout(index: int) -> Dictionary:
	var layouts := [
		{"position": Vector3(-365.0, 112.0, -250.0), "size": Vector2(320.0, 178.0), "rotation": Vector3(0.0, -24.0, 0.0), "color": Color(0.45, 0.42, 0.40, 0.38)},
		{"position": Vector3(-105.0, 106.0, -308.0), "size": Vector2(284.0, 156.0), "rotation": Vector3(0.0, 11.0, 0.0), "color": Color(0.39, 0.37, 0.36, 0.34)},
		{"position": Vector3(212.0, 118.0, -224.0), "size": Vector2(340.0, 172.0), "rotation": Vector3(0.0, 32.0, 0.0), "color": Color(0.48, 0.41, 0.39, 0.4)},
		{"position": Vector3(385.0, 124.0, -72.0), "size": Vector2(268.0, 142.0), "rotation": Vector3(0.0, -37.0, 0.0), "color": Color(0.36, 0.35, 0.35, 0.32)}
	]
	return _layout_from_table(layouts, index, Vector3(-42.0, 5.0, 118.0))


func _mid_layout(index: int) -> Dictionary:
	var layouts := [
		{"position": Vector3(-315.0, 88.0, -126.0), "size": Vector2(238.0, 128.0), "rotation": Vector3(0.0, -13.0, 0.0), "color": Color(0.58, 0.42, 0.39, 0.52)},
		{"position": Vector3(-68.0, 80.0, -214.0), "size": Vector2(222.0, 120.0), "rotation": Vector3(0.0, 24.0, 0.0), "color": Color(0.64, 0.42, 0.39, 0.56)},
		{"position": Vector3(232.0, 92.0, -110.0), "size": Vector2(260.0, 134.0), "rotation": Vector3(0.0, 39.0, 0.0), "color": Color(0.5, 0.36, 0.35, 0.5)},
		{"position": Vector3(-398.0, 94.0, 72.0), "size": Vector2(206.0, 112.0), "rotation": Vector3(0.0, -32.0, 0.0), "color": Color(0.52, 0.39, 0.38, 0.48)},
		{"position": Vector3(92.0, 84.0, 158.0), "size": Vector2(198.0, 106.0), "rotation": Vector3(0.0, -7.0, 0.0), "color": Color(0.7, 0.45, 0.42, 0.5)}
	]
	return _layout_from_table(layouts, index, Vector3(74.0, 4.0, 96.0))


func _accent_layout(index: int) -> Dictionary:
	var layouts := [
		{"position": Vector3(-212.0, 74.0, -18.0), "size": Vector2(142.0, 78.0), "rotation": Vector3(0.0, 17.0, 0.0), "color": Color(0.9, 0.5, 0.47, 0.58)},
		{"position": Vector3(24.0, 70.0, -166.0), "size": Vector2(124.0, 74.0), "rotation": Vector3(0.0, -24.0, 0.0), "color": Color(0.82, 0.44, 0.42, 0.56)},
		{"position": Vector3(304.0, 82.0, 64.0), "size": Vector2(156.0, 84.0), "rotation": Vector3(0.0, 35.0, 0.0), "color": Color(0.78, 0.38, 0.36, 0.5)},
		{"position": Vector3(-362.0, 84.0, 214.0), "size": Vector2(132.0, 76.0), "rotation": Vector3(0.0, -41.0, 0.0), "color": Color(0.86, 0.48, 0.45, 0.54)}
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
	var variation := 0.94 + fposmod(float(global_index * 19), 13.0) / 100.0
	return _shared_wind_direction() * 0.10 * _layer_speed_multiplier(layer_name) * variation


func _layer_speed_multiplier(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return 0.46
	if layer_name == ACCENT_CLOUDS:
		return 1.18
	return 0.82


func _layer_turbulence_multiplier(layer_name: String) -> float:
	if layer_name == FAR_CLOUDS:
		return 0.55
	if layer_name == ACCENT_CLOUDS:
		return 1.05
	return 0.78


func _shared_wind_direction() -> Vector3:
	var angle := deg_to_rad(wind_direction_degrees)
	return Vector3(cos(angle), 0.0, sin(angle)).normalized()


func _turbulence_axis(index: int) -> Vector3:
	var wind := _shared_wind_direction()
	var crosswind := Vector3(-wind.z, 0.0, wind.x).normalized()
	var side := 1.0
	if index % 2 == 0:
		side = -1.0
	return (crosswind * side * 0.82 + wind * 0.18).normalized()


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
