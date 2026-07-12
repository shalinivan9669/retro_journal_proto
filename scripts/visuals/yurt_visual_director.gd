extends Node

## Authoritative owner of the yurt's global image and core lighting settings.
## Gameplay, TV channels, window-vision timing, and device emission stay elsewhere.

@export_group("Scene Paths")
@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var key_light_path: NodePath = NodePath("../DirectionalLight3D")
@export var fill_light_path: NodePath = NodePath("../RoomFillLight")
@export var visual_runtime_path: NodePath = NodePath("../VisualEffectsRuntime")
@export var reflection_probe_path: NodePath

@export_group("Environment")
@export var ambient_light_color := Color(0.72, 0.64, 0.52, 1.0)
@export_range(0.0, 2.0, 0.01) var ambient_light_energy := 0.96
@export var fog_enabled := true
@export var fog_light_color := Color(0.52, 0.47, 0.38, 1.0)
@export_range(0.0, 0.1, 0.0001) var fog_density := 0.0016
@export_range(0.0, 1.0, 0.01) var fog_sky_affect := 0.28
@export var adjustment_enabled := true
@export_range(0.5, 1.5, 0.01) var adjustment_brightness := 0.98
@export_range(0.5, 2.0, 0.01) var adjustment_contrast := 1.08
@export_range(0.0, 2.0, 0.01) var adjustment_saturation := 0.88
@export var glow_enabled := true
@export_range(0.0, 1.0, 0.01) var glow_intensity := 0.18
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.42
@export_range(0.0, 0.2, 0.01) var glow_bloom := 0.04

@export_group("Key Light")
@export var key_light_color := Color(0.95, 0.82, 0.62, 1.0)
@export_range(0.0, 8.0, 0.01) var key_light_energy := 1.85
@export var key_shadow_enabled := true
@export_range(0.0, 10.0, 0.1) var key_shadow_blur := 7.0
@export_range(0.0, 1.0, 0.01) var key_shadow_opacity := 0.22
@export_range(1.0, 200.0, 1.0) var key_shadow_max_distance := 64.0

@export_group("Fill Light")
@export var fill_enabled := true
@export var fill_light_color := Color(1.0, 0.78, 0.52, 1.0)
@export_range(0.0, 8.0, 0.01) var fill_light_energy := 4.2
@export_range(0.0, 40.0, 0.1) var fill_light_range := 22.0

@export_group("TV Light")
@export var tv_light_enabled := true
@export var tv_light_color := Color(0.17, 0.78, 0.68, 1.0)
@export_range(0.0, 4.0, 0.01) var tv_light_energy := 0.55
@export_range(0.0, 12.0, 0.1) var tv_light_range := 3.0

@export_group("Reflection Probe")
@export var reflection_probe_enabled := true

@export_group("Diagnostics")
@export var debug_key_light_only := false
@export var debug_disable_fill := false
@export var debug_disable_device_lights := false
@export var debug_disable_post_effects := false


func _ready() -> void:
	_apply_environment()
	_apply_key_and_fill_lights()
	_configure_device_runtime()
	_apply_reflection_probe_state()
	_apply_device_light_state.call_deferred()


func _apply_environment() -> void:
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		push_warning("YurtVisualDirector: WorldEnvironment is missing.")
		return

	var environment := world_environment.environment
	_set_if_available(environment, "tonemap_mode", 3)
	_set_if_available(environment, "tonemap_exposure", 0.98)
	_set_if_available(environment, "tonemap_white", 1.12)
	_set_if_available(environment, "ambient_light_color", ambient_light_color)
	_set_if_available(environment, "ambient_light_energy", 0.0 if debug_key_light_only else ambient_light_energy)
	_set_if_available(environment, "fog_enabled", fog_enabled)
	_set_if_available(environment, "fog_light_color", fog_light_color)
	_set_if_available(environment, "fog_density", fog_density)
	_set_if_available(environment, "fog_sky_affect", fog_sky_affect)
	_set_if_available(environment, "adjustment_enabled", adjustment_enabled and not debug_disable_post_effects)
	_set_if_available(environment, "adjustment_brightness", adjustment_brightness)
	_set_if_available(environment, "adjustment_contrast", adjustment_contrast)
	_set_if_available(environment, "adjustment_saturation", adjustment_saturation)
	_set_if_available(environment, "glow_enabled", glow_enabled and not debug_disable_post_effects)
	_set_if_available(environment, "glow_normalized", true)
	_set_if_available(environment, "glow_intensity", glow_intensity)
	_set_if_available(environment, "glow_strength", glow_strength)
	_set_if_available(environment, "glow_bloom", glow_bloom)
	_set_if_available(environment, "glow_blend_mode", 1)
	_set_if_available(environment, "glow_hdr_threshold", 1.15)
	_set_if_available(environment, "glow_hdr_scale", 0.82)


func _apply_key_and_fill_lights() -> void:
	var key_light := get_node_or_null(key_light_path) as DirectionalLight3D
	if key_light != null:
		key_light.light_color = key_light_color
		key_light.light_energy = key_light_energy
		key_light.shadow_enabled = key_shadow_enabled
		key_light.shadow_blur = key_shadow_blur
		key_light.shadow_opacity = key_shadow_opacity
		key_light.directional_shadow_max_distance = key_shadow_max_distance

	var fill_light := get_node_or_null(fill_light_path) as OmniLight3D
	if fill_light != null:
		fill_light.visible = fill_enabled and not debug_key_light_only and not debug_disable_fill
		fill_light.light_color = fill_light_color
		fill_light.light_energy = fill_light_energy
		fill_light.omni_range = fill_light_range
		fill_light.shadow_enabled = false


func _configure_device_runtime() -> void:
	var visual_runtime := get_node_or_null(visual_runtime_path)
	if visual_runtime == null:
		return
	_set_if_available(visual_runtime, "tune_world_environment", false)
	_set_if_available(visual_runtime, "tv_light_energy", tv_light_energy if tv_light_enabled else 0.0)
	_set_if_available(visual_runtime, "tv_light_range", tv_light_range)


func _apply_device_light_state() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var disable_devices := debug_key_light_only or debug_disable_device_lights
	var tv_light := scene.find_child("TVColdScreenLight", true, false) as Light3D
	if tv_light != null:
		tv_light.light_color = tv_light_color
		tv_light.light_energy = 0.0 if disable_devices or not tv_light_enabled else tv_light_energy
		if tv_light is OmniLight3D:
			(tv_light as OmniLight3D).omni_range = tv_light_range
	var radio_light := scene.find_child("RadioAmberDisplayLight", true, false) as Light3D
	if radio_light != null and disable_devices:
		radio_light.light_energy = 0.0


func _apply_reflection_probe_state() -> void:
	if reflection_probe_path.is_empty():
		return
	var probe := get_node_or_null(reflection_probe_path) as ReflectionProbe
	if probe != null:
		probe.visible = reflection_probe_enabled


func _set_if_available(target: Object, property_name: StringName, value: Variant) -> void:
	if target == null:
		return
	for property in target.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			target.set(property_name, value)
			return
