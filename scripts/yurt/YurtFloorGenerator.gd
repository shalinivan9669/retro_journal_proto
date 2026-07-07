@tool
extends Node3D

const MAT_BASE_FELT: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_base_felt.tres")
const MAT_MAIN_ORNAMENT: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_main_ornamental_red_cream.tres")
const MAT_BORDER_DARK: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_ornamental_border_dark.tres")
const MAT_CENTER_RED: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_center_red_felt.tres")
const MAT_CHECKERED: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_checkered_muted.tres")
const MAT_FABRIC_BURGUNDY: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_fabric_burgundy.tres")
const MAT_FABRIC_WARM_BEIGE: StandardMaterial3D = preload("res://materials/yurt_floor/mat_yurt_fabric_warm_beige.tres")

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

@export_range(6, 14, 1) var mat_count: int = 11:
	set(value):
		mat_count = value
		_queue_rebuild()

@export var random_seed: int = 1947:
	set(value):
		random_seed = value
		_queue_rebuild()

@export_range(0.0, 0.18, 0.005) var edge_irregularity: float = 0.055:
	set(value):
		edge_irregularity = value
		_queue_rebuild()

@export_range(0.0, 0.08, 0.002) var wave_strength: float = 0.018:
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
		_make_disk_mesh(floor_radius, floor_radius * 0.985, 72, 8, edge_irregularity * 1.15, wave_strength, 0.38, 0.07, 10),
		_variant_material(MAT_BASE_FELT, Color(0.95, 0.9, 0.82, 1), 0.0),
		Vector3.ZERO,
		deg_to_rad(1.5)
	)

	_add_mesh_node(
		"Main_Rug_Ornamental",
		self,
		_make_disk_mesh(main_radius_x, main_radius_z, 56, 5, edge_irregularity * 0.65, wave_strength * 0.75, 0.46, -0.18, 20),
		MAT_MAIN_ORNAMENT,
		Vector3(0.16, 0.004, -0.1),
		rug_rotation
	)

	_add_mesh_node(
		"Main_Rug_Border_Outer",
		self,
		_make_ring_mesh(main_radius_x * 0.88, main_radius_z * 0.88, main_radius_x * 1.03, main_radius_z * 1.03, 64, 2, edge_irregularity * 0.5, wave_strength * 0.45, 0.74, 0.11, 30),
		_variant_material(MAT_BORDER_DARK, Color(0.82, 0.74, 0.66, 1), 0.0),
		Vector3(0.16, 0.006, -0.1),
		rug_rotation
	)

	_add_mesh_node(
		"Main_Rug_Border_Inner",
		self,
		_make_ring_mesh(main_radius_x * 0.57, main_radius_z * 0.57, main_radius_x * 0.68, main_radius_z * 0.68, 64, 2, edge_irregularity * 0.4, wave_strength * 0.4, 0.68, -0.05, 40),
		_variant_material(MAT_MAIN_ORNAMENT, Color(1.05, 0.96, 0.84, 1), 0.03),
		Vector3(0.16, 0.007, -0.1),
		rug_rotation
	)

	_add_mesh_node(
		"Center_Medallion_RedFelt",
		self,
		_make_disk_mesh(main_radius_x * 0.36, main_radius_z * 0.36, 32, 4, edge_irregularity * 0.8, wave_strength * 0.7, 0.82, 0.22, 50),
		_variant_material(MAT_CENTER_RED, Color(0.95, 0.63, 0.58, 1), 0.02),
		Vector3(0.04, 0.009, -0.03),
		rug_rotation + deg_to_rad(7.0)
	)

	var perimeter := Node3D.new()
	perimeter.name = "Perimeter_Mats"
	_mark_generated(perimeter)
	add_child(perimeter)
	_build_perimeter_mats(perimeter)

	var accents := Node3D.new()
	accents.name = "Small_Fabric_Accents"
	_mark_generated(accents)
	add_child(accents)
	_build_small_accents(accents)


func _clear_generated() -> void:
	for child: Node in get_children():
		if child.has_meta("generated_yurt_floor") or String(child.name) in GENERATED_NAMES:
			remove_child(child)
			child.queue_free()


func _build_perimeter_mats(parent: Node3D) -> void:
	var specs := [
		{"angle": -154.0, "radius": 6.55, "width": 2.25, "depth": 1.02, "rot": -10.0, "mat": MAT_FABRIC_WARM_BEIGE, "tint": Color(0.98, 0.9, 0.74, 1), "h": 0.012, "uv": 0.92},
		{"angle": -119.0, "radius": 5.95, "width": 1.85, "depth": 1.08, "rot": 12.0, "mat": MAT_CHECKERED, "tint": Color(0.84, 0.76, 0.68, 1), "h": 0.014, "uv": 1.15},
		{"angle": -82.0, "radius": 6.75, "width": 1.55, "depth": 0.92, "rot": -4.0, "mat": MAT_FABRIC_BURGUNDY, "tint": Color(0.86, 0.62, 0.58, 1), "h": 0.013, "uv": 1.0},
		{"angle": -38.0, "radius": 6.15, "width": 2.1, "depth": 1.06, "rot": 7.0, "mat": MAT_FABRIC_WARM_BEIGE, "tint": Color(0.93, 0.85, 0.69, 1), "h": 0.016, "uv": 0.88},
		{"angle": 4.0, "radius": 5.08, "width": 1.75, "depth": 0.92, "rot": -13.0, "mat": MAT_CHECKERED, "tint": Color(0.9, 0.78, 0.69, 1), "h": 0.018, "uv": 1.25},
		{"angle": 39.0, "radius": 6.45, "width": 2.2, "depth": 1.14, "rot": 5.0, "mat": MAT_BASE_FELT, "tint": Color(0.85, 0.79, 0.68, 1), "h": 0.011, "uv": 0.78},
		{"angle": 82.0, "radius": 6.2, "width": 1.72, "depth": 1.0, "rot": -8.0, "mat": MAT_FABRIC_BURGUNDY, "tint": Color(0.78, 0.52, 0.5, 1), "h": 0.015, "uv": 1.05},
		{"angle": 123.0, "radius": 5.75, "width": 2.05, "depth": 1.08, "rot": 14.0, "mat": MAT_CHECKERED, "tint": Color(0.78, 0.72, 0.64, 1), "h": 0.017, "uv": 1.08},
		{"angle": 159.0, "radius": 6.7, "width": 1.92, "depth": 0.95, "rot": -6.0, "mat": MAT_FABRIC_WARM_BEIGE, "tint": Color(0.9, 0.82, 0.68, 1), "h": 0.012, "uv": 0.95},
		{"angle": 206.0, "radius": 5.35, "width": 1.8, "depth": 0.88, "rot": 9.0, "mat": MAT_FABRIC_BURGUNDY, "tint": Color(0.88, 0.57, 0.54, 1), "h": 0.016, "uv": 1.12},
		{"angle": 248.0, "radius": 6.28, "width": 2.28, "depth": 1.1, "rot": -12.0, "mat": MAT_BASE_FELT, "tint": Color(0.8, 0.75, 0.66, 1), "h": 0.013, "uv": 0.82},
	]

	var count: int = mini(mat_count, specs.size())
	for index: int in range(count):
		var spec: Dictionary = specs[index]
		var angle := deg_to_rad(float(spec["angle"]))
		var pos := Vector3(cos(angle) * float(spec["radius"]), float(spec["h"]), sin(angle) * float(spec["radius"]))
		var tangent_rotation := -angle + PI * 0.5 + deg_to_rad(float(spec["rot"]))
		var material := _variant_material(spec["mat"] as Material, spec["tint"] as Color, 0.02 * float(index % 3))
		var mesh := _make_rect_mesh(float(spec["width"]), float(spec["depth"]), 5, 4, edge_irregularity * 1.6, wave_strength * 0.65, float(spec["uv"]), deg_to_rad(float(spec["rot"]) * 0.4), 100 + index)
		_add_mesh_node("Seat_Mat_%02d" % (index + 1), parent, mesh, material, pos, tangent_rotation)


func _build_small_accents(parent: Node3D) -> void:
	_add_folded_cloth(parent, "Folded_Cloth_01", Vector3(-2.85, 0.022, 3.05), deg_to_rad(-21.0), MAT_FABRIC_BURGUNDY, Color(0.82, 0.53, 0.5, 1), 201)
	_add_folded_cloth(parent, "Folded_Cloth_02", Vector3(3.1, 0.024, -2.95), deg_to_rad(18.0), MAT_FABRIC_WARM_BEIGE, Color(0.95, 0.86, 0.7, 1), 211)

	_add_mesh_node(
		"Accent_Rug_01",
		parent,
		_make_rect_mesh(2.05, 0.58, 6, 3, edge_irregularity * 1.4, wave_strength * 0.5, 1.25, 0.15, 220),
		_variant_material(MAT_CHECKERED, Color(0.74, 0.67, 0.6, 1), 0.04),
		Vector3(-1.05, 0.023, -4.4),
		deg_to_rad(8.0)
	)

	_add_mesh_node(
		"Accent_Rug_02",
		parent,
		_make_rect_mesh(1.35, 0.72, 4, 3, edge_irregularity * 1.8, wave_strength * 0.5, 1.0, -0.2, 230),
		_variant_material(MAT_FABRIC_BURGUNDY, Color(0.76, 0.48, 0.46, 1), 0.03),
		Vector3(4.25, 0.021, 1.35),
		deg_to_rad(-32.0)
	)


func _add_folded_cloth(parent: Node3D, node_name: String, pos: Vector3, rotation_y: float, material: Material, tint: Color, salt: int) -> void:
	var group := Node3D.new()
	group.name = node_name
	group.position = pos
	group.rotation.y = rotation_y
	_mark_generated(group)
	parent.add_child(group)

	_add_mesh_node(
		"Lower_Panel",
		group,
		_make_rect_mesh(1.35, 0.66, 5, 3, edge_irregularity * 1.4, wave_strength * 0.55, 1.1, 0.0, salt),
		_variant_material(material, tint, 0.03),
		Vector3.ZERO,
		0.0
	)
	_add_mesh_node(
		"Upper_Fold",
		group,
		_make_rect_mesh(1.08, 0.34, 4, 2, edge_irregularity * 1.25, wave_strength * 0.45, 1.0, 0.1, salt + 1),
		_variant_material(material, tint.lightened(0.06), 0.04),
		Vector3(0.05, 0.008, -0.12),
		deg_to_rad(2.0)
	)


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


func _make_rect_mesh(width: float, depth: float, x_segments: int, z_segments: int, irregularity: float, wave: float, uv_scale: float, uv_rotation: float, salt: int) -> ArrayMesh:
	var rng := _rng_for(salt)
	var left_jitter := PackedFloat32Array()
	var right_jitter := PackedFloat32Array()
	for _z: int in range(z_segments + 1):
		left_jitter.append(rng.randf_range(-irregularity, irregularity) * width)
		right_jitter.append(rng.randf_range(-irregularity, irregularity) * width)

	var top_jitter := PackedFloat32Array()
	var bottom_jitter := PackedFloat32Array()
	for _x: int in range(x_segments + 1):
		top_jitter.append(rng.randf_range(-irregularity, irregularity) * depth)
		bottom_jitter.append(rng.randf_range(-irregularity, irregularity) * depth)

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for z_index: int in range(z_segments + 1):
		var zt: float = float(z_index) / float(z_segments)
		for x_index: int in range(x_segments + 1):
			var xt: float = float(x_index) / float(x_segments)
			var x: float = lerpf(-width * 0.5, width * 0.5, xt)
			var z: float = lerpf(-depth * 0.5, depth * 0.5, zt)

			var edge_x_weight: float = maxf(1.0 - minf(xt, 1.0 - xt) * 6.0, 0.0)
			var edge_z_weight: float = maxf(1.0 - minf(zt, 1.0 - zt) * 6.0, 0.0)
			x += lerpf(left_jitter[z_index], right_jitter[z_index], xt) * edge_x_weight
			z += lerpf(bottom_jitter[x_index], top_jitter[x_index], zt) * edge_z_weight

			var corner_soften: float = maxf(abs(xt - 0.5) * 2.0 + abs(zt - 0.5) * 2.0 - 1.45, 0.0)
			x *= 1.0 - corner_soften * 0.055
			z *= 1.0 - corner_soften * 0.055

			var vertex := Vector3(x, _surface_wave(x, z, wave, salt), z)
			vertices.append(vertex)
			uvs.append(_uv_for(vertex, uv_scale, uv_rotation))

	for z_index: int in range(z_segments):
		for x_index: int in range(x_segments):
			var a := _rect_index(x_index, z_index, x_segments)
			var b := _rect_index(x_index + 1, z_index, x_segments)
			var c := _rect_index(x_index, z_index + 1, x_segments)
			var d := _rect_index(x_index + 1, z_index + 1, x_segments)
			indices.append(a)
			indices.append(c)
			indices.append(d)
			indices.append(a)
			indices.append(d)
			indices.append(b)

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


func _rect_index(x_index: int, z_index: int, x_segments: int) -> int:
	return z_index * (x_segments + 1) + x_index


func _rng_for(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(maxi(1, random_seed + salt * 1009))
	return rng
