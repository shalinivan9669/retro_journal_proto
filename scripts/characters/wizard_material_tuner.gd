extends Node3D

## Local material overrides for the wizard instance.
## The imported GLB and its embedded textures remain untouched.

@export var normal_scale: float = 0.06
@export var disable_normal_for_test: bool = false


func _ready() -> void:
	_apply_local_materials()


func _apply_local_materials() -> void:
	var mesh_count := 0
	var surface_count := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_count += 1
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source_material == null:
				continue
			var local_material := source_material.duplicate(true) as BaseMaterial3D
			if local_material == null:
				continue

			# Matte textile baseline. Keep albedo and normal textures intact.
			_set_if_supported(local_material, "metallic", 0.0)
			_set_if_supported(local_material, "roughness", 0.90)
			_set_if_supported(local_material, "specular", 0.28)
			_set_if_supported(local_material, "metallic_texture", null)
			_set_if_supported(local_material, "roughness_texture", null)
			_set_if_supported(local_material, "height_enabled", false)
			_set_if_supported(local_material, "clearcoat_enabled", false)
			_set_if_supported(local_material, "anisotropy_enabled", false)
			_set_if_supported(local_material, "emission_enabled", false)
			_set_if_supported(local_material, "normal_scale", normal_scale)
			if disable_normal_for_test:
				_set_if_supported(local_material, "normal_texture", null)
			mesh_instance.set_surface_override_material(surface, local_material)
			surface_count += 1

	print("[WizardMaterial] local overrides=", surface_count, " meshes=", mesh_count, " normal_scale=", normal_scale, " normal_test_off=", disable_normal_for_test)


func _set_if_supported(material: BaseMaterial3D, property_name: String, value: Variant) -> void:
	for property in material.get_property_list():
		if str(property.get("name", "")) == property_name:
			material.set(property_name, value)
			return
