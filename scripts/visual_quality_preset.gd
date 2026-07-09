extends Node

@export var low_end: bool = false
@export var enable_ssao: bool = true
@export var enable_ssil: bool = true
@export var enable_glow: bool = true
@export var enable_volumetric_fog: bool = false
@export var enable_taa: bool = false
@export var enable_scene_details: bool = true

@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var directional_light_path: NodePath = NodePath("../DirectionalLight3D")
@export var room_fill_light_path: NodePath = NodePath("../RoomFillLight")

const TONE_MAPPER_ACES := 3
const GLOW_BLEND_MODE_SOFTLIGHT := 1

const PALETTE_DUSTY_GRAY := Color(0.37, 0.36, 0.33, 1.0)
const PALETTE_DIRTY_BEIGE := Color(0.56, 0.49, 0.38, 1.0)
const PALETTE_COLD_BLUE := Color(0.30, 0.38, 0.44, 1.0)
const PALETTE_DIM_YELLOW := Color(0.75, 0.62, 0.36, 1.0)
const PALETTE_WARNING_RED := Color(0.54, 0.12, 0.10, 1.0)

const SOFT_INTERIOR_HAZE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 haze_color : source_color = vec4(0.48, 0.44, 0.36, 0.08);
uniform float alpha_strength : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.02, 0.45) = 0.24;
uniform float streak_density : hint_range(1.0, 18.0) = 7.0;
uniform float drift_speed : hint_range(0.0, 0.35) = 0.035;
uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.23, 289.17))) * 23143.753);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float t = TIME * drift_speed + phase;
	vec2 centered = UV - vec2(0.5);

	float edge_x = smoothstep(0.0, edge_softness, UV.x) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, UV.x));
	float edge_y = smoothstep(0.0, edge_softness, UV.y) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, UV.y));
	float edge = edge_x * edge_y;
	float oval = 1.0 - smoothstep(0.34, 0.78, length(centered * vec2(1.0, 1.75)));

	float n = noise2(UV * vec2(3.4, 8.5) + vec2(t * 0.45, -t * 0.18));
	float long_band = sin((UV.x * 0.55 + UV.y * 1.65) * streak_density + t * 3.0 + n * 1.7) * 0.5 + 0.5;
	float fine_band = noise2(UV * vec2(11.0, 2.2) + vec2(-t, t * 0.35));
	float dust = smoothstep(0.18, 0.82, long_band) * mix(0.45, 1.0, fine_band);
	float mask = max(edge * dust * 0.72, oval * 0.38) * edge;

	ALBEDO = haze_color.rgb;
	ALPHA = clamp(haze_color.a * alpha_strength * mask, 0.0, 0.42);
}
"""

var _soft_haze_shader: Shader


func _ready() -> void:
	_apply_environment_preset()
	_apply_light_preset()
	if enable_taa:
		_apply_optional_taa()
	if enable_scene_details:
		_build_scene_details.call_deferred()


func _apply_environment_preset() -> void:
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return

	var environment := world_environment.environment
	_set_if_available(environment, "tonemap_mode", TONE_MAPPER_ACES)
	_set_if_available(environment, "tonemap_exposure", 0.98)
	_set_if_available(environment, "tonemap_white", 1.12)

	_set_if_available(environment, "ambient_light_color", Color(0.58, 0.55, 0.48, 1.0))
	_set_if_available(environment, "ambient_light_energy", 0.68)
	_set_if_available(environment, "fog_enabled", true)
	_set_if_available(environment, "fog_light_color", Color(0.43, 0.41, 0.36, 1.0))
	_set_if_available(environment, "fog_density", 0.0036)
	_set_if_available(environment, "fog_sky_affect", 0.42)

	_set_if_available(environment, "adjustment_enabled", true)
	_set_if_available(environment, "adjustment_contrast", 1.08)
	_set_if_available(environment, "adjustment_saturation", 0.88)
	# Godot uses brightness as a multiplier around 1.0; negative values crush the scene to black.
	_set_if_available(environment, "adjustment_brightness", 0.98)

	var heavy_effects_enabled := not low_end
	_set_if_available(environment, "ssao_enabled", enable_ssao and heavy_effects_enabled)
	_set_if_available(environment, "ssao_radius", 2.25)
	_set_if_available(environment, "ssao_intensity", 0.72)
	_set_if_available(environment, "ssao_power", 1.12)
	_set_if_available(environment, "ssao_detail", 0.42)
	_set_if_available(environment, "ssao_horizon", 0.04)
	_set_if_available(environment, "ssao_sharpness", 0.92)
	_set_if_available(environment, "ssao_light_affect", 0.18)

	_set_if_available(environment, "ssil_enabled", enable_ssil and heavy_effects_enabled)
	_set_if_available(environment, "ssil_radius", 1.65)
	_set_if_available(environment, "ssil_intensity", 0.18)
	_set_if_available(environment, "ssil_sharpness", 0.55)
	_set_if_available(environment, "ssil_normal_rejection", 1.0)

	_set_if_available(environment, "glow_enabled", enable_glow)
	_set_if_available(environment, "glow_normalized", true)
	_set_if_available(environment, "glow_intensity", 0.18)
	_set_if_available(environment, "glow_strength", 0.42)
	_set_if_available(environment, "glow_bloom", 0.04)
	_set_if_available(environment, "glow_blend_mode", GLOW_BLEND_MODE_SOFTLIGHT)
	_set_if_available(environment, "glow_hdr_threshold", 1.15)
	_set_if_available(environment, "glow_hdr_scale", 0.82)

	_set_if_available(environment, "volumetric_fog_enabled", enable_volumetric_fog and heavy_effects_enabled)
	_set_if_available(environment, "volumetric_fog_density", 0.004)
	_set_if_available(environment, "volumetric_fog_albedo", Color(0.52, 0.50, 0.43, 1.0))
	_set_if_available(environment, "volumetric_fog_emission", Color(0.08, 0.09, 0.09, 1.0))
	_set_if_available(environment, "volumetric_fog_emission_energy", 0.045)
	_set_if_available(environment, "volumetric_fog_length", 36.0)
	_set_if_available(environment, "volumetric_fog_detail_spread", 1.75)
	_set_if_available(environment, "volumetric_fog_gi_inject", 0.08)


func _apply_light_preset() -> void:
	var directional_light := get_node_or_null(directional_light_path) as Light3D
	if directional_light != null:
		_set_if_available(directional_light, "light_energy", 1.45)
		_set_if_available(directional_light, "light_color", Color(0.78, 0.74, 0.64, 1.0))
		_set_if_available(directional_light, "shadow_enabled", true)
		_set_if_available(directional_light, "shadow_blur", 5.0)
		_set_if_available(directional_light, "shadow_opacity", 0.38)
		_set_if_available(directional_light, "directional_shadow_blend_splits", true)
		_set_if_available(directional_light, "directional_shadow_max_distance", 64.0)

	var room_fill_light := get_node_or_null(room_fill_light_path) as OmniLight3D
	if room_fill_light != null:
		_set_if_available(room_fill_light, "light_energy", 1.85)
		_set_if_available(room_fill_light, "omni_range", 17.0)
		_set_if_available(room_fill_light, "light_color", Color(0.70, 0.64, 0.52, 1.0))
		_set_if_available(room_fill_light, "shadow_enabled", false)


func _apply_optional_taa() -> void:
	var viewport := get_viewport()
	_set_if_available(viewport, "use_taa", true)


func _build_scene_details() -> void:
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		return

	var old_root := scene.get_node_or_null("VisualAtmosphereDetails")
	if old_root != null:
		old_root.queue_free()

	var root := Node3D.new()
	root.name = "VisualAtmosphereDetails"
	scene.add_child(root)

	_build_yurt_dust(root)
	_build_floor_debris(root)
	_build_distant_silhouettes(root)
	_build_warning_color_accents(root)


func _build_yurt_dust(parent: Node3D) -> void:
	var dust_root := Node3D.new()
	dust_root.name = "InteriorDustSheets"
	parent.add_child(dust_root)

	var specs := [
		{"pos": Vector3(-4.8, 1.65, -3.2), "size": Vector2(3.2, 0.95), "rot": Vector3(0.0, 24.0, -4.0), "alpha": 0.62},
		{"pos": Vector3(3.9, 1.95, -2.1), "size": Vector2(3.8, 1.05), "rot": Vector3(0.0, -31.0, 3.0), "alpha": 0.56},
		{"pos": Vector3(-1.0, 2.28, 1.7), "size": Vector2(4.6, 0.9), "rot": Vector3(0.0, 8.0, -2.0), "alpha": 0.50},
		{"pos": Vector3(5.8, 1.45, 2.2), "size": Vector2(2.5, 0.78), "rot": Vector3(0.0, 66.0, 5.0), "alpha": 0.48}
	]

	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var sheet := MeshInstance3D.new()
		sheet.name = "DustSheet_%02d" % index
		var mesh := QuadMesh.new()
		mesh.size = spec["size"]
		sheet.mesh = mesh
		sheet.position = spec["pos"]
		sheet.rotation_degrees = spec["rot"]
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := _make_soft_haze_material(
			"mat_interior_dust_sheet_%02d" % index,
			Color(0.50, 0.46, 0.38, 0.09),
			float(index) * 1.73,
			spec["alpha"]
		)
		sheet.set_surface_override_material(0, material)
		dust_root.add_child(sheet)


func _build_floor_debris(parent: Node3D) -> void:
	var debris_root := Node3D.new()
	debris_root.name = "FloorDebrisAndSteppeScrub"
	parent.add_child(debris_root)

	var rock_material := _make_lit_material("mat_debris_dusty_rock", PALETTE_DUSTY_GRAY)
	var straw_material := _make_lit_material("mat_debris_dry_straw", PALETTE_DIRTY_BEIGE)
	var specs := [
		{"pos": Vector3(-6.1, 0.07, 2.8), "size": Vector3(0.34, 0.07, 0.22), "rot": 18.0, "mat": rock_material},
		{"pos": Vector3(-5.4, 0.06, -4.5), "size": Vector3(0.22, 0.05, 0.36), "rot": -37.0, "mat": rock_material},
		{"pos": Vector3(5.2, 0.06, -5.6), "size": Vector3(0.42, 0.045, 0.16), "rot": 61.0, "mat": straw_material},
		{"pos": Vector3(6.6, 0.055, 2.9), "size": Vector3(0.27, 0.05, 0.27), "rot": -16.0, "mat": rock_material},
		{"pos": Vector3(-2.6, 0.058, 5.7), "size": Vector3(0.55, 0.035, 0.13), "rot": 7.0, "mat": straw_material},
		{"pos": Vector3(3.4, 0.062, 5.1), "size": Vector3(0.24, 0.055, 0.41), "rot": 44.0, "mat": rock_material}
	]

	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var debris := MeshInstance3D.new()
		debris.name = "FloorDebris_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = spec["size"]
		debris.mesh = mesh
		debris.position = spec["pos"]
		debris.rotation_degrees.y = spec["rot"]
		debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		debris.set_surface_override_material(0, spec["mat"])
		debris_root.add_child(debris)


func _build_distant_silhouettes(parent: Node3D) -> void:
	var silhouette_root := Node3D.new()
	silhouette_root.name = "DistantSteppeSilhouettes"
	parent.add_child(silhouette_root)

	var material := _make_unshaded_alpha_material("mat_distant_steppe_silhouettes", Color(0.06, 0.065, 0.06, 0.78))
	var specs := [
		{"pos": Vector3(62.0, 5.8, -118.0), "size": Vector3(4.8, 11.6, 0.38), "rot": -15.0},
		{"pos": Vector3(-76.0, 4.6, -96.0), "size": Vector3(6.6, 9.2, 0.36), "rot": 19.0},
		{"pos": Vector3(104.0, 3.8, 34.0), "size": Vector3(5.2, 7.6, 0.34), "rot": 72.0},
		{"pos": Vector3(-118.0, 3.2, 48.0), "size": Vector3(8.0, 6.4, 0.32), "rot": -63.0}
	]

	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var silhouette := MeshInstance3D.new()
		silhouette.name = "DistantSilhouette_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = spec["size"]
		silhouette.mesh = mesh
		silhouette.position = spec["pos"]
		silhouette.rotation_degrees.y = spec["rot"]
		silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		silhouette.set_surface_override_material(0, material)
		silhouette_root.add_child(silhouette)


func _build_warning_color_accents(parent: Node3D) -> void:
	var accent_root := Node3D.new()
	accent_root.name = "MutedPaletteAccents"
	parent.add_child(accent_root)

	var cold_mat := _make_soft_haze_material("mat_cold_blue_fog_accent", Color(PALETTE_COLD_BLUE.r, PALETTE_COLD_BLUE.g, PALETTE_COLD_BLUE.b, 0.075), 9.4, 0.58)
	var red_mat := _make_unshaded_alpha_material("mat_warning_red_thread_accent", Color(PALETTE_WARNING_RED.r, PALETTE_WARNING_RED.g, PALETTE_WARNING_RED.b, 0.38))

	var cold_card := MeshInstance3D.new()
	cold_card.name = "ColdBlueEntranceHaze"
	var cold_mesh := QuadMesh.new()
	cold_mesh.size = Vector2(3.8, 1.75)
	cold_card.mesh = cold_mesh
	cold_card.position = Vector3(0.0, 1.78, -8.45)
	cold_card.rotation_degrees.y = 180.0
	cold_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cold_card.set_surface_override_material(0, cold_mat)
	accent_root.add_child(cold_card)

	var red_thread := MeshInstance3D.new()
	red_thread.name = "DullRedFloorThread"
	var red_mesh := BoxMesh.new()
	red_mesh.size = Vector3(0.035, 0.018, 3.3)
	red_thread.mesh = red_mesh
	red_thread.position = Vector3(-4.9, 0.065, -1.4)
	red_thread.rotation_degrees.y = 16.0
	red_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	red_thread.set_surface_override_material(0, red_mat)
	accent_root.add_child(red_thread)


func _make_lit_material(resource_name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = resource_name
	material.albedo_color = color
	material.roughness = 0.96
	material.metallic = 0.0
	return material


func _make_unshaded_alpha_material(resource_name: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = resource_name
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


func _make_soft_haze_material(resource_name: String, color: Color, phase: float, alpha_strength: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = resource_name
	material.shader = _get_soft_haze_shader()
	material.render_priority = -3
	material.set_shader_parameter("haze_color", color)
	material.set_shader_parameter("alpha_strength", alpha_strength)
	material.set_shader_parameter("edge_softness", 0.28)
	material.set_shader_parameter("streak_density", 7.0)
	material.set_shader_parameter("drift_speed", 0.028)
	material.set_shader_parameter("phase", phase)
	return material


func _get_soft_haze_shader() -> Shader:
	if _soft_haze_shader == null:
		_soft_haze_shader = Shader.new()
		_soft_haze_shader.code = SOFT_INTERIOR_HAZE_SHADER_CODE
	return _soft_haze_shader


func _set_if_available(target: Object, property_name: String, value: Variant) -> void:
	if target == null or not _has_property(target, property_name):
		return
	target.set(property_name, value)


func _has_property(target: Object, property_name: String) -> bool:
	for property in target.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
