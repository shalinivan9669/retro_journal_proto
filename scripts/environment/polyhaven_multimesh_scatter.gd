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


func make_transform(pos: Vector3, yaw: float, scale: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw)
	basis = basis.scaled(scale)
	return Transform3D(basis, pos)
