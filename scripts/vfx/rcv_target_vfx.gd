extends Node3D
class_name RCVTargetVFX

## Runtime visual component for one infected/haunted object.
## Add as a child of the target object, or set target_path manually.
## Godot 4.7, Forward Plus.

enum Preset {
	BED_DREAM,
	TV_GLITCH,
	LEP_RADIATION,
	LEP_RUST,
	LEP_ION_WHITE,
	LEP_DEAD_SIGNAL
}

@export var preset: Preset = Preset.LEP_RADIATION
@export var target_path: NodePath
@export_range(0.2, 12.0, 0.1) var activation_distance: float = 3.2
@export_range(0.0, 2.0, 0.01) var screen_intensity: float = 1.0
@export_range(0.0, 4.0, 0.05) var particle_intensity: float = 1.0
@export var enable_screen_overlay: bool = true
@export var enable_particles: bool = true
@export var enable_lights: bool = true
@export var enable_corrosion_overlay: bool = true
@export var enable_debug_prints: bool = false

const BED_OVERLAY_MATERIAL_PATH := "res://materials/postprocess/mat_rcv_bed_dream_noise.tres"
const TV_GLITCH_MATERIAL_PATH := "res://materials/postprocess/mat_rcv_tv_glitch_heavy.tres"
const RADIATION_OVERLAY_MATERIAL_PATH := "res://materials/postprocess/mat_rcv_radiation_field_screen.tres"
const CORROSION_MATERIAL_PATH := "res://materials/vfx/mat_rcv_corrosion_overlay.tres"
const ION_PARTICLE_MATERIAL_PATH := "res://materials/vfx/mat_rcv_ion_particle_unshaded.tres"
const WHITE_PARTICLE_MATERIAL_PATH := "res://materials/vfx/mat_rcv_ion_particle_white.tres"
const BED_VEIL_MATERIAL_PATH := "res://materials/vfx/mat_rcv_bed_veil_sheet.tres"

var _target: Node3D
var _overlay_rect: ColorRect
var _overlay_material: ShaderMaterial
var _overlay_layer: CanvasLayer
var _particles_root: Node3D
var _last_camera: Camera3D

func _ready() -> void:
	_resolve_target()
	if _target == null:
		push_warning("RCVTargetVFX has no Node3D target. Preset will not run.")
		return

	match preset:
		Preset.BED_DREAM:
			_setup_bed_dream()
		Preset.TV_GLITCH:
			_setup_tv_glitch()
		Preset.LEP_RADIATION:
			_setup_lep_radiation()
		Preset.LEP_RUST:
			_setup_lep_rust()
		Preset.LEP_ION_WHITE:
			_setup_lep_ion_white()
		Preset.LEP_DEAD_SIGNAL:
			_setup_lep_dead_signal()

	if enable_debug_prints:
		print("RCVTargetVFX installed: ", Preset.keys()[preset], " on ", _target.name)

func _process(_delta: float) -> void:
	_update_screen_overlay()

func _resolve_target() -> void:
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target == null and get_parent() is Node3D:
		_target = get_parent() as Node3D
	if _target == null:
		_target = self

func _setup_bed_dream() -> void:
	activation_distance = maxf(activation_distance, 5.2)
	if enable_screen_overlay:
		_create_screen_overlay(BED_OVERLAY_MATERIAL_PATH, 90)
	if enable_particles:
		_add_pixel_noise_particles("BedWhiteStaticPixels", 6200, 1.18, 0.9, 0.012, 0.048, Color(0.98, 0.995, 1.0, 0.96), true)
		_add_pixel_noise_particles("BedBlackStaticPixels", 3800, 1.12, 0.8, 0.010, 0.040, Color(0.0, 0.0, 0.0, 0.82), false)
		_add_noise_cloud_particles("BedWhiteNoiseMistCloud", 1300, 1.2, 1.25, 0.035, 0.11, WHITE_PARTICLE_MATERIAL_PATH, Color(0.96, 0.985, 1.0, 0.72))
		if _particles_root != null:
			_particles_root.position = Vector3(0.0, 1.15, 0.0)
	if enable_lights:
		_add_omni_light("BedDreamColdHalo", Color(0.88, 0.94, 1.0, 1.0), 0.72, 4.2, Vector3(0.0, 1.05, 0.0))

func _setup_tv_glitch() -> void:
	activation_distance = maxf(activation_distance, 2.4)
	if enable_screen_overlay:
		_create_screen_overlay(TV_GLITCH_MATERIAL_PATH, 100)
	if enable_particles:
		_add_soft_particles("TVStaticSparks", 42, 0.42, 0.9, 0.012, 0.038, WHITE_PARTICLE_MATERIAL_PATH, Color(0.66, 1.0, 0.86, 0.38))
	if enable_lights:
		_add_omni_light("TVGlitchColdFlicker", Color(0.32, 0.95, 0.82, 1.0), 0.34, 2.1, Vector3(0.0, 0.25, 0.0))

func _setup_lep_radiation() -> void:
	activation_distance = maxf(activation_distance, 10.5)
	if enable_screen_overlay:
		_create_screen_overlay(RADIATION_OVERLAY_MATERIAL_PATH, 95)
	if enable_particles:
		_add_radial_particles("LEPRadialIonFallout", 920, 4.0, 1.45, 0.018, 0.11, ION_PARTICLE_MATERIAL_PATH, Color(1.0, 0.74, 0.28, 0.82))
		_add_radial_particles("LEPWhiteStaticRadiationNoise", 1280, 4.8, 1.12, 0.018, 0.13, WHITE_PARTICLE_MATERIAL_PATH, Color(0.96, 0.99, 1.0, 0.88))
	if enable_corrosion_overlay:
		_apply_corrosion_to_meshes(0.56, Color(0.52, 0.20, 0.055, 1.0), 0.20)
	if enable_lights:
		_add_omni_light("LEPRadiationDirtyAmber", Color(1.0, 0.66, 0.26, 1.0), 0.86, 7.2, Vector3(0.0, 2.2, 0.0))

func _setup_lep_rust() -> void:
	activation_distance = maxf(activation_distance, 5.6)
	if enable_particles:
		_add_radial_particles("LEPRustAshDust", 560, 3.0, 1.8, 0.018, 0.09, ION_PARTICLE_MATERIAL_PATH, Color(0.72, 0.32, 0.12, 0.58))
	if enable_corrosion_overlay:
		_apply_corrosion_to_meshes(0.72, Color(0.36, 0.13, 0.04, 1.0), 0.035)
	if enable_lights:
		_add_omni_light("LEPRustLowSodiumLeak", Color(0.95, 0.42, 0.12, 1.0), 0.16, 3.8, Vector3(0.0, 1.0, 0.0))

func _setup_lep_ion_white() -> void:
	activation_distance = maxf(activation_distance, 7.8)
	if enable_particles:
		_add_radial_particles("LEPWhiteIonAsh", 980, 3.8, 1.35, 0.016, 0.105, WHITE_PARTICLE_MATERIAL_PATH, Color(0.94, 0.98, 1.0, 0.82))
		_add_noise_cloud_particles("LEPDeadWhiteDustCloud", 520, 3.2, 2.1, 0.035, 0.13, WHITE_PARTICLE_MATERIAL_PATH, Color(0.90, 0.96, 1.0, 0.58))
	if enable_corrosion_overlay:
		_apply_corrosion_to_meshes(0.26, Color(0.68, 0.64, 0.54, 1.0), 0.10)
	if enable_lights:
		_add_omni_light("LEPWhiteIonDeadHalo", Color(0.72, 0.82, 1.0, 1.0), 0.22, 4.6, Vector3(0.0, 1.2, 0.0))

func _setup_lep_dead_signal() -> void:
	activation_distance = maxf(activation_distance, 4.8)
	if enable_screen_overlay:
		_create_screen_overlay(TV_GLITCH_MATERIAL_PATH, 92)
	if enable_particles:
		_add_radial_particles("LEPDeadSignalNeedles", 90, 1.4, 2.3, 0.008, 0.032, WHITE_PARTICLE_MATERIAL_PATH, Color(1.0, 1.0, 0.92, 0.30))
	if enable_corrosion_overlay:
		_apply_corrosion_to_meshes(0.38, Color(0.16, 0.16, 0.14, 1.0), 0.16)

func _create_screen_overlay(material_path: String, layer_index: int) -> void:
	if not ResourceLoader.exists(material_path):
		push_warning("RCV overlay material not found: " + material_path)
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "RCVScreenOverlayLayer"
	_overlay_layer.layer = layer_index
	add_child(_overlay_layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "RCVScreenOverlay"
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.offset_left = 0.0
	_overlay_rect.offset_top = 0.0
	_overlay_rect.offset_right = 0.0
	_overlay_rect.offset_bottom = 0.0
	_overlay_material = (load(material_path) as ShaderMaterial).duplicate() as ShaderMaterial
	_overlay_rect.material = _overlay_material
	_overlay_rect.visible = false
	_overlay_layer.add_child(_overlay_rect)

func _update_screen_overlay() -> void:
	if _overlay_rect == null or _target == null:
		return
	var camera := _find_active_camera(get_tree().current_scene)
	if camera == null:
		_overlay_rect.visible = false
		return

	_last_camera = camera
	var distance := camera.global_position.distance_to(_target.global_position)
	var amount := clampf(1.0 - (distance / maxf(activation_distance, 0.1)), 0.0, 1.0)
	amount = amount * amount
	_overlay_rect.visible = amount > 0.015
	if _overlay_material != null:
		if _has_shader_parameter(_overlay_material, "opacity"):
			_overlay_material.set_shader_parameter("opacity", amount * screen_intensity)
		if _has_shader_parameter(_overlay_material, "radial_strength"):
			_overlay_material.set_shader_parameter("radial_strength", amount * screen_intensity * 0.95)
		if _has_shader_parameter(_overlay_material, "center"):
			var screen_pos := camera.unproject_position(_target.global_position)
			var viewport_size := get_viewport().get_visible_rect().size
			if viewport_size.x > 1.0 and viewport_size.y > 1.0:
				_overlay_material.set_shader_parameter("center", screen_pos / viewport_size)

func _add_radial_particles(particle_name: String, amount: int, radius: float, lifetime: float, size_min: float, size_max: float, material_path: String, fallback_color: Color) -> void:
	var particles := _make_particles_base(particle_name, amount, radius, lifetime, size_min, size_max, material_path, fallback_color)
	if particles == null:
		return
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.initial_velocity_min = 0.75
	process.initial_velocity_max = 5.2 * particle_intensity
	process.radial_velocity_min = 1.45
	process.radial_velocity_max = 5.8 * particle_intensity
	process.damping_min = 0.0
	process.damping_max = 0.08
	_apply_particle_turbulence(process, 1.0, 4.0)
	particles.emitting = true

func _add_noise_cloud_particles(particle_name: String, amount: int, radius: float, lifetime: float, size_min: float, size_max: float, material_path: String, fallback_color: Color) -> void:
	var particles := _make_particles_base(particle_name, amount, radius, lifetime, size_min, size_max, material_path, fallback_color)
	if particles == null:
		return
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.012, 0.0)
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 1.55 * particle_intensity
	process.radial_velocity_min = -0.65 * particle_intensity
	process.radial_velocity_max = 1.85 * particle_intensity
	process.damping_min = 0.0
	process.damping_max = 0.12
	_apply_particle_turbulence(process, 1.0, 6.0)
	particles.emitting = true

func _add_pixel_noise_particles(particle_name: String, amount: int, radius: float, lifetime: float, size_min: float, size_max: float, color: Color, emissive: bool) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "mat_%s" % particle_name
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.65

	var particles := _make_particles_base(particle_name, amount, radius, lifetime, size_min, size_max, "", color, material)
	if particles == null:
		return
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.22 * particle_intensity
	process.radial_velocity_min = -0.08 * particle_intensity
	process.radial_velocity_max = 0.12 * particle_intensity
	process.damping_min = 0.55
	process.damping_max = 0.95
	_apply_particle_turbulence(process, 0.35, 2.2)
	particles.emitting = true

func _add_soft_particles(particle_name: String, amount: int, radius: float, lifetime: float, size_min: float, size_max: float, material_path: String, fallback_color: Color) -> void:
	var particles := _make_particles_base(particle_name, amount, radius, lifetime, size_min, size_max, material_path, fallback_color)
	if particles == null:
		return
	var process := particles.process_material as ParticleProcessMaterial
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.82 * particle_intensity
	process.radial_velocity_min = 0.18
	process.radial_velocity_max = 0.92 * particle_intensity
	process.damping_min = 0.02
	process.damping_max = 0.18
	_apply_particle_turbulence(process, 0.7, 3.2)
	particles.emitting = true

func _apply_particle_turbulence(process: ParticleProcessMaterial, influence: float, strength: float) -> void:
	_safe_set(process, "turbulence_enabled", true)
	_safe_set(process, "turbulence_influence_min", influence * 0.45)
	_safe_set(process, "turbulence_influence_max", influence)
	_safe_set(process, "turbulence_noise_strength", strength)
	_safe_set(process, "turbulence_noise_scale", 4.0)
	_safe_set(process, "turbulence_noise_speed", Vector3(2.8, 4.2, 3.4))

func _make_particles_base(particle_name: String, amount: int, radius: float, lifetime: float, size_min: float, size_max: float, material_path: String, fallback_color: Color, override_material: Material = null) -> GPUParticles3D:
	if not enable_particles:
		return null

	if _particles_root == null:
		_particles_root = Node3D.new()
		_particles_root.name = "RCVParticlesRoot"
		add_child(_particles_root)

	var particles := GPUParticles3D.new()
	particles.name = particle_name
	particles.amount = maxi(1, int(round(float(amount) * particle_intensity)))
	particles.lifetime = lifetime
	particles.preprocess = minf(lifetime * 0.65, 2.0)
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-radius * 2.0, -radius * 2.0, -radius * 2.0), Vector3(radius * 4.0, radius * 4.0, radius * 4.0))

	var quad := QuadMesh.new()
	quad.size = Vector2(size_min, size_min)
	var material: Material = override_material
	if material != null:
		pass
	elif ResourceLoader.exists(material_path):
		material = load(material_path) as Material
	else:
		var standard := StandardMaterial3D.new()
		standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		standard.albedo_color = fallback_color
		standard.emission_enabled = true
		standard.emission = fallback_color
		standard.emission_energy_multiplier = 1.0
		standard.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material = standard
	quad.material = material
	particles.draw_pass_1 = quad

	var process := ParticleProcessMaterial.new()
	process.color = fallback_color
	process.scale_min = size_min
	process.scale_max = size_max
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -22.0
	process.angular_velocity_max = 22.0
	particles.process_material = process
	_particles_root.add_child(particles)
	return particles

func _add_bed_veil_sheet() -> void:
	if not ResourceLoader.exists(BED_VEIL_MATERIAL_PATH):
		return
	var sheet := MeshInstance3D.new()
	sheet.name = "BedAngelicWhiteNoiseVeil"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.6, 2.35)
	sheet.mesh = mesh
	sheet.position = Vector3(0.0, 0.82, 0.0)
	sheet.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.set_surface_override_material(0, load(BED_VEIL_MATERIAL_PATH) as Material)
	add_child(sheet)

func _apply_corrosion_to_meshes(opacity: float, rust_color: Color, emission_leak: float) -> void:
	if not ResourceLoader.exists(CORROSION_MATERIAL_PATH):
		push_warning("Corrosion material not found: " + CORROSION_MATERIAL_PATH)
		return
	var base_material := load(CORROSION_MATERIAL_PATH) as ShaderMaterial
	if base_material == null:
		return
	var meshes := _find_meshes(_target)
	for mesh in meshes:
		var material := base_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("opacity", opacity)
		material.set_shader_parameter("rust_color", rust_color)
		material.set_shader_parameter("emission_leak", emission_leak)
		_safe_set(mesh, "material_overlay", material)

func _add_omni_light(light_name: String, light_color: Color, energy: float, light_range: float, local_position: Vector3) -> void:
	if not enable_lights:
		return
	if find_child(light_name, false, false) != null:
		return
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = local_position
	light.light_color = light_color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)

func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root == null:
		return result
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			result.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return result

func _find_active_camera(root: Node) -> Camera3D:
	if root == null:
		return null
	var fallback: Camera3D = null
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is Camera3D:
			var camera: Camera3D = node as Camera3D
			if camera.current:
				return camera
			if fallback == null:
				fallback = camera
		for child in node.get_children():
			stack.append(child)
	return fallback

func _safe_set(obj: Object, property_name: String, property_value: Variant) -> void:
	if obj == null:
		return
	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == property_name:
			obj.set(property_name, property_value)
			return

func _has_shader_parameter(material: ShaderMaterial, parameter_name: String) -> bool:
	if material == null:
		return false
	# Godot accepts set_shader_parameter on absent uniforms, but this guard keeps intent clear.
	return true
