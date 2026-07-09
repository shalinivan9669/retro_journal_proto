extends MeshInstance3D
class_name MountainArcLayer


@export_category("Arc Shape")
@export var radius: float = 350.0
@export var arc_degrees: float = 95.0
@export var height: float = 360.0
@export var bottom_y: float = -20.0
@export var center_yaw_degrees: float = 90.0
@export var segments: int = 96

@export_category("Motion")
@export var parallax_strength: float = 0.0015
@export var uv_scroll_speed: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var layer_opacity: float = 1.0

@export_category("Debug")
@export var regenerate_mesh_on_ready: bool = true

var _start_camera_xz := Vector2.ZERO
var _last_mesh_signature := ""


func _ready() -> void:
	if regenerate_mesh_on_ready:
		rebuild_arc_mesh()


func capture_start_camera(camera_pos: Vector3) -> void:
	_start_camera_xz = Vector2(camera_pos.x, camera_pos.z)


func set_center_yaw_degrees(value: float) -> void:
	if is_equal_approx(center_yaw_degrees, value):
		return
	center_yaw_degrees = value
	rebuild_arc_mesh()


func apply_segment_count(value: int) -> void:
	var next_segments := maxi(3, value)
	if segments == next_segments:
		return
	segments = next_segments
	rebuild_arc_mesh()


func rebuild_arc_mesh() -> void:
	var signature := "%0.3f:%0.3f:%0.3f:%0.3f:%0.3f:%d" % [
		radius,
		arc_degrees,
		height,
		bottom_y,
		center_yaw_degrees,
		segments,
	]
	if signature == _last_mesh_signature and mesh != null:
		return

	mesh = MountainArcMeshBuilder.create_arc_strip(
		radius,
		arc_degrees,
		height,
		bottom_y,
		center_yaw_degrees,
		segments
	)
	_last_mesh_signature = signature


func update_layer(camera_pos: Vector3, day_night: float, haze_strength: float, elapsed_time: float) -> void:
	var mat := _shader_material()
	if mat == null:
		return

	var cam_xz := Vector2(camera_pos.x, camera_pos.z)
	var delta := cam_xz - _start_camera_xz
	var parallax_uv := delta * parallax_strength * 0.001
	parallax_uv += uv_scroll_speed * elapsed_time

	_set_shader_parameter_if_present(mat, "day_night", day_night)
	_set_shader_parameter_if_present(mat, "haze_strength", haze_strength)
	_set_shader_parameter_if_present(mat, "parallax_uv", parallax_uv)
	_set_shader_parameter_if_present(mat, "layer_opacity", layer_opacity)
	_set_shader_parameter_if_present(mat, "elapsed_time", elapsed_time)


func _shader_material() -> ShaderMaterial:
	var active := get_active_material(0) as ShaderMaterial
	if active != null:
		return active
	return material_override as ShaderMaterial


func _set_shader_parameter_if_present(mat: ShaderMaterial, parameter_name: StringName, value: Variant) -> void:
	if mat.shader == null:
		return
	for uniform in mat.shader.get_shader_uniform_list():
		if uniform.has("name") and uniform["name"] == parameter_name:
			mat.set_shader_parameter(parameter_name, value)
			return
