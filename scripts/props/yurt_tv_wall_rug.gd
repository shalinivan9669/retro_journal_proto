@tool
extends Node3D

@export var width := 5.20
@export var height := 3.35
@export_range(2, 32, 1) var horizontal_segments := 15
@export_range(2, 40, 1) var vertical_segments := 10

func _ready() -> void:
	_build_cloth()

func _build_cloth() -> void:
	var cloth := get_node_or_null("RugCloth") as MeshInstance3D
	if cloth == null:
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y_index in range(vertical_segments + 1):
		var v := float(y_index) / float(vertical_segments)
		for x_index in range(horizontal_segments + 1):
			var u := float(x_index) / float(horizontal_segments)
			var edge_falloff := sin(u * PI)
			var bulge := edge_falloff * sin(v * PI) * 0.022
			var lower_irregularity := sin(u * PI * 3.0) * v * v * 0.008
			vertices.append(Vector3((u - 0.5) * width, (0.5 - v) * height + lower_irregularity, bulge))
			normals.append(Vector3(0, 0, 1))
			uvs.append(Vector2(u, v))
	for y_index in range(vertical_segments):
		for x_index in range(horizontal_segments):
			var a := y_index * (horizontal_segments + 1) + x_index
			var b := a + 1
			var c := a + horizontal_segments + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, d, b, a, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cloth.mesh = result
