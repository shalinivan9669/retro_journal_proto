extends Node3D

enum QualityProfile {
	CINEMATIC,
	PERFORMANCE,
}

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const NIGHT_HDRI := preload(
	"res://addons/archive_barrage/assets/polyhaven/rogland_clear_night_4k/rogland_clear_night_4k.exr"
)
const VISIBLE_SKY_TEXTURE := preload(
	"res://addons/archive_barrage/assets/generated/backgrounds/visible_archive_night_sky_8k.png"
)
const SKY_DOME_SHADER := preload(
	"res://addons/archive_barrage/shaders/archive_sky_dome.gdshader"
)

@export_enum("Cinematic", "Performance") var quality_profile: int = QualityProfile.CINEMATIC

var _previous_scaling_3d_scale := 1.0
var _changed_scaling_3d_scale := false


func _ready() -> void:
	add_to_group("archive_night_barrage")
	var performance_mode := quality_profile == QualityProfile.PERFORMANCE
	_apply_viewport_quality(performance_mode)

	var terrain := BarrageTerrain.new()
	terrain.name = "SteppeEnvironment"
	terrain.position = Vector3(0.0, 0.0, -250.0)
	add_child(terrain)
	terrain.build(performance_mode)

	var camera := _create_project_player(terrain)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArchiveNightEnvironment"
	world_environment.environment = _create_environment(performance_mode)
	add_child(world_environment)

	_create_visible_sky_dome(performance_mode)
	_create_starlight(performance_mode)

	var props := EnvironmentPropBuilder.new()
	props.name = "EnvironmentProps"
	add_child(props)
	props.build(terrain, performance_mode)

	var light_pool := DynamicLightPool.new()
	light_pool.name = "DynamicLightPool"
	light_pool.configure_quality(performance_mode)
	add_child(light_pool)

	var post_process := ArchivePostProcess.new()
	post_process.name = "ArchivePostProcess"
	add_child(post_process)

	var director := BarrageDirector.new()
	director.name = "BarrageDirector"
	add_child(director)
	director.configure(camera, terrain, light_pool, post_process, performance_mode)


func _exit_tree() -> void:
	if _changed_scaling_3d_scale and is_instance_valid(get_viewport()):
		get_viewport().scaling_3d_scale = _previous_scaling_3d_scale


func get_quality_profile_name() -> String:
	return "Performance" if quality_profile == QualityProfile.PERFORMANCE else "Cinematic"


func _apply_viewport_quality(performance_mode: bool) -> void:
	var viewport := get_viewport()
	_previous_scaling_3d_scale = viewport.scaling_3d_scale
	viewport.scaling_3d_scale = 0.80 if performance_mode else 1.0
	_changed_scaling_3d_scale = true


func _create_project_player(terrain: BarrageTerrain) -> Camera3D:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player"
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var head := player.get_node("Head") as Node3D
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 950.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	camera.attributes = null
	head.rotation_degrees.x = -7.0
	player.set("pitch", deg_to_rad(-7.0))

	var observation_x := 0.0
	var observation_z := 92.0
	player.position = Vector3(
		observation_x,
		terrain.height_at_world(observation_x, observation_z) + 0.025,
		observation_z
	)
	add_child(player)
	return camera


func _create_environment(performance_mode: bool) -> Environment:
	var environment := Environment.new()
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = NIGHT_HDRI
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_512 if performance_mode else Sky.RADIANCE_SIZE_1024

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.055
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.055, 0.059, 0.065)
	environment.ambient_light_energy = 0.032
	environment.ambient_light_sky_contribution = 0.12
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.78
	environment.tonemap_white = 2.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.78 if performance_mode else 0.92
	environment.glow_strength = 1.02 if performance_mode else 1.16
	environment.glow_bloom = 0.11 if performance_mode else 0.14
	environment.glow_hdr_threshold = 0.9
	environment.glow_hdr_scale = 2.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	environment.ssao_enabled = not performance_mode
	environment.ssao_radius = 2.2
	environment.ssao_intensity = 2.4
	environment.ssao_power = 1.7
	environment.ssr_enabled = true

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0018 if performance_mode else 0.0027
	environment.volumetric_fog_length = 360.0 if performance_mode else 520.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_ambient_inject = 0.14 if performance_mode else 0.18
	environment.volumetric_fog_sky_affect = 0.32 if performance_mode else 0.38
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.68
	return environment


func _create_visible_sky_dome(performance_mode: bool) -> void:
	var dome := MeshInstance3D.new()
	dome.name = "VisibleArchiveSky"
	var sphere := SphereMesh.new()
	sphere.radius = 690.0
	sphere.height = 1380.0
	sphere.radial_segments = 72 if performance_mode else 96
	sphere.rings = 36 if performance_mode else 48
	dome.mesh = sphere
	dome.position = Vector3(0.0, -70.0, -250.0)
	var material := ShaderMaterial.new()
	material.shader = SKY_DOME_SHADER
	material.set_shader_parameter("sky_texture", VISIBLE_SKY_TEXTURE)
	material.set_shader_parameter("energy", 0.72)
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


func _create_starlight(performance_mode: bool) -> void:
	var moonless_light := DirectionalLight3D.new()
	moonless_light.name = "WeakNightSkyLight"
	moonless_light.rotation_degrees = Vector3(-54.0, -24.0, 0.0)
	moonless_light.light_color = Color(0.52, 0.57, 0.65)
	moonless_light.light_energy = 0.045
	moonless_light.shadow_enabled = true
	moonless_light.directional_shadow_max_distance = 220.0 if performance_mode else 280.0
	add_child(moonless_light)
