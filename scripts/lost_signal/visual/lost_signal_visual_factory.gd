class_name LostSignalVisualFactory
extends RefCounted


static func material(
	color: Color,
	roughness: float = 0.72,
	metallic: float = 0.0,
	emission: Color = Color(0.0, 0.0, 0.0, 1.0),
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = roughness
	value.metallic = metallic
	if emission_energy > 0.0:
		value.emission_enabled = true
		value.emission = emission
		value.emission_energy_multiplier = emission_energy
	return value


static func box(
	parent: Node,
	name: String,
	size: Vector3,
	position: Vector3,
	mat: Material,
	rotation_degrees: Vector3 = Vector3.ZERO,
	shadow := true
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.set_surface_override_material(0, mat)
	if not shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func cylinder(
	parent: Node,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	mat: Material,
	rotation_degrees: Vector3 = Vector3.ZERO,
	radial_segments := 16
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.set_surface_override_material(0, mat)
	parent.add_child(node)
	return node


static func sphere(
	parent: Node,
	name: String,
	radius: float,
	position: Vector3,
	mat: Material,
	scale: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.position = position
	node.scale = scale
	node.set_surface_override_material(0, mat)
	parent.add_child(node)
	return node


static func plane(
	parent: Node,
	name: String,
	size: Vector2,
	position: Vector3,
	mat: Material,
	rotation_degrees: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := PlaneMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.set_surface_override_material(0, mat)
	parent.add_child(node)
	return node


static func label_3d(
	parent: Node,
	name: String,
	text: String,
	position: Vector3,
	font_size := 72,
	color := Color.WHITE
) -> Label3D:
	var label := Label3D.new()
	label.name = name
	label.text = text
	label.position = position
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 8
	label.no_depth_test = false
	parent.add_child(label)
	return label


static func make_night_environment(fog_density := 0.008, ambient_energy := 0.24) -> WorldEnvironment:
	var world := WorldEnvironment.new()
	world.name = "NightWorldEnvironment"
	var env := Environment.new()
	var panorama := load("res://assets/lost_signal/environment/sky/qwantani_night_puresky_4k.exr") as Texture2D
	if panorama:
		var sky_material := PanoramaSkyMaterial.new()
		sky_material.panorama = panorama
		sky_material.energy_multiplier = 0.34
		var sky := Sky.new()
		sky.radiance_size = Sky.RADIANCE_SIZE_512
		sky.sky_material = sky_material
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.003, 0.008, 0.024)
	env.background_energy_multiplier = 0.18
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.19, 0.32)
	env.ambient_light_energy = ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.12, 0.19)
	env.fog_light_energy = 0.45
	env.fog_density = fog_density
	env.fog_height = 1.0
	env.fog_height_density = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	return world


static func make_star_field(parent: Node, count := 420, radius := 170.0, seed := 9317) -> MultiMeshInstance3D:
	var star_material := material(
		Color(0.92, 0.96, 1.0), 1.0, 0.0,
		Color(0.72, 0.84, 1.0), 2.4
	)
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var star_mesh := QuadMesh.new()
	star_mesh.size = Vector2(0.26, 0.26)
	star_mesh.material = star_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = star_mesh
	multimesh.instance_count = count
	var random := RandomNumberGenerator.new()
	random.seed = seed
	for index in count:
		var angle := random.randf_range(-PI, PI)
		var elevation := random.randf_range(0.08, 1.25)
		var distance := random.randf_range(radius * 0.86, radius)
		var position := Vector3(
			cos(angle) * cos(elevation) * distance,
			sin(elevation) * distance,
			sin(angle) * cos(elevation) * distance
		)
		var size := random.randf_range(0.35, 1.65)
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * size), position))
	var instance := MultiMeshInstance3D.new()
	instance.name = "StaticStarField"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func build_anthro_character(
	parent: Node,
	name: String,
	position: Vector3,
	coat: Color,
	apron: Color,
	ears := true,
	tail := true
) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.position = position
	parent.add_child(root)
	var coat_mat := material(coat, 0.84)
	var cloth_mat := material(apron, 0.9)
	var dark_mat := material(coat.darkened(0.55), 0.78)
	cylinder(root, "Torso", 0.28, 0.85, Vector3(0, 1.17, 0), cloth_mat, Vector3.ZERO, 14)
	sphere(root, "Head", 0.30, Vector3(0, 1.84, 0), coat_mat, Vector3(0.95, 1.06, 0.9))
	cylinder(root, "ArmL", 0.075, 0.68, Vector3(-0.34, 1.18, 0), coat_mat, Vector3(0, 0, -8), 10)
	cylinder(root, "ArmR", 0.075, 0.68, Vector3(0.34, 1.18, 0), coat_mat, Vector3(0, 0, 8), 10)
	cylinder(root, "LegL", 0.09, 0.78, Vector3(-0.14, 0.4, 0), dark_mat, Vector3.ZERO, 10)
	cylinder(root, "LegR", 0.09, 0.78, Vector3(0.14, 0.4, 0), dark_mat, Vector3.ZERO, 10)
	sphere(root, "EyeL", 0.034, Vector3(-0.105, 1.90, -0.266), material(Color(0.015, 0.02, 0.025), 0.35), Vector3(0.8, 1.0, 0.45))
	sphere(root, "EyeR", 0.034, Vector3(0.105, 1.90, -0.266), material(Color(0.015, 0.02, 0.025), 0.35), Vector3(0.8, 1.0, 0.45))
	if ears:
		var ear_l := sphere(root, "EarL", 0.15, Vector3(-0.18, 2.18, 0), coat_mat, Vector3(0.55, 1.4, 0.5))
		ear_l.rotation_degrees.z = -18.0
		var ear_r := sphere(root, "EarR", 0.15, Vector3(0.18, 2.18, 0), coat_mat, Vector3(0.55, 1.4, 0.5))
		ear_r.rotation_degrees.z = 18.0
	if tail:
		var tail_node := cylinder(root, "Tail", 0.065, 0.72, Vector3(0.33, 0.85, 0.22), coat_mat, Vector3(60, 0, -25), 10)
		tail_node.add_to_group("lost_signal_tails")
	root.set_meta("idle_phase", float(name.hash() % 1000) / 173.0)
	return root
