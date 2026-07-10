@tool
extends Node3D

const MAT_BASE_FELT: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_outer_worn_kazakh_rug.tres")
const MAT_MAIN_ORNAMENT: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_main_worn_kazakh_rug.tres")
const MAT_BORDER_DARK: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_ornamental_border_dark.tres")

const GENERATED_NAMES := [
	"Floor_Base_Felt",
	"Main_Rug_Ornamental",
	"Main_Rug_Border_Outer",
	"Main_Rug_Border_Inner",
	"Center_Medallion_RedFelt",
	"Perimeter_Mats",
	"Small_Fabric_Accents",
]

@export_range(4.0, 12.0, 0.05) var floor_radius: float = 9.35:
	set(value):
		floor_radius = value
		_queue_rebuild()

@export var random_seed: int = 1947:
	set(value):
		random_seed = value
		_queue_rebuild()

@export_range(0.0, 0.18, 0.005) var edge_irregularity: float = 0.025:
	set(value):
		edge_irregularity = value
		_queue_rebuild()

@export_range(0.0, 0.08, 0.002) var wave_strength: float = 0.008:
	set(value):
		wave_strength = value
		_queue_rebuild()

@export var generate_in_editor: bool = true:
	set(value):
		generate_in_editor = value
		_queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree():
		return
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild_deferred")


func _rebuild_deferred() -> void:
	_rebuild_queued = false
	rebuild()


func rebuild() -> void:
	if Engine.is_editor_hint() and not generate_in_editor:
		_clear_generated()
		return

	_clear_generated()

	var rug_rotation := deg_to_rad(-4.5)
	var main_radius_x: float = floor_radius * 0.49
	var main_radius_z: float = floor_radius * 0.41

	_add_mesh_node(
		"Floor_Base_Felt",
		self,
		_make_disk_mesh(floor_radius, floor_radius * 0.985, 48, 4, edge_irregularity * 1.15, wave_strength, 0.38, 0.07, 10),
		MAT_BASE_FELT,
		Vector3.ZERO,
		deg_to_rad(1.5)
	)

	_add_mesh_node(
		"Main_Rug_Ornamental",
		self,
		_make_disk_mesh(main_radius_x, main_radius_z, 48, 4, edge_irregularity * 0.65, wave_strength * 0.75, 0.46, -0.18, 20),
		MAT_MAIN_ORNAMENT,
		Vector3(0.16, 0.004, -0.1),
		rug_rotation
	)

	_add_mesh_node(
		"Main_Rug_Border_Outer",
		self,
		_make_ring_mesh(main_radius_x * 0.88, main_radius_z * 0.88, main_radius_x * 1.03, main_radius_z * 1.03, 48, 2, edge_irregularity * 0.5, wave_strength * 0.45, 0.74, 0.11, 30),
		_variant_material(MAT_BORDER_DARK, Color(0.82, 0.74, 0.66, 1), 0.0),
		Vector3(0.16, 0.006, -0.1),
		rug_rotation
	)

func _clear_generated() -> void:
	for child: Node in get_children():
		if child.has_meta("generated_yurt_floor") or String(child.name) in GENERATED_NAMES:
			remove_child(child)
			child.queue_free()


func _add_mesh_node(node_name: String, parent: Node, mesh: ArrayMesh, material: Material, position: Vector3, rotation_y: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark_generated(mesh_instance)
	parent.add_child(mesh_instance)
	return mesh_instance


func _mark_generated(node: Node) -> void:
	node.set_meta("generated_yurt_floor", true)


func _variant_material(base_material: Material, tint: Color, roughness_delta: float) -> Material:
	var result := base_material.duplicate()
	if result is StandardMaterial3D:
		var standard := result as StandardMaterial3D
		standard.albedo_color = tint
		standard.roughness = clampf(standard.roughness + roughness_delta, 0.72, 0.98)
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


func _make_disk_mesh(radius_x: float, radius_z: float, segments: int, rings: int, irregularity: float, wave: float, uv_scale: float, uv_rotation: float, salt: int) -> ArrayMesh:
	var rng := _rng_for(salt)
	var edge_noise := PackedFloat32Array()
	for _i: int in range(segments):
		edge_noise.append(rng.randf_range(-1.0, 1.0))

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	vertices.append(Vector3.ZERO)
	uvs.append(_uv_for(Vector3.ZERO, uv_scale, uv_rotation))

	for ring: int in range(1, rings + 1):
		var t: float = float(ring) / float(rings)
		for segment: int in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var edge_factor: float = 1.0 + edge_noise[segment] * irregularity * pow(t, 2.2)
			var x: float = cos(angle) * radius_x * t * edge_factor
			var z: float = sin(angle) * radius_z * t * edge_factor
			var y: float = _surface_wave(x, z, wave, salt) * smoothstep(0.0, 1.0, t)
			var vertex := Vector3(x, y, z)
			vertices.append(vertex)
			uvs.append(_uv_for(vertex, uv_scale, uv_rotation))

	for segment: int in range(segments):
		indices.append(0)
		indices.append(_disk_index(1, (segment + 1) % segments, segments))
		indices.append(_disk_index(1, segment, segments))

	for ring: int in range(1, rings):
		for segment: int in range(segments):
			var next_segment := (segment + 1) % segments
			var inner_current := _disk_index(ring, segment, segments)
			var inner_next := _disk_index(ring, next_segment, segments)
			var outer_current := _disk_index(ring + 1, segment, segments)
			var outer_next := _disk_index(ring + 1, next_segment, segments)
			indices.append(inner_current)
			indices.append(inner_next)
			indices.append(outer_next)
			indices.append(inner_current)
			indices.append(outer_next)
			indices.append(outer_current)

	return _make_array_mesh(vertices, uvs, indices)


func _make_ring_mesh(inner_radius_x: float, inner_radius_z: float, outer_radius_x: float, outer_radius_z: float, segments: int, bands: int, irregularity: float, wave: float, uv_scale: float, uv_rotation: float, salt: int) -> ArrayMesh:
	var rng := _rng_for(salt)
	var inner_noise := PackedFloat32Array()
	var outer_noise := PackedFloat32Array()
	for _i: int in range(segments):
		inner_noise.append(rng.randf_range(-1.0, 1.0))
		outer_noise.append(rng.randf_range(-1.0, 1.0))

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for band: int in range(bands + 1):
		var t: float = float(band) / float(bands)
		for segment: int in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var noise: float = lerpf(inner_noise[segment], outer_noise[segment], t) * irregularity
			var radius_x: float = lerpf(inner_radius_x, outer_radius_x, t) * (1.0 + noise)
			var radius_z: float = lerpf(inner_radius_z, outer_radius_z, t) * (1.0 + noise)
			var x: float = cos(angle) * radius_x
			var z: float = sin(angle) * radius_z
			var vertex := Vector3(x, _surface_wave(x, z, wave, salt), z)
			vertices.append(vertex)
			uvs.append(_uv_for(vertex, uv_scale, uv_rotation))

	for band: int in range(bands):
		for segment: int in range(segments):
			var next_segment := (segment + 1) % segments
			var inner_current := _ring_index(band, segment, segments)
			var inner_next := _ring_index(band, next_segment, segments)
			var outer_current := _ring_index(band + 1, segment, segments)
			var outer_next := _ring_index(band + 1, next_segment, segments)
			indices.append(inner_current)
			indices.append(inner_next)
			indices.append(outer_next)
			indices.append(inner_current)
			indices.append(outer_next)
			indices.append(outer_current)

	return _make_array_mesh(vertices, uvs, indices)


func _make_array_mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _build_normals(vertices, indices)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normal_list: Array[Vector3] = []
	normal_list.resize(vertices.size())
	for index: int in range(normal_list.size()):
		normal_list[index] = Vector3.ZERO

	for index: int in range(0, indices.size(), 3):
		var ia: int = indices[index]
		var ib: int = indices[index + 1]
		var ic: int = indices[index + 2]
		var a := vertices[ia]
		var b := vertices[ib]
		var c := vertices[ic]
		var normal := (b - a).cross(c - a).normalized()
		normal_list[ia] += normal
		normal_list[ib] += normal
		normal_list[ic] += normal

	var normals := PackedVector3Array()
	for normal: Vector3 in normal_list:
		normals.append(normal.normalized() if normal.length_squared() > 0.0 else Vector3.UP)
	return normals


func _surface_wave(x: float, z: float, amount: float, salt: int) -> float:
	var phase := float(salt) * 0.173
	return (sin(x * 2.2 + phase) * 0.55 + cos(z * 2.9 - phase) * 0.45 + sin((x + z) * 1.1 + phase * 0.7) * 0.35) * amount


func _uv_for(vertex: Vector3, scale: float, rotation: float) -> Vector2:
	var c := cos(rotation)
	var s := sin(rotation)
	var u := vertex.x * c - vertex.z * s
	var v := vertex.x * s + vertex.z * c
	return Vector2(u * scale, v * scale)


func _disk_index(ring: int, segment: int, segments: int) -> int:
	return 1 + (ring - 1) * segments + segment


func _ring_index(band: int, segment: int, segments: int) -> int:
	return band * segments + segment


func _rng_for(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(maxi(1, random_seed + salt * 1009))
	return rng
