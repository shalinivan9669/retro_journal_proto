extends RefCounted
class_name SteppeTerrainBuilder

const ZONE_NO_SPAWN := 0
const ZONE_YURT_FLAT := 1
const ZONE_YURT_EDGE := 2
const ZONE_DRY_STEPPE := 3
const ZONE_LOWLAND_WET := 4
const ZONE_ROCKY_PATCH := 5
const ZONE_PATH_EDGE := 6
const ZONE_DISTANT_TREE_PATCH := 7
const ZONE_SALT_DUST_EDGE := 8

var sampler
var terrain_size: float = 240.0
var terrain_resolution: int = 177
var material: Material
var collision_enabled: bool = false
var debug_show_spawn_zones: bool = false

var vertex_count: int = 0
var triangle_count: int = 0


func build(parent: Node3D) -> Node3D:
	if sampler == null:
		push_warning("SteppeTerrainBuilder needs a TerrainHeightSampler.")
		return null

	var root := Node3D.new()
	root.name = "SteppeTerrainRoot"
	parent.add_child(root)

	var body := StaticBody3D.new()
	body.name = "SteppeTerrainBody"
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SteppeTerrainMesh"
	mesh_instance.mesh = _build_mesh()
	if material != null:
		mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	if collision_enabled:
		var collision := CollisionShape3D.new()
		collision.name = "SteppeTerrainCollision"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(_mesh_faces(mesh_instance.mesh))
		collision.shape = shape
		body.add_child(collision)

	if debug_show_spawn_zones:
		_add_debug_zone_markers(root)

	print("[Landscape] terrain verts=", vertex_count, " tris=", triangle_count)
	return root


func _build_mesh() -> ArrayMesh:
	var resolution := clampi(terrain_resolution, 17, 257)
	if resolution % 2 == 0:
		resolution += 1
	terrain_resolution = resolution

	var half_size := terrain_size * 0.5
	var step := terrain_size / float(resolution - 1)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	vertices.resize(resolution * resolution)
	uvs.resize(resolution * resolution)
	colors.resize(resolution * resolution)

	for z_i in range(resolution):
		for x_i in range(resolution):
			var x := -half_size + float(x_i) * step
			var z := -half_size + float(z_i) * step
			var h: float = sampler.height_at(x, z)
			var normal: Vector3 = sampler.normal_at(x, z)
			var index := z_i * resolution + x_i
			vertices[index] = Vector3(x, h, z)
			uvs[index] = Vector2(x, z) * 0.08
			colors[index] = _vertex_color_for(x, z, h, normal)

	for z_i in range(resolution - 1):
		for x_i in range(resolution - 1):
			var a := z_i * resolution + x_i
			var b := a + 1
			var c := (z_i + 1) * resolution + x_i
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var base_mesh := ArrayMesh.new()
	base_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(base_mesh, 0)
	surface_tool.generate_normals()
	surface_tool.generate_tangents()
	var final_mesh := surface_tool.commit()

	vertex_count = vertices.size()
	triangle_count = indices.size() / 3
	return final_mesh


func _vertex_color_for(x: float, z: float, h: float, normal: Vector3) -> Color:
	var zone: int = sampler.zone_at(x, z)
	var slope: float = 1.0 - clamp(normal.y, 0.0, 1.0)

	var salt := 0.0
	var wet := 0.0
	var rocky := 0.0
	var path := 0.0

	if zone == ZONE_SALT_DUST_EDGE:
		salt = 0.82
	if zone == ZONE_LOWLAND_WET:
		wet = 0.74
	if zone == ZONE_ROCKY_PATCH:
		rocky = 0.74
	if zone == ZONE_PATH_EDGE:
		path = 0.58
	if zone == ZONE_YURT_EDGE:
		path = max(path, 0.28)

	rocky = max(rocky, slope * 0.9)
	rocky = max(rocky, sampler.rock_mask_at(x, z) * 0.74)
	wet = max(wet, 1.0 - smoothstep(-1.08, -0.18, h))
	salt = max(salt, smoothstep(74.0, 112.0, -x) * 0.42)

	var path_distance: float = sampler.path_distance(x, z)
	path = max(path, 1.0 - smoothstep(1.6, 6.2, path_distance))

	return Color(clamp(salt, 0.0, 1.0), clamp(wet, 0.0, 1.0), clamp(rocky, 0.0, 1.0), clamp(path, 0.0, 1.0))


func _mesh_faces(mesh: Mesh) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if mesh == null or mesh.get_surface_count() == 0:
		return faces

	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.size() > 0:
		faces.resize(indices.size())
		for i in range(indices.size()):
			faces[i] = vertices[indices[i]]
	else:
		faces = vertices
	return faces


func _add_debug_zone_markers(parent: Node3D) -> void:
	var debug_root := Node3D.new()
	debug_root.name = "TerrainZoneDebugMarkers"
	parent.add_child(debug_root)

	var material_by_zone := {
		ZONE_YURT_EDGE: _debug_material(Color(0.9, 0.75, 0.25, 0.28)),
		ZONE_LOWLAND_WET: _debug_material(Color(0.2, 0.45, 0.55, 0.28)),
		ZONE_ROCKY_PATCH: _debug_material(Color(0.36, 0.34, 0.32, 0.32)),
		ZONE_PATH_EDGE: _debug_material(Color(0.7, 0.56, 0.34, 0.28)),
		ZONE_SALT_DUST_EDGE: _debug_material(Color(0.8, 0.77, 0.62, 0.26))
	}

	for z in range(-110, 111, 12):
		for x in range(-110, 111, 12):
			var zone: int = sampler.zone_at(float(x), float(z))
			if not material_by_zone.has(zone):
				continue
			var marker := MeshInstance3D.new()
			marker.name = "ZoneMarker"
			var mesh := PlaneMesh.new()
			mesh.size = Vector2(8.0, 8.0)
			marker.mesh = mesh
			marker.position = Vector3(x, sampler.height_at(float(x), float(z)) + 0.035, z)
			marker.set_surface_override_material(0, material_by_zone[zone])
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			debug_root.add_child(marker)


func _debug_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat
