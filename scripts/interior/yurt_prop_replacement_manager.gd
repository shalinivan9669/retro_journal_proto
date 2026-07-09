extends RefCounted
class_name YurtPropReplacementManager

const PROP_DIR := "res://assets/polyhaven/props"
const TV_HERO_SCENE := "res://scenes/interior/props/Television01Hero.tscn"
const TABLE_HERO_SCENE := "res://scenes/interior/props/GallineraMediaTable.tscn"
const BOOMBOX_HERO_SCENE := "res://scenes/interior/props/BoomboxHero.tscn"
const BOULDER_02_SCENE := "res://scenes/environment/polyhaven/NamaqualandBoulder02.tscn"
const BOULDER_04_SCENE := "res://scenes/environment/polyhaven/NamaqualandBoulder04.tscn"


func replace_tv_visual(tv_root: Node3D) -> void:
	if tv_root == null:
		return
	_hide_named_children(tv_root, ["TVModel"])
	_hide_named_children(tv_root, ["VisibleTVModel"])

	var visual := _instantiate_exact_scene(TV_HERO_SCENE, "Television01Visual", "Television_01")
	if visual == null:
		push_warning("Exact Poly Haven asset Television_01 is missing; TV visual was not replaced.")
		return
	tv_root.add_child(visual)
	visual.position = Vector3(0.0, 0.0, 0.0)
	visual.rotation_degrees = Vector3.ZERO
	visual.scale = Vector3.ONE * 1.0
	_resize_collision_box(tv_root, Vector3(0.50, 0.56, 0.42), Vector3(0.0, 0.27, 0.04))
	_ensure_front_interaction_area(tv_root, "TVFrontInteractionArea", Vector3(0.54, 0.58, 0.20), Vector3(0.0, 0.27, 0.31))

	var screen_proxy := _find_screen_proxy(visual)
	if screen_proxy != null:
		_retarget_video_screen(tv_root, screen_proxy)


func replace_radio_visual(radio_root: Node3D) -> void:
	if radio_root == null:
		return
	for child in radio_root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false

	var visual := _instantiate_exact_scene(BOOMBOX_HERO_SCENE, "BoomboxVisual", "boombox")
	if visual == null:
		push_warning("Exact Poly Haven asset boombox is missing; radio visual was not replaced.")
		return
	radio_root.add_child(visual)
	visual.position = Vector3(0.0, 0.0, 0.0)
	visual.rotation_degrees = Vector3.ZERO
	visual.scale = Vector3.ONE * 1.0
	_resize_collision_box(radio_root, Vector3(1.04, 0.72, 0.48), Vector3(0.0, 0.3, 0.04))
	_ensure_front_interaction_area(radio_root, "RadioFrontInteractionArea", Vector3(1.55, 0.98, 0.34), Vector3(0.0, 0.38, 0.35))


func add_media_table(parent: Node3D, position: Vector3, rotation_y: float, fallback_material: Material) -> Node3D:
	var table := _instantiate_exact_scene(TABLE_HERO_SCENE, "GallineraMediaTable", "gallinera_table")
	if table == null:
		push_warning("Exact Poly Haven asset gallinera_table is missing; media table was not replaced.")
		return null
	parent.add_child(table)
	table.position = position
	table.rotation.y = rotation_y
	table.scale = Vector3(4.25, 3.4, 3.65)
	return table


func add_bed(parent: Node3D, position: Vector3, rotation_y: float, fallback_material: Material, cloth_material: Material) -> Node3D:
	var bed := _instantiate_prop("GothicBed_01", "Phase2GothicBed")
	if bed == null:
		bed = _make_fallback_bed("Phase2GothicBed", fallback_material, cloth_material)
	parent.add_child(bed)
	bed.position = position
	bed.rotation.y = rotation_y
	bed.scale = Vector3.ONE * 1.84
	_add_toy_under_bed_leg(bed)
	return bed


func add_bull_head(parent: Node3D, position: Vector3, rotation_y: float, fallback_material: Material) -> Node3D:
	var bull := _instantiate_prop("bull_head", "Phase2BullHeadWallTrophy")
	if bull == null:
		bull = _make_fallback_bull_head("Phase2BullHeadWallTrophy", fallback_material)
	parent.add_child(bull)
	bull.position = position
	bull.rotation.y = rotation_y
	bull.scale = Vector3.ONE * 0.58
	return bull


func add_screen(parent: Node3D, position: Vector3, rotation_y: float, fallback_material: Material) -> Node3D:
	var screen := _instantiate_prop("chinese_screen_panels", "Phase2ChineseScreenPanels")
	if screen == null:
		screen = _make_fallback_screen("Phase2ChineseScreenPanels", fallback_material)
	parent.add_child(screen)
	screen.position = position
	screen.rotation.y = rotation_y
	screen.scale = Vector3.ONE * 1.64
	return screen


func add_exterior_generator(parent: Node3D, position: Vector3, rotation_y: float, fallback_material: Material) -> Node3D:
	var generator := _instantiate_prop("portable_generator", "Phase2PortableGenerator")
	if generator == null:
		generator = _make_fallback_generator("Phase2PortableGenerator", fallback_material)
	parent.add_child(generator)
	generator.position = position
	generator.rotation.y = rotation_y
	generator.scale = Vector3.ONE * 2.16
	return generator


func add_exterior_console_table(parent: Node3D, position: Vector3, rotation_y: float, fallback_material: Material) -> Node3D:
	var table := _instantiate_prop("chinese_console_table", "Phase2ExteriorConsoleTable")
	if table == null:
		table = _make_fallback_media_table("Phase2ExteriorConsoleTable", fallback_material)
	parent.add_child(table)
	table.position = position
	table.rotation.y = rotation_y
	table.scale = Vector3(0.82, 0.82, 0.58)
	return table


func add_boulder_02(parent: Node3D, position: Vector3, rotation_y: float) -> Node3D:
	var boulder := _instantiate_exact_scene(BOULDER_02_SCENE, "NamaqualandBoulder02", "namaqualand_boulder_02")
	if boulder == null:
		push_warning("Exact Poly Haven asset namaqualand_boulder_02 is missing; boulder was not placed.")
		return null
	parent.add_child(boulder)
	boulder.position = position
	boulder.rotation.y = rotation_y
	boulder.rotation_degrees.x = -3.0
	boulder.scale = Vector3.ONE * 0.82
	return boulder


func add_boulder_04(parent: Node3D, position: Vector3, rotation_y: float) -> Node3D:
	var boulder := _instantiate_exact_scene(BOULDER_04_SCENE, "NamaqualandBoulder04", "namaqualand_boulder_04")
	if boulder == null:
		push_warning("Exact Poly Haven asset namaqualand_boulder_04 is missing; boulder was not placed.")
		return null
	parent.add_child(boulder)
	boulder.position = position
	boulder.rotation.y = rotation_y
	boulder.rotation_degrees.x = 4.0
	boulder.scale = Vector3.ONE * 0.68
	return boulder


func _instantiate_exact_scene(scene_path: String, node_name: String, asset_id: String) -> Node3D:
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Exact Poly Haven wrapper missing for %s: %s" % [asset_id, scene_path])
		return null
	var packed := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if packed == null:
		push_warning("Exact Poly Haven wrapper failed to load for %s: %s" % [asset_id, scene_path])
		return null
	var instance := packed.instantiate()
	var node := instance as Node3D
	if node == null:
		node = Node3D.new()
		node.add_child(instance)
	node.name = node_name
	_prepare_imported_visual(node)
	return node


func _instantiate_prop(asset_id: String, node_name: String) -> Node3D:
	for resolution in ["2k", "1k", "4k", "8k"]:
		var path := "%s/%s_%s.gltf" % [PROP_DIR, asset_id, resolution]
		if not ResourceLoader.exists(path, "PackedScene"):
			continue
		var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		var node := instance as Node3D
		if node == null:
			node = Node3D.new()
			node.add_child(instance)
		node.name = node_name
		_prepare_imported_visual(node)
		return node
	return null


func _prepare_imported_visual(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface)
				if material is BaseMaterial3D:
					var duplicate := material.duplicate() as BaseMaterial3D
					duplicate.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_instance.set_surface_override_material(surface, duplicate)
	for child in node.get_children():
		_prepare_imported_visual(child)


func _hide_named_children(root: Node, names: Array[String]) -> void:
	for child_name in names:
		var child := root.get_node_or_null(child_name)
		if child is Node3D:
			(child as Node3D).visible = false


func _hide_visible_tv_parts_except_screen(tv_root: Node) -> void:
	var visible_model := tv_root.get_node_or_null("VisibleTVModel")
	if visible_model == null:
		return
	for child in visible_model.get_children():
		if child is MeshInstance3D and child.name != "Screen":
			(child as MeshInstance3D).visible = false


func _resize_collision_box(root: Node, size: Vector3, position: Vector3) -> void:
	var shape_node := root.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = position


func _ensure_front_interaction_area(root: Node3D, area_name: String, size: Vector3, position: Vector3) -> void:
	var area := root.get_node_or_null(area_name) as Area3D
	if area == null:
		area = Area3D.new()
		area.name = area_name
		root.add_child(area)
		area.owner = root.owner
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.position = position
	area.rotation = Vector3.ZERO

	var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		area.add_child(shape_node)
		shape_node.owner = root.owner
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = Vector3.ZERO


func _retarget_video_screen(tv_root: Node, screen_mesh: MeshInstance3D) -> void:
	var video_screen := tv_root.get_node_or_null("TVVideoScreen")
	if video_screen == null:
		return
	video_screen.set("screen_mesh_path", video_screen.get_path_to(screen_mesh))
	video_screen.set("screen_mesh", screen_mesh)
	if video_screen.has_method("_prepare_screen_material"):
		video_screen.call("_prepare_screen_material")


func _find_screen_proxy(root: Node) -> MeshInstance3D:
	var named := root.find_child("ScreenProxy", true, false)
	if named is MeshInstance3D:
		return named as MeshInstance3D
	return null


func _make_fallback_tv(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var body_mat := _mat(Color(0.12, 0.10, 0.085, 1.0), 0.82)
	var trim_mat := _mat(Color(0.28, 0.22, 0.16, 1.0), 0.76)
	var screen_mat := _mat(Color(0.02, 0.075, 0.055, 1.0), 0.28)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.05, 0.16, 0.11, 1.0)
	screen_mat.emission_energy_multiplier = 1.2

	_add_box(root, "Body", Vector3(1.78, 1.1, 0.82), Vector3(0.0, 0.58, -0.04), body_mat)
	_add_box(root, "WoodTrim", Vector3(1.92, 1.24, 0.08), Vector3(0.0, 0.6, 0.43), trim_mat)
	var screen := MeshInstance3D.new()
	screen.name = "ScreenProxy"
	var screen_mesh := QuadMesh.new()
	screen_mesh.size = Vector2(1.22, 0.72)
	screen.mesh = screen_mesh
	screen.position = Vector3(-0.22, 0.62, 0.475)
	screen.set_surface_override_material(0, screen_mat)
	root.add_child(screen)
	_add_box(root, "ControlPanel", Vector3(0.28, 0.7, 0.04), Vector3(0.62, 0.61, 0.48), trim_mat)
	for y in [0.72, 0.48]:
		var knob := MeshInstance3D.new()
		knob.name = "Knob"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.055
		mesh.bottom_radius = 0.055
		mesh.height = 0.045
		mesh.radial_segments = 18
		knob.mesh = mesh
		knob.position = Vector3(0.62, y, 0.52)
		knob.rotation_degrees.x = 90.0
		knob.set_surface_override_material(0, trim_mat)
		root.add_child(knob)
	return root


func _make_fallback_boombox(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var body_mat := _mat(Color(0.09, 0.085, 0.075, 1.0), 0.74)
	var metal_mat := _mat(Color(0.42, 0.39, 0.34, 1.0), 0.55)
	var display_mat := _mat(Color(0.02, 0.12, 0.09, 1.0), 0.38)
	display_mat.emission_enabled = true
	display_mat.emission = Color(0.04, 0.28, 0.2, 1.0)
	display_mat.emission_energy_multiplier = 0.6
	_add_box(root, "BoomboxBody", Vector3(1.18, 0.44, 0.34), Vector3(0.0, 0.28, 0.0), body_mat)
	_add_box(root, "BoomboxHandle", Vector3(0.84, 0.08, 0.08), Vector3(0.0, 0.58, 0.0), metal_mat)
	_add_box(root, "BoomboxDisplay", Vector3(0.32, 0.14, 0.035), Vector3(0.0, 0.33, -0.19), display_mat)
	for x in [-0.38, 0.38]:
		var speaker := MeshInstance3D.new()
		speaker.name = "Speaker"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.16
		mesh.bottom_radius = 0.16
		mesh.height = 0.055
		mesh.radial_segments = 32
		speaker.mesh = mesh
		speaker.position = Vector3(x, 0.29, -0.2)
		speaker.rotation_degrees.x = 90.0
		speaker.set_surface_override_material(0, metal_mat)
		root.add_child(speaker)
	return root


func _make_fallback_media_table(node_name: String, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	_add_box(root, "ConsoleTop", Vector3(2.25, 0.16, 0.78), Vector3(0.0, 0.72, 0.0), material)
	_add_box(root, "ConsoleShelf", Vector3(2.05, 0.12, 0.66), Vector3(0.0, 0.38, 0.0), material)
	for x in [-0.95, 0.95]:
		for z in [-0.28, 0.28]:
			_add_box(root, "ConsoleLeg", Vector3(0.13, 0.72, 0.13), Vector3(x, 0.36, z), material)
	return root


func _make_fallback_bed(node_name: String, wood_material: Material, cloth_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	_add_box(root, "BedFrame", Vector3(2.3, 0.22, 3.25), Vector3(0.0, 0.42, 0.0), wood_material)
	_add_box(root, "Mattress", Vector3(2.1, 0.24, 2.9), Vector3(0.0, 0.66, 0.0), cloth_material)
	_add_box(root, "Headboard", Vector3(2.45, 1.25, 0.18), Vector3(0.0, 0.98, 1.68), wood_material)
	_add_box(root, "Footboard", Vector3(2.35, 0.72, 0.16), Vector3(0.0, 0.72, -1.66), wood_material)
	return root


func _make_fallback_bull_head(node_name: String, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var head := MeshInstance3D.new()
	head.name = "LowPolyTrophyHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.42
	head_mesh.height = 0.62
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.scale = Vector3(0.9, 1.0, 0.62)
	head.set_surface_override_material(0, material)
	root.add_child(head)
	for x in [-0.38, 0.38]:
		var horn := MeshInstance3D.new()
		horn.name = "Horn"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.025
		mesh.bottom_radius = 0.075
		mesh.height = 0.62
		mesh.radial_segments = 8
		horn.mesh = mesh
		horn.position = Vector3(x, 0.18, -0.05)
		var horn_side := 1.0 if x > 0.0 else -1.0
		horn.rotation_degrees = Vector3(0.0, 0.0, -42.0 * horn_side)
		horn.set_surface_override_material(0, material)
		root.add_child(horn)
	return root


func _make_fallback_screen(node_name: String, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	for index in range(3):
		var panel := _add_box(root, "ScreenPanel_%02d" % index, Vector3(0.74, 2.05, 0.055), Vector3((float(index) - 1.0) * 0.72, 1.02, 0.0), material)
		panel.rotation_degrees.y = -8.0 + float(index) * 8.0
	return root


func _make_fallback_generator(node_name: String, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	_add_box(root, "GeneratorBody", Vector3(0.98, 0.58, 0.55), Vector3(0.0, 0.34, 0.0), material)
	_add_box(root, "GeneratorHandle", Vector3(1.1, 0.08, 0.08), Vector3(0.0, 0.72, -0.02), material)
	for x in [-0.38, 0.38]:
		var wheel := MeshInstance3D.new()
		wheel.name = "GeneratorWheel"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 0.12
		mesh.height = 0.08
		mesh.radial_segments = 18
		wheel.mesh = mesh
		wheel.position = Vector3(x, 0.14, -0.32)
		wheel.rotation_degrees.z = 90.0
		wheel.set_surface_override_material(0, material)
		root.add_child(wheel)
	return root


func _add_toy_under_bed_leg(bed: Node3D) -> void:
	var toy_mat := _mat(Color(0.16, 0.32, 0.46, 1.0), 0.7)
	var toy := Node3D.new()
	toy.name = "SmallMilkCartonSizedToy"
	toy.position = Vector3(-1.02, 0.14, -1.26)
	toy.rotation_degrees = Vector3(0.0, -24.0, 7.0)
	bed.add_child(toy)
	_add_box(toy, "ToyBody", Vector3(0.18, 0.28, 0.12), Vector3.ZERO, toy_mat)
	_add_box(toy, "ToyTop", Vector3(0.16, 0.08, 0.1), Vector3(0.0, 0.16, 0.0), _mat(Color(0.8, 0.76, 0.62, 1.0), 0.82))


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
