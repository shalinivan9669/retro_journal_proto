extends RefCounted
class_name YurtTextileLibrary

const MAT_VELVET: Material = preload("res://materials/polyhaven/textiles/mat_velour_velvet_hero.tres")
const MAT_TEDDY: Material = preload("res://materials/polyhaven/textiles/mat_curly_teddy_checkered_thick.tres")
const MAT_JACQUARD: Material = preload("res://materials/polyhaven/textiles/mat_quatrefoil_jacquard_tablecloth.tres")
const MAT_WOOL: Material = preload("res://materials/polyhaven/textiles/mat_wool_boucle_heavy.tres")
const MAT_WAFFLE: Material = preload("res://materials/polyhaven/textiles/mat_waffle_pique_cotton_flags.tres")


func add_draped_rect(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector2,
	material: Material,
	rotation_y: float = 0.0,
	thickness: float = 0.035,
	fold: float = 0.055,
	wave: float = 0.035,
	seed: int = 1
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.mesh = make_draped_rect_mesh(size, thickness, fold, wave, seed, false)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func add_irregular_hide(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector2,
	material: Material,
	rotation_y: float,
	seed: int
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.mesh = make_draped_rect_mesh(size, 0.045, 0.085, 0.045, seed, true)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func add_folded_stack(parent: Node3D, node_name: String, position: Vector3, material: Material, rotation_y: float, layer_count: int = 3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.rotation.y = rotation_y
	parent.add_child(root)

	for index in range(layer_count):
		var layer := MeshInstance3D.new()
		layer.name = "Fold_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.05 - float(index) * 0.12, 0.085, 0.42 + float(index) * 0.035)
		layer.mesh = mesh
		layer.position = Vector3(float(index) * 0.05, float(index) * 0.08, sin(float(index) * 1.7) * 0.03)
		layer.rotation_degrees = Vector3(0.0, float(index) * 2.5, 1.5 - float(index))
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.set_surface_override_material(0, material)
		root.add_child(layer)

	var rolled := MeshInstance3D.new()
	rolled.name = "SoftRoll"
	var roll_mesh := CylinderMesh.new()
	roll_mesh.top_radius = 0.16
	roll_mesh.bottom_radius = 0.16
	roll_mesh.height = 0.78
	roll_mesh.radial_segments = 18
	rolled.mesh = roll_mesh
	rolled.position = Vector3(0.16, 0.29, 0.36)
	rolled.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rolled.set_surface_override_material(0, material)
	root.add_child(rolled)
	return root


func add_low_table(parent: Node3D, node_name: String, position: Vector3, rotation_y: float, table_material: Material, cloth_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.rotation.y = rotation_y
	parent.add_child(root)

	var top := MeshInstance3D.new()
	top.name = "WideLowTableTop"
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.85, 0.16, 1.55)
	top.mesh = top_mesh
	top.position = Vector3(0.0, 0.42, 0.0)
	top.set_surface_override_material(0, table_material)
	root.add_child(top)

	for x in [-1.14, 1.14]:
		for z in [-0.54, 0.54]:
			var leg := MeshInstance3D.new()
			leg.name = "LowTableLeg"
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.16, 0.42, 0.16)
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.2, z)
			leg.set_surface_override_material(0, table_material)
			root.add_child(leg)

	add_draped_rect(root, "JacquardTablecloth", Vector3(0.0, 0.535, 0.0), Vector2(2.62, 1.36), cloth_material, 0.0, 0.045, 0.08, 0.026, 44)
	return root


func add_flag(parent: Node3D, node_name: String, position: Vector3, rotation_y: float, material: Material, index: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.mesh = make_flag_mesh(index)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func make_draped_rect_mesh(size: Vector2, thickness: float, fold: float, wave: float, seed: int, irregular: bool) -> Mesh:
	var columns := 8
	var rows := 6
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for layer in range(2):
		var y_base := 0.0 if layer == 0 else -thickness
		for row in range(rows + 1):
			for col in range(columns + 1):
				var u := float(col) / float(columns)
				var v := float(row) / float(rows)
				var x := (u - 0.5) * size.x
				var z := (v - 0.5) * size.y
				var edge: float = maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0
				var ripple := sin((u * 8.0 + float(seed)) * 1.7) * cos((v * 7.0 + float(seed)) * 1.3) * wave
				var edge_lift := smoothstep(0.62, 1.0, edge) * fold
				var irregular_offset := 0.0
				if irregular:
					irregular_offset = sin(float(col * 17 + row * 31 + seed) * 0.73) * 0.045 * smoothstep(0.55, 1.0, edge)
				vertices.append(Vector3(x + irregular_offset, y_base + ripple + edge_lift, z - irregular_offset * 0.7))
				uvs.append(Vector2(u, v))

	var stride := columns + 1
	for row in range(rows):
		for col in range(columns):
			var a := row * stride + col
			var b := a + 1
			var c := (row + 1) * stride + col
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var bottom_offset := (rows + 1) * (columns + 1)
	for row in range(rows):
		for col in range(columns):
			var a := bottom_offset + row * stride + col
			var b := a + 1
			var c := bottom_offset + (row + 1) * stride + col
			var d := c + 1
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(b)
			indices.append(d)
			indices.append(c)

	_add_side_indices(indices, 0, bottom_offset, columns, rows, stride)
	return _commit_mesh(vertices, uvs, indices)


func make_flag_mesh(index: int) -> Mesh:
	var width := 0.72
	var height := 0.78
	var sag := 0.05 + float(index % 3) * 0.018
	var vertices := PackedVector3Array([
		Vector3(-width * 0.5, 0.0, 0.0),
		Vector3(width * 0.5, -sag, 0.0),
		Vector3(0.0, -height, 0.04 * sin(float(index)))
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.5, 1.0)
	])
	var indices := PackedInt32Array([0, 2, 1, 0, 1, 2])
	return _commit_mesh(vertices, uvs, indices)


func _add_side_indices(indices: PackedInt32Array, top_offset: int, bottom_offset: int, columns: int, rows: int, stride: int) -> void:
	for col in range(columns):
		_add_edge_quad(indices, top_offset + col, top_offset + col + 1, bottom_offset + col, bottom_offset + col + 1)
		var top_row := rows * stride
		_add_edge_quad(indices, top_offset + top_row + col + 1, top_offset + top_row + col, bottom_offset + top_row + col + 1, bottom_offset + top_row + col)
	for row in range(rows):
		_add_edge_quad(indices, top_offset + (row + 1) * stride, top_offset + row * stride, bottom_offset + (row + 1) * stride, bottom_offset + row * stride)
		_add_edge_quad(indices, top_offset + row * stride + columns, top_offset + (row + 1) * stride + columns, bottom_offset + row * stride + columns, bottom_offset + (row + 1) * stride + columns)


func _add_edge_quad(indices: PackedInt32Array, top_a: int, top_b: int, bottom_a: int, bottom_b: int) -> void:
	indices.append(top_a)
	indices.append(bottom_a)
	indices.append(top_b)
	indices.append(top_b)
	indices.append(bottom_a)
	indices.append(bottom_b)


func _commit_mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> Mesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(mesh, 0)
	surface_tool.generate_normals()
	surface_tool.generate_tangents()
	return surface_tool.commit()
