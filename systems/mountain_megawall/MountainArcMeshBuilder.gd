extends RefCounted
class_name MountainArcMeshBuilder


static func create_arc_strip(
		radius: float,
		arc_degrees: float,
		height: float,
		bottom_y: float,
		center_yaw_degrees: float,
		segments: int
	) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	segments = maxi(3, segments)
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	var center := deg_to_rad(center_yaw_degrees)

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := center - half_arc + t * half_arc * 2.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var x := direction.x * radius
		var z := direction.z * radius
		var inward_normal := -direction

		vertices.append(Vector3(x, bottom_y, z))
		vertices.append(Vector3(x, bottom_y + height, z))
		normals.append(inward_normal)
		normals.append(inward_normal)
		uvs.append(Vector2(t, 1.0))
		uvs.append(Vector2(t, 0.0))

	for i in range(segments):
		var base := i * 2
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
