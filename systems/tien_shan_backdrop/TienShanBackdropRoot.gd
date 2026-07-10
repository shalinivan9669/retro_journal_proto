extends Node3D
class_name TienShanBackdropRoot

## Seven alpha-preserving, curved panorama layers for the playable steppe.
## Each layer contains tile_00 -> tile_01 -> tile_02 as adjacent arc meshes.

const BACKDROP_DIR := "res://assets/backdrops/tien_shan_hires"
const BACKDROP_SHADER := preload("res://systems/tien_shan_backdrop/tien_shan_backdrop.gdshader")
const TILE_HEIGHT_PX := 3960.0

@export var mountain_direction_yaw_degrees := 180.0
@export var follow_camera_xz := true

# Ordered far-to-near. The scale values retain the native 4:3 tile aspect.
const LAYERS := [
	{"id": "00", "name": "StormSky", "radius": 505.0, "scale": 0.150, "arc_degrees": 140.0, "bottom_y": -100.0, "parallax": 0.005, "alpha": 0.78, "saturation": 1.22, "contrast": 1.13, "brightness": 0.82, "priority": -21},
	{"id": "01", "name": "ExtremeFarPeaks", "radius": 475.0, "scale": 0.030, "arc_degrees": 132.0, "bottom_y": -8.0, "parallax": 0.020, "alpha": 0.46, "saturation": 0.98, "contrast": 1.00, "brightness": 0.98, "priority": -15},
	{"id": "02", "name": "FarSnowWall", "radius": 445.0, "scale": 0.038, "arc_degrees": 132.0, "bottom_y": -12.0, "parallax": 0.040, "alpha": 0.70, "saturation": 1.06, "contrast": 1.04, "brightness": 1.08, "priority": -10},
	{"id": "03", "name": "MainHighMassif", "radius": 410.0, "scale": 0.046, "arc_degrees": 132.0, "bottom_y": -16.0, "parallax": 0.070, "alpha": 1.0, "saturation": 1.24, "contrast": 1.11, "brightness": 1.12, "priority": -5},
	{"id": "04", "name": "MidDarkRidges", "radius": 335.0, "scale": 0.026, "arc_degrees": 136.0, "bottom_y": -22.0, "parallax": 0.110, "alpha": 0.88, "saturation": 1.06, "contrast": 1.07, "brightness": 1.00, "priority": 0},
	{"id": "05", "name": "NearDarkFoothills", "radius": 275.0, "scale": 0.018, "arc_degrees": 140.0, "bottom_y": -24.0, "parallax": 0.170, "alpha": 0.84, "saturation": 1.08, "contrast": 1.10, "brightness": 0.96, "priority": 5},
	{"id": "06", "name": "LowFog", "radius": 255.0, "scale": 0.020, "arc_degrees": 142.0, "bottom_y": -20.0, "parallax": 0.130, "alpha": 0.34, "saturation": 0.82, "contrast": 0.92, "brightness": 1.02, "priority": 10},
]

var _camera: Camera3D
var _layer_roots: Array[Node3D] = []


func _ready() -> void:
	_resolve_camera()
	_build_layers()


func _process(_delta: float) -> void:
	if _camera == null:
		_resolve_camera()
	if _camera == null or not follow_camera_xz:
		return
	for layer_root in _layer_roots:
		var parallax := float(layer_root.get_meta("parallax"))
		layer_root.global_position = Vector3(_camera.global_position.x * parallax, 0.0, _camera.global_position.z * parallax)


func _resolve_camera() -> void:
	if get_viewport() != null:
		_camera = get_viewport().get_camera_3d()


func _build_layers() -> void:
	for child in get_children():
		child.queue_free()
	_layer_roots.clear()
	for layer_data in LAYERS:
		_build_layer(layer_data)


func _build_layer(data: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "TienShanLayer_%s_%s" % [data["id"], data["name"]]
	root.set_meta("parallax", data["parallax"])
	add_child(root)
	_layer_roots.append(root)

	var radius := float(data["radius"])
	var tile_scale := float(data["scale"])
	var tile_height := TILE_HEIGHT_PX * tile_scale
	var tile_arc := deg_to_rad(float(data["arc_degrees"]) / 3.0)
	var center_yaw := deg_to_rad(mountain_direction_yaw_degrees)
	# tile_00, tile_01 and tile_02 occupy adjacent angular intervals with
	# identical scale, baseline, tint, filtering and shader configuration.
	for tile_index in range(3):
		var tile := MeshInstance3D.new()
		tile.name = "Tile_%02d" % tile_index
		tile.mesh = _make_arc_tile_mesh(radius, tile_height, center_yaw, tile_arc, tile_index, float(data["bottom_y"]))
		tile.material_override = _make_tile_material(str(data["id"]), tile_index, data)
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tile)


func _make_arc_tile_mesh(radius: float, height: float, center_yaw: float, tile_arc: float, tile_index: int, bottom_y: float) -> ArrayMesh:
	var start_angle := center_yaw + (float(tile_index) - 1.5) * tile_arc
	var end_angle := start_angle + tile_arc
	var segments := 24
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		var position := Vector3(sin(angle) * radius, bottom_y, cos(angle) * radius)
		vertices.append(position)
		vertices.append(position + Vector3.UP * height)
		uvs.append(Vector2(t, 1.0))
		uvs.append(Vector2(t, 0.0))
	for i in range(segments):
		var base := i * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_tile_material(layer_id: String, tile_index: int, data: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BACKDROP_SHADER
	material.render_priority = int(data["priority"])
	material.set_shader_parameter("albedo_texture", load("%s/layer_%s/tile_%02d.png" % [BACKDROP_DIR, layer_id, tile_index]))
	material.set_shader_parameter("color_tint", Color(1.0, 1.0, 1.0, float(data["alpha"])))
	material.set_shader_parameter("saturation", float(data["saturation"]))
	material.set_shader_parameter("contrast", float(data["contrast"]))
	material.set_shader_parameter("brightness", float(data["brightness"]))
	material.set_shader_parameter("fade_left_edge", 1.0 if tile_index == 0 else 0.0)
	material.set_shader_parameter("fade_right_edge", 1.0 if tile_index == 2 else 0.0)
	return material
