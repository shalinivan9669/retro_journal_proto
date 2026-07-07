extends Node3D
class_name PowerlinePastureController

@export var interaction_distance: float = 12.0


func _ready() -> void:
	_extend_player_interaction_ray()
	_build_ground()
	_build_powerlines()


func _extend_player_interaction_ray() -> void:
	var ray := get_node_or_null("Player/Head/Camera3D/InteractionRay") as RayCast3D
	if ray != null:
		ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
		ray.collide_with_areas = true


func _build_ground() -> void:
	if has_node("PastureGround"):
		return

	var material := StandardMaterial3D.new()
	material.resource_name = "mat_powerline_pasture_ground"
	material.albedo_color = Color(0.22, 0.19, 0.12, 1.0)
	material.roughness = 1.0

	var ground := StaticBody3D.new()
	ground.name = "PastureGround"
	add_child(ground)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GroundMesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(120.0, 0.18, 120.0)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, -0.09, -12.0)
	mesh_instance.set_surface_override_material(0, material)
	ground.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position = mesh_instance.position
	ground.add_child(collision)


func _build_powerlines() -> void:
	if has_node("Powerlines"):
		return

	var powerlines := Node3D.new()
	powerlines.name = "Powerlines"
	add_child(powerlines)

	var pole_mat := _make_material("mat_powerline_pole", Color(0.19, 0.16, 0.13, 1.0))
	var wire_mat := _make_material("mat_powerline_wire", Color(0.025, 0.025, 0.022, 1.0))

	var pylon_positions := [
		Vector3(-24.0, 0.0, -36.0),
		Vector3(0.0, 0.0, -36.0),
		Vector3(24.0, 0.0, -36.0),
	]

	for i in range(pylon_positions.size()):
		_build_pylon(powerlines, "Powerline_%02d" % (i + 1), pylon_positions[i], pole_mat)

	_build_wire(powerlines, "Wire_Left_Top", Vector3(0.0, 7.9, -37.1), Vector3(48.0, 0.045, 0.045), wire_mat)
	_build_wire(powerlines, "Wire_Right_Top", Vector3(0.0, 7.9, -34.9), Vector3(48.0, 0.045, 0.045), wire_mat)
	_build_wire(powerlines, "Wire_Left_Low", Vector3(0.0, 6.8, -37.3), Vector3(48.0, 0.04, 0.04), wire_mat)
	_build_wire(powerlines, "Wire_Right_Low", Vector3(0.0, 6.8, -34.7), Vector3(48.0, 0.04, 0.04), wire_mat)


func _build_pylon(parent: Node3D, node_name: String, pos: Vector3, material: Material) -> void:
	var pylon := Node3D.new()
	pylon.name = node_name
	pylon.position = pos
	parent.add_child(pylon)

	_box(pylon, "LeftLeg", Vector3(-0.85, 3.3, 0.0), Vector3(0.18, 6.6, 0.18), material, Vector3(0.0, 0.0, deg_to_rad(-6.0)))
	_box(pylon, "RightLeg", Vector3(0.85, 3.3, 0.0), Vector3(0.18, 6.6, 0.18), material, Vector3(0.0, 0.0, deg_to_rad(6.0)))
	_box(pylon, "TopCrossbar", Vector3(0.0, 7.1, 0.0), Vector3(4.2, 0.18, 0.18), material)
	_box(pylon, "MidCrossbar", Vector3(0.0, 5.6, 0.0), Vector3(2.7, 0.16, 0.16), material)
	_box(pylon, "CenterSpine", Vector3(0.0, 4.0, 0.0), Vector3(0.14, 6.0, 0.14), material)
	_box(pylon, "LeftBrace", Vector3(-0.44, 5.9, 0.0), Vector3(0.12, 2.2, 0.12), material, Vector3(0.0, 0.0, deg_to_rad(35.0)))
	_box(pylon, "RightBrace", Vector3(0.44, 5.9, 0.0), Vector3(0.12, 2.2, 0.12), material, Vector3(0.0, 0.0, deg_to_rad(-35.0)))


func _build_wire(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material) -> void:
	_box(parent, node_name, pos, size, material)


func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _make_material(name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = 0.95
	return material
