extends Area3D

var _powered := false
var _screen_material: ShaderMaterial
var _screen_light: OmniLight3D
var _indicator: MeshInstance3D


func configure(screen_material: ShaderMaterial, screen_light: OmniLight3D, indicator: MeshInstance3D) -> void:
	_screen_material = screen_material
	_screen_light = screen_light
	_indicator = indicator
	_apply_power_state()


func interact(_dialogue_ui: Node = null) -> void:
	_powered = not _powered
	_apply_power_state()


func get_interaction_prompt() -> String:
	return "E — выключить монитор" if _powered else "E — включить монитор"


func _apply_power_state() -> void:
	var power := 1.0 if _powered else 0.0
	if _screen_material != null:
		_screen_material.set_shader_parameter("power", power)
	if _screen_light != null:
		_screen_light.light_energy = 0.72 if _powered else 0.0
	if _indicator != null:
		var material := _indicator.get_surface_override_material(0) as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 2.6 if _powered else 0.05
