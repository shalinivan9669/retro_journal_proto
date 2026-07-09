extends MeshInstance3D
class_name MountainForegroundRidge


@export var center_yaw_degrees: float = 90.0
@export var radius: float = 112.0
@export var arc_degrees: float = 108.0
@export var thickness: float = 28.0
@export var bottom_y: float = -6.0
@export var min_height: float = 8.0
@export var max_height: float = 30.0
@export var segments: int = 24
@export var seed: int = 9173
@export var rebuild_on_ready: bool = true

var _last_signature := ""


func _ready() -> void:
	if rebuild_on_ready:
		rebuild_ridge()


func set_center_yaw_degrees(value: float) -> void:
	if is_equal_approx(center_yaw_degrees, value):
		return
	center_yaw_degrees = value
	rebuild_ridge()


func rebuild_ridge() -> void:
	segments = maxi(4, segments)
	var signature := "%0.3f:%0.3f:%0.3f:%0.3f:%0.3f:%0.3f:%d:%d" % [
		center_yaw_degrees,
		radius,
		arc_degrees,
		thickness,
		bottom_y,
		max_height,
		segments,
		seed,
	]
	if signature == _last_signature and mesh != null:
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	var center := deg_to_rad(center_yaw_degrees)

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := center - half_arc + t * half_arc * 2.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var front_radius := radius - thickness * 0.45
		var rear_radius := radius + thickness * 0.55
		var height := lerpf(min_height, max_height, _height_noise(t))
		var top_front := bottom_y + height
		var top_rear := bottom_y + height * 0.72

		vertices.append(direction * front_radius + Vector3(0.0, bottom_y, 0.0))
		vertices.append(direction * front_radius + Vector3(0.0, top_front, 0.0))
		vertices.append(direction * rear_radius + Vector3(0.0, top_rear, 0.0))
		vertices.append(direction * rear_radius + Vector3(0.0, bottom_y - 1.0, 0.0))

		var normal := -direction
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)

		uvs.append(Vector2(t, 1.0))
		uvs.append(Vector2(t, 0.2))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))

	for i in range(segments):
		var a := i * 4
		var b := (i + 1) * 4

		_add_quad(indices, a, b, a + 1, b + 1)
		_add_quad(indices, a + 1, b + 1, a + 2, b + 2)
		_add_quad(indices, a + 2, b + 2, a + 3, b + 3)
		_add_quad(indices, a + 3, b + 3, a, b)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var ridge_mesh := ArrayMesh.new()
	ridge_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = ridge_mesh
	_last_signature = signature


func _add_quad(indices: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)
	indices.append(c)
	indices.append(b)
	indices.append(d)


func _height_noise(t: float) -> float:
	var wave_a := sin((t * 2.4 + float(seed % 37) * 0.013) * TAU) * 0.5 + 0.5
	var wave_b := sin((t * 6.7 + float(seed % 83) * 0.007) * TAU) * 0.5 + 0.5
	var wave_c := sin((t * 13.0 + float(seed % 101) * 0.011) * TAU) * 0.5 + 0.5
	var peak := exp(-pow((t - 0.58) / 0.18, 2.0))
	return clampf(0.22 + wave_a * 0.26 + wave_b * 0.18 + wave_c * 0.10 + peak * 0.30, 0.0, 1.0)
