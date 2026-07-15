@tool
class_name LostSignalBackdropArc
extends MeshInstance3D

@export_range(100.0, 20000.0, 10.0) var radius_m := 1800.0
@export_range(-180.0, 180.0, 1.0) var start_angle_degrees := -120.0
@export_range(-180.0, 180.0, 1.0) var end_angle_degrees := -20.0
@export_range(-2000.0, 500.0, 1.0) var bottom_height_m := -700.0
@export_range(10.0, 4000.0, 1.0) var visual_height_m := 1500.0
@export_range(4, 128, 1) var subdivisions := 64
@export var rebuild_in_editor := false:
	set(value):
		rebuild_in_editor = false
		if value:
			rebuild()


func _ready() -> void:
	if mesh == null:
		rebuild()


func rebuild() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var steps := maxi(subdivisions, 4)

	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var angle := deg_to_rad(lerpf(start_angle_degrees, end_angle_degrees, t))
		var x := sin(angle) * radius_m
		var z := -cos(angle) * radius_m
		var inward := Vector3(-x, 0.0, -z).normalized()
		vertices.append(Vector3(x, bottom_height_m, z))
		vertices.append(Vector3(x, bottom_height_m + visual_height_m, z))
		normals.append(inward)
		normals.append(inward)
		uvs.append(Vector2(t, 1.0))
		uvs.append(Vector2(t, 0.0))

	for index in range(steps):
		var vertex := index * 2
		indices.append_array(PackedInt32Array([
			vertex,
			vertex + 1,
			vertex + 2,
			vertex + 2,
			vertex + 1,
			vertex + 3,
		]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var generated := ArrayMesh.new()
	generated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = generated
