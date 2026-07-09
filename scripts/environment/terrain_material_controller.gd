extends RefCounted
class_name TerrainMaterialController

const LEAF_MATERIAL: Material = preload("res://materials/polyhaven/mat_polyhaven_leaf_alpha.tres")
const ROCK_MATERIAL: Material = preload("res://materials/polyhaven/mat_polyhaven_rock_grounded.tres")
const FLOWER_MATERIAL: Material = preload("res://materials/polyhaven/mat_polyhaven_flower_soft.tres")


static func apply_grounded_tint(root: Node, role: String) -> void:
	var material := material_for_role(role)
	if material == null:
		return
	_apply_material_recursive(root, material)


static func prepare_imported_asset_materials(root: Node, role: String) -> void:
	_prepare_imported_materials_recursive(root, role)


static func material_for_role(role: String) -> Material:
	if role in ["hero_rocks", "distant_rocks", "small_rock"]:
		return ROCK_MATERIAL
	if role in ["dry_shrub", "hero_tree", "distant_tree", "grass_multimesh"]:
		return LEAF_MATERIAL
	if role == "flower":
		return FLOWER_MATERIAL
	return null


static func set_shadow_recursive(root: Node, setting: int) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = setting
	for child in root.get_children():
		set_shadow_recursive(child, setting)


static func _apply_material_recursive(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var surface_count := 1
		if mesh_instance.mesh != null:
			surface_count = max(1, mesh_instance.mesh.get_surface_count())
		for surface in range(surface_count):
			mesh_instance.set_surface_override_material(surface, material)
	for child in root.get_children():
		_apply_material_recursive(child, material)


static func _prepare_imported_materials_recursive(root: Node, role: String) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var surface_count := 0
		if mesh_instance.mesh != null:
			surface_count = mesh_instance.mesh.get_surface_count()
		for surface in range(surface_count):
			var material := mesh_instance.get_surface_override_material(surface)
			if material == null and mesh_instance.mesh != null:
				material = mesh_instance.mesh.surface_get_material(surface)
			var prepared := _prepared_imported_material(material, role)
			if prepared != null:
				mesh_instance.set_surface_override_material(surface, prepared)
	for child in root.get_children():
		_prepare_imported_materials_recursive(child, role)


static func _prepared_imported_material(material: Material, role: String) -> Material:
	if material == null:
		return material_for_role(role)

	var duplicate := material.duplicate()
	if duplicate is BaseMaterial3D:
		var base := duplicate as BaseMaterial3D
		base.cull_mode = BaseMaterial3D.CULL_DISABLED
		base.roughness = 0.96
		if role in ["dry_shrub", "hero_tree", "distant_tree"]:
			base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			base.alpha_scissor_threshold = 0.24
			base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		elif role in ["hero_rocks", "distant_rocks", "small_rock"]:
			base.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return duplicate
