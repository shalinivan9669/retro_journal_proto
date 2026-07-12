extends RefCounted
class_name BalkhashBackdropArc

static func build_tile_arc(radius: float, start_angle: float, end_angle: float, bottom_y: float, height: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment in range(segments + 1):
		var t := float(segment) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		var point := Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)
		vertices.append(point + Vector3(0.0, bottom_y, 0.0))
		vertices.append(point + Vector3(0.0, bottom_y + height, 0.0))
		uvs.append(Vector2(t, 1.0))
		uvs.append(Vector2(t, 0.0))
	for segment in range(segments):
		var base := segment * 2
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
