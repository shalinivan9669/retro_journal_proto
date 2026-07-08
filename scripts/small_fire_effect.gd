extends Node3D

@export var final_fire: bool = false

var _light: OmniLight3D
var _flame_particles: GPUParticles3D
var _ember_particles: GPUParticles3D
var _flame_cards: Array[MeshInstance3D] = []
var _time := 0.0
var _base_energy := 0.85
var _variant_scale := 1.0


func configure(is_final: bool) -> void:
	final_fire = is_final
	_apply_variant()


func _ready() -> void:
	_variant_scale = 1.28 if final_fire else 1.0
	_build_coals()
	_build_flame_cards()
	_build_particles()
	_build_light()
	_apply_variant()


func _process(delta: float) -> void:
	_time += delta
	if _light != null:
		var flicker := 0.9 + sin(_time * 6.7) * 0.07 + sin(_time * 12.3 + 0.8) * 0.035
		_light.light_energy = _base_energy * flicker

	for index in range(_flame_cards.size()):
		var card := _flame_cards[index]
		var phase := float(index) * 1.9
		card.rotation.z = deg_to_rad(float(index * 50)) + sin(_time * 3.2 + phase) * 0.045
		card.scale.y = _variant_scale * (0.92 + sin(_time * 4.1 + phase) * 0.05)


func _build_coals() -> void:
	var coal_material := _make_emissive_material(Color(0.025, 0.018, 0.014, 1.0), Color(0.16, 0.045, 0.018, 1.0), 0.32, false)
	for index in range(5):
		var coal := MeshInstance3D.new()
		coal.name = "Coal_%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.11 + float(index % 2) * 0.025
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.075
		mesh.radial_segments = 6
		coal.mesh = mesh
		coal.position = Vector3(cos(float(index) * TAU / 5.0) * 0.18, 0.035, sin(float(index) * TAU / 5.0) * 0.13)
		coal.rotation_degrees = Vector3(90.0, float(index * 37), 0.0)
		coal.set_surface_override_material(0, coal_material)
		add_child(coal)


func _build_flame_cards() -> void:
	var colors: Array[Color] = [
		Color(1.0, 0.34, 0.08, 0.72),
		Color(1.0, 0.62, 0.12, 0.58),
		Color(0.75, 0.08, 0.03, 0.42)
	]

	for index in range(3):
		var card := MeshInstance3D.new()
		card.name = "FlameCard_%02d" % index
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.34 - float(index) * 0.045, 0.58 - float(index) * 0.07)
		card.mesh = mesh
		card.position = Vector3(0.0, 0.34 + float(index) * 0.03, 0.0)
		card.rotation_degrees = Vector3(0.0, float(index * 60), float(index * 50))
		card.set_surface_override_material(0, _make_emissive_material(colors[index], colors[index], 1.25, true))
		_flame_cards.append(card)
		add_child(card)


func _build_particles() -> void:
	_flame_particles = _make_particles(
		"FlameParticles",
		18 if final_fire else 12,
		0.58,
		Color(1.0, 0.38, 0.08, 0.58),
		Vector2(0.07, 0.18),
		Vector2(0.2, 0.55),
		Vector3(0.0, 0.45, 0.0)
	)
	add_child(_flame_particles)

	_ember_particles = _make_particles(
		"EmberParticles",
		10 if final_fire else 6,
		1.15,
		Color(0.88, 0.28, 0.08, 0.45),
		Vector2(0.025, 0.06),
		Vector2(0.12, 0.32),
		Vector3(0.0, 0.18, 0.0)
	)
	add_child(_ember_particles)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.position = Vector3(0.0, 0.48, 0.0)
	_light.light_color = Color(1.0, 0.47, 0.18, 1.0)
	_light.light_energy = 0.85
	_light.omni_range = 4.4
	add_child(_light)


func _apply_variant() -> void:
	_variant_scale = 1.28 if final_fire else 1.0
	_base_energy = 1.25 if final_fire else 0.78
	scale = Vector3.ONE * _variant_scale

	if _light != null:
		_light.omni_range = 5.6 if final_fire else 3.8
		_light.light_energy = _base_energy
	if _flame_particles != null:
		_flame_particles.amount = 22 if final_fire else 12
	if _ember_particles != null:
		_ember_particles.amount = 14 if final_fire else 6


func _make_particles(
	node_name: String,
	amount: int,
	lifetime: float,
	color: Color,
	scale_range: Vector2,
	velocity_range: Vector2,
	gravity: Vector3
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.randomness = 0.55
	particles.visibility_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 1.8, 1.6))

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.14
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 21.0
	process_material.gravity = gravity
	process_material.initial_velocity_min = velocity_range.x
	process_material.initial_velocity_max = velocity_range.y
	process_material.scale_min = scale_range.x
	process_material.scale_max = scale_range.y
	process_material.color = color
	particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = _make_emissive_material(color, color, 1.1, true)
	particles.draw_pass_1 = quad
	return particles


func _make_emissive_material(albedo: Color, emission: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	if transparent or albedo.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material
