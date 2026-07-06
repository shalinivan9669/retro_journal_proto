extends Node3D

const WALL_MATERIAL: Material = preload("res://materials/mat_wall.tres")
const FLOOR_MATERIAL: Material = preload("res://materials/mat_floor.tres")
const ROOF_MATERIAL: Material = preload("res://materials/mat_ceiling.tres")
const RING_MATERIAL: Material = preload("res://materials/mat_door.tres")
const SKY_MATERIAL: Material = preload("res://materials/mat_sky_shanyrak.tres")

@export var yurt_radius: float = 10.0
@export var wall_height: float = 6.0
@export var roof_peak_height: float = 10.3
@export var shanyrak_inner_radius: float = 3.0
@export var wall_thickness: float = 0.28
@export var roof_thickness: float = 0.16
@export var exit_opening_width: float = 4.2


func _ready() -> void:
	_clear_existing_geometry()
	_build_floor()
	_build_walls()
	_build_roof()
	_build_shanyrak()
	_build_sky_disc()


func _clear_existing_geometry() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "YurtOctagonalFloor"
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := CylinderMesh.new()
	mesh.top_radius = yurt_radius
	mesh.bottom_radius = yurt_radius
	mesh.height = 0.2
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, FLOOR_MATERIAL)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = yurt_radius
	shape.height = 0.2
	collision.shape = shape
	body.add_child(collision)


func _build_walls() -> void:
	var side_length: float = 2.0 * yurt_radius * tan(PI / 8.0)
	var wall_size := Vector3(side_length + 0.18, wall_height, wall_thickness)

	for index: int in range(8):
		var theta: float = -PI * 0.5 + float(index) * TAU / 8.0
		var radial := Vector3(cos(theta), 0.0, sin(theta))
		var tangent := Vector3(-sin(theta), 0.0, cos(theta))
		var origin := radial * yurt_radius + Vector3.UP * (wall_height * 0.5)
		var basis := Basis(tangent, Vector3.UP, radial)
		if index == 0:
			_build_exit_wall(origin, tangent, basis, side_length)
		else:
			_make_static_box("YurtWall_%02d" % (index + 1), origin, basis, wall_size, WALL_MATERIAL)


func _build_exit_wall(origin: Vector3, tangent: Vector3, basis: Basis, side_length: float) -> void:
	var piece_length: float = max(0.4, (side_length - exit_opening_width) * 0.5)
	var piece_size := Vector3(piece_length + 0.18, wall_height, wall_thickness)
	var offset: float = (exit_opening_width + piece_length) * 0.5
	_make_static_box("YurtWall_01_LeftOfExit", origin - tangent * offset, basis, piece_size, WALL_MATERIAL)
	_make_static_box("YurtWall_01_RightOfExit", origin + tangent * offset, basis, piece_size, WALL_MATERIAL)


func _build_roof() -> void:
	var side_length: float = 2.0 * yurt_radius * tan(PI / 8.0)
	var radial_length: float = yurt_radius - shanyrak_inner_radius
	var roof_size := Vector3(side_length + 0.35, roof_thickness, radial_length + 0.25)

	for index: int in range(8):
		var theta: float = -PI * 0.5 + float(index) * TAU / 8.0
		var radial := Vector3(cos(theta), 0.0, sin(theta))
		var tangent := Vector3(-sin(theta), 0.0, cos(theta))
		var center_radius: float = (yurt_radius + shanyrak_inner_radius) * 0.5
		var center_height: float = (wall_height + roof_peak_height) * 0.5
		var origin := radial * center_radius + Vector3.UP * center_height
		var slope_axis := Vector3(radial.x * radial_length, wall_height - roof_peak_height, radial.z * radial_length).normalized()
		var normal_axis := slope_axis.cross(tangent).normalized()
		var basis := Basis(tangent, normal_axis, slope_axis)
		_make_mesh_box("YurtRoof_%02d" % (index + 1), origin, basis, roof_size, ROOF_MATERIAL)


func _build_shanyrak() -> void:
	var ring_segment_count := 16
	var ring_radius: float = shanyrak_inner_radius + 0.25
	var ring_arc: float = TAU * ring_radius / float(ring_segment_count) * 0.94
	var ring_size := Vector3(ring_arc, 0.22, 0.28)

	for index: int in range(ring_segment_count):
		var theta: float = float(index) * TAU / float(ring_segment_count)
		var radial := Vector3(cos(theta), 0.0, sin(theta))
		var tangent := Vector3(-sin(theta), 0.0, cos(theta))
		var origin := radial * ring_radius + Vector3.UP * roof_peak_height
		var basis := Basis(tangent, Vector3.UP, radial)
		_make_mesh_box("ShanyrakRing_%02d" % (index + 1), origin, basis, ring_size, RING_MATERIAL)

	var beam_count := 16
	var radial_length: float = yurt_radius - shanyrak_inner_radius
	var beam_size := Vector3(0.14, 0.14, radial_length + 0.2)

	for index: int in range(beam_count):
		var theta: float = float(index) * TAU / float(beam_count)
		var radial := Vector3(cos(theta), 0.0, sin(theta))
		var tangent := Vector3(-sin(theta), 0.0, cos(theta))
		var center_radius: float = (yurt_radius + shanyrak_inner_radius) * 0.5
		var center_height: float = (wall_height + roof_peak_height) * 0.5
		var origin := radial * center_radius + Vector3.UP * center_height
		var slope_axis := Vector3(radial.x * radial_length, wall_height - roof_peak_height, radial.z * radial_length).normalized()
		var normal_axis := slope_axis.cross(tangent).normalized()
		var basis := Basis(tangent, normal_axis, slope_axis)
		_make_mesh_box("ShanyrakBeam_%02d" % (index + 1), origin, basis, beam_size, RING_MATERIAL)


func _build_sky_disc() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SkyDisc"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(shanyrak_inner_radius * 3.2, 0.08, shanyrak_inner_radius * 3.2)
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, SKY_MATERIAL)
	mesh_instance.position = Vector3(0.0, roof_peak_height + 0.45, 0.0)
	add_child(mesh_instance)


func _make_static_box(node_name: String, origin: Vector3, basis: Basis, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = Transform3D(basis, origin)
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	return body


func _make_mesh_box(node_name: String, origin: Vector3, basis: Basis, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.transform = Transform3D(basis, origin)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	add_child(mesh_instance)
	return mesh_instance
