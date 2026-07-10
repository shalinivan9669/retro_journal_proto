extends Node3D
class_name YurtInteriorDressingBuilder

const TEXTILE_LIBRARY_SCRIPT: Script = preload("res://scripts/interior/yurt_textile_library.gd")
const PROP_MANAGER_SCRIPT: Script = preload("res://scripts/interior/yurt_prop_replacement_manager.gd")
const BED_VOID_INTERACTABLE_SCRIPT: Script = preload("res://scripts/bed_void_interactable.gd")
const YURT_WALL_MATERIAL: Material = preload("res://materials/yurt/mat_yurt_wall_weathered_felt.tres")
const YURT_CEILING_MATERIAL: Material = preload("res://materials/yurt/mat_yurt_roof_smoked_felt.tres")
const MAT_VELVET: Material = preload("res://materials/polyhaven/textiles/mat_velour_velvet_hero.tres")
const MAT_TEDDY: Material = preload("res://materials/polyhaven/textiles/mat_curly_teddy_checkered_thick.tres")
const MAT_JACQUARD: Material = preload("res://materials/polyhaven/textiles/mat_quatrefoil_jacquard_tablecloth.tres")
const MAT_WOOL: Material = preload("res://materials/polyhaven/textiles/mat_wool_boucle_heavy.tres")
const MAT_WAFFLE: Material = preload("res://materials/polyhaven/textiles/mat_waffle_pique_cotton_flags.tres")

@export var interior_upgrade_enabled: bool = true
@export_range(1, 3, 1) var textile_density_level: int = 1
@export var use_ultra_textile_quality: bool = false
@export var enlarge_yurt_enabled: bool = true
@export var add_low_table_enabled: bool = true
@export var add_screen_enabled: bool = true
@export var replace_media_props_enabled: bool = true
@export var add_bed_enabled: bool = true
@export var add_exterior_props_enabled: bool = true
@export var debug_hide_textiles: bool = false
@export var debug_hide_new_props: bool = false

@export var yurt_scale_xz: float = 1.175
@export var wall_uv_repeats_per_meter: Vector2 = Vector2(0.07, 0.063333)
@export var roof_uv_repeats_per_meter: Vector2 = Vector2(0.204, 0.18)
@export var widen_shanyrak_enabled: bool = true
@export var shanyrak_open_radius: float = 3.35
@export var shanyrak_open_blend_radius: float = 1.45

var _root: Node3D
var _textiles
var _props
var _wood_material: StandardMaterial3D
var _dark_material: StandardMaterial3D


func _ready() -> void:
	if not interior_upgrade_enabled:
		return
	call_deferred("_apply_upgrade")


func _apply_upgrade() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var old := scene.get_node_or_null("YurtInteriorPhase2Root")
	if old != null:
		old.queue_free()

	_root = Node3D.new()
	_root.name = "YurtInteriorPhase2Root"
	scene.add_child(_root)

	_textiles = TEXTILE_LIBRARY_SCRIPT.new()
	_props = PROP_MANAGER_SCRIPT.new()
	_wood_material = _make_material("mat_phase2_deep_worn_wood", Color(0.34, 0.22, 0.13, 1.0), 0.82)
	_dark_material = _make_material("mat_phase2_dark_metal_aged", Color(0.07, 0.068, 0.062, 1.0), 0.74)

	if enlarge_yurt_enabled:
		_enlarge_yurt(scene)
	_project_clean_yurt_uvs(scene)
	_apply_yurt_wall_material(scene)
	_apply_yurt_ceiling_material(scene)
	_widen_shanyrak(scene)
	_fix_window_after_yurt_scale(scene)
	_build_yurt_interior_lights(scene)

	if not debug_hide_textiles:
		_build_floor_textile_composition()
		_build_wall_flags()

	if not debug_hide_new_props:
		_build_low_table()
		_build_interior_props(scene)
		_build_exterior_props(scene)


func _enlarge_yurt(scene: Node) -> void:
	var clean_yurt := scene.get_node_or_null("CleanYurt") as Node3D
	if clean_yurt != null:
		clean_yurt.scale = Vector3(yurt_scale_xz, 1.0, yurt_scale_xz)

	var floor_rich := scene.get_node_or_null("YurtFloorRich") as Node3D
	if floor_rich != null:
		floor_rich.scale = Vector3(yurt_scale_xz, 1.0, yurt_scale_xz)

	var collision_root := scene.get_node_or_null("YurtCollision") as Node3D
	if collision_root != null:
		collision_root.scale = Vector3(yurt_scale_xz, 1.0, yurt_scale_xz)


func _apply_yurt_wall_material(scene: Node) -> void:
	var yurt_world := scene.get_node_or_null("CleanYurt/world")
	if yurt_world == null:
		return

	_apply_wall_material_recursive(yurt_world)


func _apply_yurt_ceiling_material(scene: Node) -> void:
	var yurt_world := scene.get_node_or_null("CleanYurt/world")
	if yurt_world == null:
		return
	_apply_ceiling_material_recursive(yurt_world)


func _apply_ceiling_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var name := String(mesh_instance.name)
		if _is_yurt_roof_mesh_name(name):
			mesh_instance.set_surface_override_material(0, YURT_CEILING_MATERIAL)
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_ceiling_material_recursive(child)


func _apply_wall_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var name := String(mesh_instance.name)
		if _is_yurt_wall_mesh_name(name):
			mesh_instance.set_surface_override_material(0, YURT_WALL_MATERIAL)
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_wall_material_recursive(child)


func _project_clean_yurt_uvs(scene: Node) -> void:
	var yurt_world := scene.get_node_or_null("CleanYurt/world")
	if yurt_world == null:
		return
	_project_clean_yurt_uvs_recursive(yurt_world)


func _project_clean_yurt_uvs_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var name := String(mesh_instance.name)
		if _is_yurt_wall_mesh_name(name):
			_replace_mesh_with_projected_uvs(mesh_instance, false)
		elif _is_yurt_roof_mesh_name(name):
			_replace_mesh_with_projected_uvs(mesh_instance, true)
	for child in node.get_children():
		_project_clean_yurt_uvs_recursive(child)


func _replace_mesh_with_projected_uvs(mesh_instance: MeshInstance3D, is_roof: bool) -> void:
	var source_mesh := mesh_instance.mesh
	if source_mesh == null:
		return

	var projected_mesh := ArrayMesh.new()
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays := source_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var shaped_vertices := _widen_roof_opening_vertices(mesh_instance, vertices) if is_roof and widen_shanyrak_enabled else vertices
		var uvs := _make_projected_uvs(mesh_instance, shaped_vertices, is_roof)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if indices.is_empty():
			for vertex_index in range(shaped_vertices.size()):
				_add_projected_vertex(surface_tool, shaped_vertices, uvs, vertex_index)
		else:
			for vertex_index in indices:
				_add_projected_vertex(surface_tool, shaped_vertices, uvs, vertex_index)
		surface_tool.generate_normals()
		surface_tool.commit(projected_mesh)
		var material := source_mesh.surface_get_material(surface_index)
		if material != null and projected_mesh.get_surface_count() > 0:
			projected_mesh.surface_set_material(projected_mesh.get_surface_count() - 1, material)

	if projected_mesh.get_surface_count() == 0:
		return
	mesh_instance.mesh = projected_mesh


func _widen_roof_opening_vertices(mesh_instance: MeshInstance3D, vertices: PackedVector3Array) -> PackedVector3Array:
	var shaped := PackedVector3Array()
	shaped.resize(vertices.size())
	for index in range(vertices.size()):
		var world_vertex := mesh_instance.to_global(vertices[index])
		var flat := Vector2(world_vertex.x, world_vertex.z)
		var radius := flat.length()
		if radius > 0.001 and radius < shanyrak_open_radius + shanyrak_open_blend_radius:
			var target_radius := maxf(radius, shanyrak_open_radius)
			var blend := 1.0 - smoothstep(shanyrak_open_radius, shanyrak_open_radius + shanyrak_open_blend_radius, radius)
			var new_radius := lerpf(radius, target_radius, blend)
			var direction := flat / radius
			world_vertex.x = direction.x * new_radius
			world_vertex.z = direction.y * new_radius
		shaped[index] = mesh_instance.to_local(world_vertex)
	return shaped


func _add_projected_vertex(surface_tool: SurfaceTool, vertices: PackedVector3Array, uvs: PackedVector2Array, vertex_index: int) -> void:
	surface_tool.set_uv(uvs[vertex_index])
	surface_tool.add_vertex(vertices[vertex_index])


func _make_projected_uvs(mesh_instance: MeshInstance3D, vertices: PackedVector3Array, is_roof: bool) -> PackedVector2Array:
	var world_vertices := PackedVector3Array()
	world_vertices.resize(vertices.size())
	var center := Vector3.ZERO
	for index in range(vertices.size()):
		var world_vertex := mesh_instance.to_global(vertices[index])
		world_vertices[index] = world_vertex
		center += world_vertex
	center /= float(vertices.size())

	var radial := Vector3(center.x, 0.0, center.z)
	if radial.length_squared() < 0.0001:
		radial = Vector3.FORWARD
	else:
		radial = radial.normalized()
	var tangent := Vector3(-radial.z, 0.0, radial.x).normalized()
	var repeats := roof_uv_repeats_per_meter if is_roof else wall_uv_repeats_per_meter

	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	for index in range(world_vertices.size()):
		var world_vertex := world_vertices[index]
		var u := world_vertex.dot(tangent) * repeats.x
		var v: float
		if is_roof:
			var slope_position := world_vertex.dot(radial) * 0.78 + world_vertex.y * 0.48
			v = slope_position * repeats.y
		else:
			v = world_vertex.y * repeats.y
		uvs[index] = Vector2(u, v)
	return uvs


func _is_yurt_wall_mesh_name(mesh_name: String) -> bool:
	return mesh_name.begins_with("YurtWall_") or (mesh_name.contains("Wall") and not mesh_name.contains("Roof"))


func _is_yurt_roof_mesh_name(mesh_name: String) -> bool:
	return mesh_name.begins_with("YurtRoof_") or mesh_name.begins_with("YurtRoofSegment_")


func _widen_shanyrak(scene: Node) -> void:
	if not widen_shanyrak_enabled:
		return
	var yurt_world := scene.get_node_or_null("CleanYurt/world")
	if yurt_world == null:
		return

	for child in yurt_world.get_children():
		var node := child as Node3D
		if node == null:
			continue
		var node_name := String(node.name)
		if node_name == "LargeOpenShanyrakRing":
			node.scale.x *= 1.34
			node.scale.z *= 1.34
			node.position.y += 0.08
		elif node_name.begins_with("RoofRadialBeam_"):
			var flat := Vector2(node.position.x, node.position.z)
			if flat.length() > 0.001:
				var widened := flat.normalized() * (flat.length() + 0.34)
				node.position.x = widened.x
				node.position.z = widened.y
			node.scale.z *= 0.88
			node.position.y += 0.04
		elif node_name.begins_with("ShanyrakCrossbar_"):
			var suffix := int(node_name.get_slice("_", 1))
			if suffix % 8 != 0:
				node.visible = false
			else:
				node.scale.x *= 1.22
				node.scale.z *= 1.22
				node.position.y += 0.1


func _fix_window_after_yurt_scale(scene: Node) -> void:
	var window_vision := scene.get_node_or_null("YurtWindowVision") as Node3D
	if window_vision == null:
		return

	var scaled_window := Vector3(8.9 * yurt_scale_xz, 2.65, 0.8 * yurt_scale_xz)
	var scaled_trigger := Vector3(6.9 * yurt_scale_xz, 1.1, 0.8 * yurt_scale_xz)
	window_vision.set("window_position", scaled_window)
	window_vision.set("trigger_position", scaled_trigger)

	var frame := window_vision.get_node_or_null("RoundWindowHole") as Node3D
	if frame != null:
		frame.global_position = scaled_window
	var area := window_vision.get_node_or_null("YurtWindowVisionTrigger") as Area3D
	if area != null:
		area.global_position = scaled_trigger
	var light := window_vision.get_node_or_null("RoundWindowOutsideLight") as OmniLight3D
	if light != null:
		light.global_position = scaled_window + Vector3(-0.65, -0.2, 0.0)
		light.light_energy = 0.45
		light.omni_range = 4.5

	if window_vision.has_method("_apply_round_window_cutout"):
		window_vision.call("_apply_round_window_cutout")


func _build_yurt_interior_lights(scene: Node) -> void:
	# A restrained key/fill setup keeps the felt readable and avoids several
	# full-room lights accumulating over every carpet pixel.
	_add_spot_light("Phase2ShanyrakSunShaft", Vector3(0.0, 8.9, 0.0), Vector3(-90.0, 0.0, 0.0), Color(0.84, 0.88, 0.86, 1.0), 4.2, 13.0, 36.0)
	_add_omni_light("Phase2DoorWarmSpill", Vector3(0.0, 2.25, -8.35), Color(1.0, 0.68, 0.38, 1.0), 1.15, 6.5)
	_add_omni_light("Phase2WindowWarmSpill", Vector3(8.15 * yurt_scale_xz, 2.35, 0.85 * yurt_scale_xz), Color(0.72, 0.82, 0.90, 1.0), 0.65, 5.5)


func _add_spot_light(node_name: String, position: Vector3, rotation_degrees_value: Vector3, color: Color, energy: float, range_value: float, angle: float) -> void:
	var light := SpotLight3D.new()
	light.name = node_name
	light.position = position
	light.rotation_degrees = rotation_degrees_value
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_value
	light.spot_angle = angle
	light.spot_attenuation = 1.15
	light.shadow_enabled = false
	_root.add_child(light)


func _add_omni_light(node_name: String, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	_root.add_child(light)


func _build_floor_textile_composition() -> void:
	# YurtFloorRich already owns the large carpet composition. Keep only a few
	# lived-in accents here instead of rendering another stack of overlapping rugs.
	_textiles.add_irregular_hide(_root, "RoughWoolHideNearBed", Vector3(4.65, 0.105, 1.3), Vector2(1.85, 1.12), MAT_WOOL, deg_to_rad(-28.0), 55)
	_textiles.add_folded_stack(_root, "FoldedWoolBoucleBundleA", Vector3(2.1, 0.16, 2.9), MAT_WOOL, deg_to_rad(-18.0), 3)

	if textile_density_level >= 2:
		_textiles.add_draped_rect(_root, "SmallVelourThresholdLayer", Vector3(0.1, 0.1, -5.85), Vector2(2.35, 1.05), MAT_VELVET, deg_to_rad(-4.0), 0.045, 0.06, 0.025, 71)
	if textile_density_level >= 3 and use_ultra_textile_quality:
		_textiles.add_folded_stack(_root, "FoldedVelvetBundleB", Vector3(-4.35, 0.14, 3.0), MAT_VELVET, deg_to_rad(18.0), 2)


func _build_low_table() -> void:
	if not add_low_table_enabled:
		return
	_textiles.add_low_table(_root, "Phase2LowSeatedTableForThree", Vector3(-1.25, 0.05, -2.55), deg_to_rad(5.0), _wood_material, MAT_JACQUARD)


func _build_wall_flags() -> void:
	var positions := [
		Vector3(3.7, 2.62, -8.85),
		Vector3(2.72, 2.48, -9.18),
		Vector3(1.75, 2.56, -9.42),
		Vector3(-3.75, 2.5, -8.78),
		Vector3(-4.74, 2.42, -8.35)
	]
	for index in range(positions.size()):
		_textiles.add_flag(_root, "WafflePiqueWallFlag_%02d" % index, positions[index], deg_to_rad(180.0 + float(index - 2) * 4.0), MAT_WAFFLE, index)


func _build_interior_props(scene: Node) -> void:
	if replace_media_props_enabled:
		var old_stand := scene.get_node_or_null("SignalCenterStand") as Node3D
		if old_stand != null:
			old_stand.visible = false
		var media_table_yaw := deg_to_rad(131.0)
		var tv_yaw := media_table_yaw
		var media_table: Node3D = _props.add_media_table(_root, Vector3(-6.45, 0.0, 5.45), media_table_yaw, _wood_material)
		var tv := scene.get_node_or_null("InteractableTV") as Node3D
		if tv != null:
			if media_table != null:
				tv.global_position = media_table.to_global(Vector3(-0.34, 0.31, 0.18))
				tv.rotation.y = tv_yaw
				tv.scale = Vector3.ONE * 3.52
			_props.replace_tv_visual(tv)
		var radio := scene.get_node_or_null("RadioOnBox") as Node3D
		if radio != null:
			if media_table != null:
				radio.global_position = media_table.to_global(Vector3(0.48, 0.33, 0.04))
				radio.rotation.y = media_table.rotation.y
				radio.scale = Vector3.ONE * 1.22
			_props.replace_radio_visual(radio)

	if add_bed_enabled:
		var bed := _props.add_bed(_root, Vector3(6.55, 0.02, 1.42), deg_to_rad(-82.0), _wood_material, MAT_TEDDY) as Node3D
		_add_bed_void_interaction(bed)
		_props.add_bull_head(_root, Vector3(5.05, 2.65, -8.6), deg_to_rad(190.0), _dark_material)

	if add_screen_enabled:
		_props.add_screen(_root, Vector3(7.25, 0.0, -1.45), deg_to_rad(-91.0), _wood_material)


func _build_exterior_props(scene: Node) -> void:
	if not add_exterior_props_enabled:
		return
	var generator_pos := _grounded_position(scene, Vector3(18.0, 0.0, 14.0), 0.02)
	var console_pos := _grounded_position(scene, Vector3(-7.95, 0.0, 2.9), 0.02)
	_props.add_exterior_generator(_root, generator_pos, deg_to_rad(-12.0), _dark_material)
	_props.add_exterior_console_table(_root, console_pos, deg_to_rad(78.0), _wood_material)
	var boulder_02_pos := _grounded_position(scene, Vector3(7.4, 0.0, -13.6), -0.08)
	var boulder_04_pos := _grounded_position(scene, Vector3(-8.6, 0.0, -11.7), -0.06)
	_props.add_boulder_02(_root, boulder_02_pos, deg_to_rad(34.0))
	_props.add_boulder_04(_root, boulder_04_pos, deg_to_rad(-28.0))


func _add_bed_void_interaction(bed: Node3D) -> void:
	if bed == null:
		return
	var area := Area3D.new()
	area.name = "BedVoidInteractionArea"
	area.monitorable = true
	area.monitoring = true
	area.set_script(BED_VOID_INTERACTABLE_SCRIPT)
	area.position = Vector3(0.0, 0.92, 0.0)
	bed.add_child(area)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(4.8, 1.4, 6.4)
	shape.shape = box
	area.add_child(shape)


func _grounded_position(scene: Node, position: Vector3, offset: float) -> Vector3:
	var steppe := scene.get_node_or_null("SteppeEnvironment")
	if steppe != null and steppe.has_method("get_walkable_ground_y"):
		var y := float(steppe.call("get_walkable_ground_y", position.x, position.z))
		if is_finite(y):
			position.y = y + offset
	return position


func _make_material(name: String, color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
