extends Node3D
class_name PowerlinePastureController

@export var interaction_distance: float = 12.0

const BACKDROP_DIR := "res://assets/textures/backdrops"
const TEX_SALT_FLAT := BACKDROP_DIR + "/balkhash_salt_flat_01.png"
const TEX_SHORE_STRIP := BACKDROP_DIR + "/balkhash_shore_strip_01.png"
const TEX_BACKDROP_MAIN := BACKDROP_DIR + "/balkhash_far_backdrop_main_01.png"
const TEX_BACKDROP_ALT := BACKDROP_DIR + "/balkhash_far_backdrop_alt_01.png"
const TEX_INDUSTRIAL := BACKDROP_DIR + "/balkhash_industrial_smudge_01.png"
const TEX_HORIZON_FOG := BACKDROP_DIR + "/balkhash_horizon_fog_01.png"


func _ready() -> void:
	_extend_player_interaction_ray()
	_tag_existing_horses()
	_ensure_yurt_entrance_marker()
	_build_ground()
	_build_distant_balkhash_view()
	_build_powerlines()


func _extend_player_interaction_ray() -> void:
	var ray := get_node_or_null("Player/Head/Camera3D/InteractionRay") as RayCast3D
	if ray != null:
		ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
		ray.collide_with_areas = true


func _tag_existing_horses() -> void:
	var horses := get_node_or_null("Horses")
	if horses == null:
		return
	for child in horses.get_children():
		if child is Node3D:
			child.add_to_group("horse")


func _ensure_yurt_entrance_marker() -> void:
	if get_tree().get_first_node_in_group("yurt_entrance") != null:
		return
	var marker := Marker3D.new()
	marker.name = "YurtEntranceMarker"
	marker.position = Vector3(0.0, 0.0, 6.0)
	marker.add_to_group("yurt_entrance")
	add_child(marker)


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
	_build_distant_powerline_extension(powerlines, pole_mat, wire_mat)


func _build_distant_balkhash_view() -> void:
	if has_node("DistantBalkhashRoot"):
		return

	var root := Node3D.new()
	root.name = "DistantBalkhashRoot"
	add_child(root)

	var salt_mat := _make_unshaded_alpha_material("mat_balkhash_salt_flat", TEX_SALT_FLAT, Color(0.92, 0.88, 0.76, 0.94), false)
	var shore_mat := _make_unshaded_alpha_material("mat_balkhash_shore_strip", TEX_SHORE_STRIP, Color(0.34, 0.28, 0.22, 0.96), false)
	var water_mat := _make_unshaded_alpha_material("mat_balkhash_far_water", "", Color(0.36, 0.49, 0.50, 0.62), true)
	var backdrop_main_mat := _make_unshaded_alpha_material("mat_balkhash_backdrop_main", TEX_BACKDROP_MAIN, Color(0.72, 0.78, 0.78, 0.88), true)
	var backdrop_alt_mat := _make_unshaded_alpha_material("mat_balkhash_backdrop_alt", TEX_BACKDROP_ALT, Color(0.58, 0.66, 0.66, 0.42), true)
	var fog_mat := _make_unshaded_alpha_material("mat_balkhash_horizon_fog", TEX_HORIZON_FOG, Color(0.62, 0.66, 0.64, 0.52), true)
	var industrial_mat := _make_unshaded_alpha_material("mat_balkhash_industrial_smudge", TEX_INDUSTRIAL, Color(0.22, 0.23, 0.22, 0.34), true)

	_add_horizontal_plane(root, "SaltFlatExtensionPlane", Vector3(0.0, 0.012, -70.0), Vector2(168.0, 82.0), salt_mat)
	_add_horizontal_plane(root, "SaltFlatSoftShoulderLeft", Vector3(-54.0, 0.014, -82.0), Vector2(64.0, 42.0), salt_mat, deg_to_rad(-3.0))
	_add_horizontal_plane(root, "SaltFlatSoftShoulderRight", Vector3(50.0, 0.014, -84.0), Vector2(72.0, 44.0), salt_mat, deg_to_rad(4.0))
	_add_horizontal_plane(root, "ShoreMudStrip", Vector3(0.0, 0.018, -111.0), Vector2(170.0, 12.0), shore_mat)
	_add_horizontal_plane(root, "LakeWaterPlane", Vector3(0.0, 0.006, -133.0), Vector2(184.0, 48.0), water_mat)

	_add_backdrop_card(root, "FarBackdropCard", Vector3(-4.0, 10.5, -190.0), Vector2(190.0, 31.0), backdrop_main_mat)
	_add_backdrop_card(root, "FarBackdropAltLowShore", Vector3(22.0, 7.4, -181.0), Vector2(150.0, 21.0), backdrop_alt_mat)
	_add_backdrop_card(root, "HorizonFogCard", Vector3(0.0, 9.2, -168.0), Vector2(210.0, 24.0), fog_mat)
	_add_backdrop_card(root, "FarIndustrialOverlay", Vector3(-24.0, 9.8, -178.0), Vector2(56.0, 10.0), industrial_mat)


func _build_distant_powerline_extension(parent: Node3D, _pole_mat: Material, wire_mat: Material) -> void:
	var far_pole_mat := _make_material("mat_powerline_far_pole", Color(0.42, 0.40, 0.34, 1.0))
	var far_wire_mat := _make_material("mat_powerline_far_wire", Color(0.018, 0.018, 0.016, 1.0))
	var distant_pylon_pos := Vector3(42.0, 0.0, -64.0)

	_build_pylon(parent, "Powerline_Distant_Right", distant_pylon_pos, far_pole_mat, 0.62)

	_build_sagging_wire(parent, "DistantWire_Top_Left", Vector3(25.8, 7.9, -37.1), Vector3(40.8, 4.55, -65.0), 0.55, far_wire_mat, 18)
	_build_sagging_wire(parent, "DistantWire_Top_Right", Vector3(25.8, 7.9, -34.9), Vector3(43.0, 4.55, -63.0), 0.58, far_wire_mat, 18)
	_build_sagging_wire(parent, "DistantWire_Low_Left", Vector3(25.2, 6.8, -37.3), Vector3(41.2, 3.68, -65.3), 0.46, wire_mat, 16)
	_build_sagging_wire(parent, "DistantWire_Low_Right", Vector3(25.2, 6.8, -34.7), Vector3(42.8, 3.68, -62.8), 0.48, wire_mat, 16)


func _build_pylon(parent: Node3D, node_name: String, pos: Vector3, material: Material, scale_value: float = 1.0) -> void:
	var pylon := Node3D.new()
	pylon.name = node_name
	pylon.position = pos
	pylon.scale = Vector3.ONE * scale_value
	match node_name:
		"Powerline_01":
			pylon.add_to_group("vfx_lep_radiation")
		"Powerline_02":
			pylon.add_to_group("vfx_lep_rust")
		"Powerline_03":
			pylon.add_to_group("vfx_lep_ion")
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


func _build_sagging_wire(parent: Node3D, node_name: String, start: Vector3, end: Vector3, sag: float, material: Material, segments: int = 18) -> void:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)

	var previous := start
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := start.lerp(end, t)
		point.y -= sin(t * PI) * sag
		_wire_segment(root, "seg_%02d" % i, previous, point, material)
		previous = point


func _wire_segment(parent: Node3D, node_name: String, a: Vector3, b: Vector3, material: Material) -> void:
	var direction := b - a
	var length := direction.length()
	if length <= 0.001:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.032, 0.032, length)
	mesh_instance.mesh = mesh
	mesh_instance.position = (a + b) * 0.5
	mesh_instance.look_at_from_position(mesh_instance.position, b, Vector3.UP)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)


func _add_horizontal_plane(parent: Node3D, node_name: String, pos: Vector3, size: Vector2, material: Material, rotation_y: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation.y = rotation_y
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_backdrop_card(parent: Node3D, node_name: String, pos: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _make_unshaded_alpha_material(name: String, texture_path: String = "", color: Color = Color.WHITE, transparent: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	if texture_path != "":
		var texture := load(texture_path) as Texture2D
		if texture != null:
			material.albedo_texture = texture

	return material


func _make_material(name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = 0.95
	return material
