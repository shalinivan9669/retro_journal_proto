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

	var player_setup := _create_project_player(terrain)
	var player := player_setup["player"] as CharacterBody3D
	var camera := player_setup["camera"] as Camera3D

	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArchiveNightEnvironment"
	world_environment.environment = _create_environment(performance_mode)
	add_child(world_environment)

	_create_starlight(performance_mode)

	var props := EnvironmentPropBuilder.new()
	props.name = "EnvironmentProps"
	add_child(props)
	props.build(terrain, performance_mode)

	var light_pool := DynamicLightPool.new()
	light_pool.name = "DynamicLightPool"
	light_pool.configure_quality(performance_mode, terrain)
	add_child(light_pool)

	var post_process := ArchivePostProcess.new()
	post_process.name = "ArchivePostProcess"
	add_child(post_process)

	var audio_director := BarrageAudioDirector.new()
	audio_director.name = "BarrageAudioDirector"
	add_child(audio_director)
	audio_director.configure(camera, performance_mode)

	var director := BarrageDirector.new()
	director.name = "BarrageDirector"
	add_child(director)
	director.configure(
		camera,
		player,
		terrain,
		light_pool,
		post_process,
		props,
		audio_director,
		performance_mode
	)


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


func _create_project_player(terrain: BarrageTerrain) -> Dictionary:
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player"
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var head := player.get_node("Head") as Node3D
	# A slightly higher archive-scene eye point exposes more near-ground detail
	# while keeping the shared Player scene and its collision capsule unchanged.
	player.set("standing_head_y", 1.82)
	head.position.y = 1.82
	camera.fov = 70.0
	camera.near = 0.05
	# The steppe itself reaches almost 800 m on the diagonal and the 2.4 km-wide
	# horizon cards are about 1.4 km away at their outer corners.  A 950 m far
	# plane clipped those cards toward the sides of an ultrawide view, producing
	# the false impression of a circular searchlight.
	camera.far = 3200.0
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
	return {"player": player, "camera": camera}


func _create_environment(performance_mode: bool) -> Environment:
	var environment := Environment.new()
	var sky := Sky.new()
	var archive_sky := ShaderMaterial.new()
	archive_sky.shader = SKY_DOME_SHADER
	archive_sky.set_shader_parameter("sky_texture", VISIBLE_SKY_TEXTURE)
	archive_sky.set_shader_parameter("hdri_texture", NIGHT_HDRI)
	archive_sky.set_shader_parameter("energy", 1.0)
	archive_sky.set_shader_parameter("ibl_strength", 4.5 if performance_mode else 5.0)
	archive_sky.set_shader_parameter("visible_strength", 0.08)
	archive_sky.set_shader_parameter("star_strength", 0.58 if performance_mode else 0.72)
	sky.sky_material = archive_sky
	sky.radiance_size = Sky.RADIANCE_SIZE_512 if performance_mode else Sky.RADIANCE_SIZE_1024

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.12
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.12, 0.125, 0.14)
	environment.ambient_light_energy = 0.72 if performance_mode else 0.82
	environment.ambient_light_sky_contribution = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 2.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.78 if performance_mode else 0.92
	environment.glow_strength = 1.02 if performance_mode else 1.16
	environment.glow_bloom = 0.11 if performance_mode else 0.14
	environment.glow_hdr_threshold = 0.78
	environment.glow_hdr_scale = 2.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	environment.ssao_enabled = not performance_mode
	environment.ssao_radius = 2.2
	environment.ssao_intensity = 2.4
	environment.ssao_power = 1.7
	environment.ssr_enabled = true

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0012 if performance_mode else 0.00155
	# Keep the fog volume beyond all playable terrain and the entire horizon
	# strip.  Its former short cutoff reinforced the same centre-only falloff.
	environment.volumetric_fog_length = 1400.0 if performance_mode else 1600.0
	environment.volumetric_fog_detail_spread = 2.0
	environment.volumetric_fog_ambient_inject = 0.22 if performance_mode else 0.27
	environment.volumetric_fog_sky_affect = 0.46 if performance_mode else 0.52
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.44
	return environment


func _create_starlight(performance_mode: bool) -> void:
	var moonless_light := DirectionalLight3D.new()
	moonless_light.name = "MoonAndSkyLight"
	moonless_light.rotation_degrees = Vector3(-38.0, 102.0, 0.0)
	moonless_light.light_color = Color(0.72, 0.75, 0.82)
	moonless_light.light_energy = 0.24 if performance_mode else 0.30
	moonless_light.light_angular_distance = 1.1
	moonless_light.shadow_enabled = true
	moonless_light.directional_shadow_max_distance = 520.0 if performance_mode else 760.0
	add_child(moonless_light)
