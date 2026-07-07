extends Node3D
class_name ProceduralHorseBuilder

@export var coat_color: Color = Color(0.09, 0.055, 0.035, 1.0)
@export var mane_color: Color = Color(0.015, 0.012, 0.01, 1.0)


func _ready() -> void:
	add_to_group("horses")
	if get_child_count() > 0:
		return
	_build_horse()


func _build_horse() -> void:
	var coat := _make_material("HorseCoat", coat_color)
	var mane := _make_material("HorseMane", mane_color)

	_box("Body", Vector3(0.0, 0.95, 0.0), Vector3(1.6, 0.62, 0.55), coat)
	_box("Chest", Vector3(0.62, 1.02, 0.0), Vector3(0.45, 0.7, 0.58), coat)
	_box("Neck", Vector3(0.92, 1.45, 0.0), Vector3(0.34, 0.82, 0.32), coat, Vector3(0.0, 0.0, deg_to_rad(-22.0)))
	_box("Head", Vector3(1.18, 1.75, 0.0), Vector3(0.5, 0.34, 0.32), coat, Vector3(0.0, 0.0, deg_to_rad(-8.0)))
	_box("Muzzle", Vector3(1.5, 1.68, 0.0), Vector3(0.24, 0.22, 0.26), coat)
	_box("Mane", Vector3(0.73, 1.55, 0.0), Vector3(0.1, 0.7, 0.36), mane, Vector3(0.0, 0.0, deg_to_rad(-22.0)))
	_box("Tail", Vector3(-0.95, 1.02, 0.0), Vector3(0.18, 0.72, 0.18), mane, Vector3(0.0, 0.0, deg_to_rad(-35.0)))

	for index in range(4):
		var x := -0.48 if index < 2 else 0.48
		var z := -0.2 if index % 2 == 0 else 0.2
		_box("Leg_%02d" % (index + 1), Vector3(x, 0.42, z), Vector3(0.16, 0.85, 0.16), coat)
		_box("Hoof_%02d" % (index + 1), Vector3(x + 0.03, 0.04, z), Vector3(0.22, 0.12, 0.2), mane)


func _box(name_suffix: String, local_pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_suffix
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.rotation = rot
	mesh_instance.set_surface_override_material(0, material)
	add_child(mesh_instance)
	return mesh_instance


func _make_material(name_prefix: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "%s_%s" % [name_prefix, name]
	material.albedo_color = color
	material.roughness = 0.9
	return material
