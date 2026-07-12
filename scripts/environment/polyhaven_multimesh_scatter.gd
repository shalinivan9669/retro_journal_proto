extends RefCounted
class_name PolyhavenMultimeshScatter

var sampler
var rng := RandomNumberGenerator.new()


func build_multimesh_from_mesh(
	parent: Node3D,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D],
	node_name: String
) -> MultiMeshInstance3D:
	if parent == null or mesh == null or transforms.is_empty():
		return null

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material != null:
		instance.material_override = material
	parent.add_child(instance)
	return instance


func build_chunked_multimesh_from_mesh(
	parent: Node3D,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D],
	node_name: String,
	chunk_size: float = 40.0,
	visibility_range_end: float = 120.0
) -> Node3D:
	if parent == null or mesh == null or transforms.is_empty():
		return null

	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)

	var safe_chunk_size := maxf(chunk_size, 8.0)
	var chunks: Dictionary = {}
	for world_transform in transforms:
		var key := Vector2i(
			floori(world_transform.origin.x / safe_chunk_size),
			floori(world_transform.origin.z / safe_chunk_size)
		)
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(world_transform)

	var chunk_index := 0
	for key in chunks:
		var chunk_transforms: Array = chunks[key]
		var chunk_origin := Vector3(
			(float(key.x) + 0.5) * safe_chunk_size,
			0.0,
			(float(key.y) + 0.5) * safe_chunk_size
		)
		var local_transforms: Array[Transform3D] = []
		local_transforms.resize(chunk_transforms.size())
		for index in range(chunk_transforms.size()):
			var local_transform: Transform3D = chunk_transforms[index]
			local_transform.origin -= chunk_origin
			local_transforms[index] = local_transform

		var instance := build_multimesh_from_mesh(
			root,
			mesh,
			material,
			local_transforms,
			"Chunk_%03d" % chunk_index
		)
		instance.position = chunk_origin
		instance.visibility_range_end = maxf(visibility_range_end, safe_chunk_size * 1.5)
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		instance.extra_cull_margin = 3.0
		chunk_index += 1

	return root


func make_transform(pos: Vector3, yaw: float, scale: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw)
	basis = basis.scaled(scale)
	return Transform3D(basis, pos)
