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
const MOUNTAIN_SILHOUETTE := preload(
	"res://addons/archive_barrage/assets/generated/backgrounds/far_berms_8k.png"
)
const SKY_DOME_SHADER := preload(
	"res://addons/archive_barrage/shaders/archive_sky_dome.gdshader"
)
const FILM_REVEAL_CONTROLLER_SCRIPT := preload(
	"res://addons/film_revelation/film_reveal_controller.gd"
)
const FILM_REVEAL_PROFILE_SCRIPT := preload(
	"res://addons/film_revelation/film_reveal_profile.gd"
)
const FILM_REVEAL_TARGET_SCRIPT := preload(
	"res://addons/film_revelation/film_reveal_target.gd"
)
const GEIGER_CLICK_EMITTER_SCRIPT := preload(
	"res://addons/film_revelation/geiger_click_emitter.gd"
)
const RIDERS_MANIFESTATION_SCRIPT := preload(
	"res://addons/film_revelation/riders_manifestation.gd"
)
const FILM_REVEAL_SHADER := preload(
	"res://addons/film_revelation/film_reveal.gdshader"
)
const TWO_WHITE_HORSES_NEGATIVE_TEXTURE := preload(
	"res://assets/film/two_white_horses/negative_initial.png"
)
const TWO_WHITE_HORSES_REVEALED_TEXTURE := preload(
	"res://assets/film/two_white_horses/original_revealed.png"
)
const COLD_ION_PARTICLE_MATERIAL := preload(
	"res://materials/vfx/mat_rcv_ion_particle_white.tres"
)
const STEPPE_STRUCTURE_BUILDER_SCRIPT := preload(
	"res://addons/archive_barrage/scripts/steppe_structure_builder.gd"
)
const MOON_UV := Vector2(0.611, 0.420)
const MOON_SKY_DIRECTION := Vector3(0.62, 0.25, -0.74)
const ARCHIVE_PLAYER_EYE_HEIGHT := 3.0
const ARCHIVE_PLAYER_GROUND_CLEARANCE := 0.22
const ARCHIVE_INITIAL_LOOK_DOWN_DEGREES := 10.0
const FILM_TARGET_LAYER := 1 << 26
const FILM_TARGET_OFFSET_M := 0.45
const FILM_CARD_HEIGHT_RATIO := 0.64
const TWO_WHITE_HORSES_FILM_ID := &"two_white_horses"
const RIDERS_MANIFESTATION_DURATION_S := 1.45
const FILM_HUM_MIX_RATE := 22050
const FILM_HUM_BASE_VOLUME_DB := -34.0

@export_enum("Cinematic", "Performance") var quality_profile: int = QualityProfile.PERFORMANCE

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

	var steppe_structures := STEPPE_STRUCTURE_BUILDER_SCRIPT.new() as Node3D
	steppe_structures.name = "SteppeStructures"
	add_child(steppe_structures)
	steppe_structures.call(&"build", terrain, performance_mode, player.global_position)

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

	_create_film_revelation(terrain, player, camera, performance_mode)


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
	# Keep the archive viewpoint and the whole player capsule safely above the
	# terrain. Starting even slightly inside a concave terrain triangle can put the
	# camera below its one-sided surface and make distant props look transparent.
	player.set("standing_head_y", ARCHIVE_PLAYER_EYE_HEIGHT)
	player.set("landscape_ground_surface_offset", ARCHIVE_PLAYER_GROUND_CLEARANCE)
	head.position.y = ARCHIVE_PLAYER_EYE_HEIGHT
	var initial_pitch := deg_to_rad(-ARCHIVE_INITIAL_LOOK_DOWN_DEGREES)
	player.set("pitch", initial_pitch)
	head.rotation.x = initial_pitch
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

	var observation_x := 0.0
	var observation_z := 92.0
	player.position = Vector3(
		observation_x,
		terrain.height_at_world(observation_x, observation_z) + ARCHIVE_PLAYER_GROUND_CLEARANCE,
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
	archive_sky.set_shader_parameter("mountain_texture", MOUNTAIN_SILHOUETTE)
	archive_sky.set_shader_parameter("energy", 1.0)
	archive_sky.set_shader_parameter("ibl_strength", 0.55 if performance_mode else 0.65)
	archive_sky.set_shader_parameter("visible_strength", 0.20 if performance_mode else 0.22)
	archive_sky.set_shader_parameter("star_strength", 1.35 if performance_mode else 1.55)
	archive_sky.set_shader_parameter("moon_uv", MOON_UV)
	archive_sky.set_shader_parameter("moon_energy", 0.86)
	sky.sky_material = archive_sky
	sky.radiance_size = Sky.RADIANCE_SIZE_512 if performance_mode else Sky.RADIANCE_SIZE_1024

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Keep the now-matte ground readable with cold diffuse fill. This raises the
	# shadow side of banks and crater bowls without restoring a wet specular band.
	environment.ambient_light_color = Color(0.145, 0.152, 0.172)
	environment.ambient_light_energy = 0.22 if performance_mode else 0.26
	environment.ambient_light_sky_contribution = 0.14
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.92
	environment.tonemap_white = 2.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.22 if performance_mode else 0.28
	environment.glow_strength = 0.30 if performance_mode else 0.38
	environment.glow_bloom = 0.018 if performance_mode else 0.025
	environment.glow_hdr_threshold = 1.2
	environment.glow_hdr_scale = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	environment.ssao_enabled = not performance_mode
	environment.ssao_radius = 2.2
	environment.ssao_intensity = 2.4
	environment.ssao_power = 1.7
	environment.ssr_enabled = true

	# Barrage lights remain local surface flashes. Disabling the global volume
	# prevents every launch from bleaching the stars and moon into a grey wall.
	environment.volumetric_fog_enabled = false
	return environment


func _create_starlight(performance_mode: bool) -> void:
	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonDirectionalLight"
	# Point the light rays opposite the visible moon direction so highlights and
	# shadows consistently come from the moon's side of the panorama.
	moon_light.basis = Basis.looking_at(-MOON_SKY_DIRECTION.normalized(), Vector3.UP)
	moon_light.light_color = Color(0.66, 0.72, 0.84)
	moon_light.light_energy = 0.52 if performance_mode else 0.62
	moon_light.light_angular_distance = 0.28
	moon_light.light_volumetric_fog_energy = 0.0
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_max_distance = 520.0 if performance_mode else 760.0
	add_child(moon_light)


func _create_film_revelation(
	terrain: BarrageTerrain,
	player: CharacterBody3D,
	camera: Camera3D,
	performance_mode: bool
) -> void:
	var target := _create_horse_hill_target(terrain, player)
	var riders_manifestation := _create_riders_manifestation(
		terrain,
		target,
		player,
		camera
	)
	var radiation_particles := _create_film_radiation_particles(player, performance_mode)

	var controller := FILM_REVEAL_CONTROLLER_SCRIPT.new() as CanvasLayer
	controller.name = "FilmRevealController"
	controller.layer = 110

	var back_buffer := BackBufferCopy.new()
	back_buffer.name = "BackBufferCopy"
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	controller.add_child(back_buffer)

	var film_card := TextureRect.new()
	film_card.name = "FilmCard"
	film_card.texture = TWO_WHITE_HORSES_NEGATIVE_TEXTURE
	film_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	film_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	film_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film_card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	film_card.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_layout_film_card(film_card)
	var film_material := ShaderMaterial.new()
	film_material.shader = FILM_REVEAL_SHADER
	film_material.set_shader_parameter(
		"original_revealed_texture",
		TWO_WHITE_HORSES_REVEALED_TEXTURE
	)
	film_card.material = film_material
	controller.add_child(film_card)

	var aim_dot := ColorRect.new()
	aim_dot.name = "CenterDot"
	aim_dot.set_anchors_preset(Control.PRESET_CENTER)
	aim_dot.position = Vector2(-2.0, -2.0)
	aim_dot.size = Vector2(4.0, 4.0)
	aim_dot.pivot_offset = Vector2(2.0, 2.0)
	aim_dot.color = Color(0.82, 0.90, 0.92, 0.72)
	aim_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controller.add_child(aim_dot)

	var click_player := AudioStreamPlayer.new()
	click_player.name = "ClickPlayer"
	click_player.volume_db = -20.0
	click_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	var geiger := GEIGER_CLICK_EMITTER_SCRIPT.new() as Node
	geiger.name = "GeigerClickEmitter"
	geiger.add_child(click_player)
	geiger.set("click_player", click_player)
	controller.add_child(geiger)

	var low_frequency_hum := AudioStreamPlayer.new()
	low_frequency_hum.name = "LowFrequencyHum"
	low_frequency_hum.stream = _build_film_low_frequency_hum()
	low_frequency_hum.volume_db = FILM_HUM_BASE_VOLUME_DB
	low_frequency_hum.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	low_frequency_hum.autoplay = true
	controller.add_child(low_frequency_hum)

	var profile := FILM_REVEAL_PROFILE_SCRIPT.new() as Resource
	profile.set("slot_action", &"film_slot_4")
	profile.set("equip_time_s", 0.22)
	profile.set("acquire_angle_deg", 12.0)
	profile.set("release_angle_deg", 18.0)
	profile.set("dwell_s", 0.35)
	profile.set("camera_lock_s", 0.28)
	profile.set("reveal_s", 4.80)
	profile.set("post_lock_hold_s", 0.35)
	profile.set("film_shake_px", 7.0)
	profile.set("film_tilt_deg", 1.35)
	profile.set("camera_shake_deg", 0.12)
	profile.set("camera_shake_m", 0.0035)
	profile.set("film_opacity", 0.52)
	profile.set("radiation_peak", 1.0)

	controller.set("profile", profile)
	controller.set("camera", camera)
	controller.set("film_rect", film_card)
	controller.set("revealed_texture", TWO_WHITE_HORSES_REVEALED_TEXTURE)
	controller.set("target", target)
	controller.set("input_lock_receiver", player)
	controller.set("geiger_emitter", geiger)
	controller.set("low_frequency_hum", low_frequency_hum)
	controller.set("radiation_particles", radiation_particles)
	controller.set("aim_indicator", aim_dot)
	controller.set("target_collision_mask", FILM_TARGET_LAYER)
	controller.set("occlusion_collision_mask", 0)
	controller.set("allow_angular_target_assist", true)
	controller.connect(
		&"final_reveal_reached",
		Callable(self, "_on_final_film_reveal_reached").bind(
			riders_manifestation,
			controller
		)
	)
	controller.connect(&"film_archived", Callable(GameState, "archive_film"))

	var legacy_viewer := camera.get_node_or_null("FilmViewer")
	controller.connect(
		&"equipment_changed",
		func(equipped: bool) -> void:
			if equipped and is_instance_valid(legacy_viewer) and legacy_viewer.has_method("hide_film"):
				legacy_viewer.call("hide_film", true)
	)
	add_child(controller)


func _create_riders_manifestation(
	terrain: BarrageTerrain,
	target: Node3D,
	player: CharacterBody3D,
	camera: Camera3D
) -> Node3D:
	var manifestation := RIDERS_MANIFESTATION_SCRIPT.new() as Node3D
	manifestation.name = "RidersManifestation"
	manifestation.call("setup", target.global_position, camera, player, terrain)
	add_child(manifestation)
	if GameState.is_film_archived(TWO_WHITE_HORSES_FILM_ID):
		manifestation.call("show_immediate")
	return manifestation


func _on_final_film_reveal_reached(
	film_id: StringName,
	_texture: Texture2D,
	manifestation: Node,
	controller: Node
) -> void:
	if film_id != TWO_WHITE_HORSES_FILM_ID:
		return
	if not is_instance_valid(manifestation) or not is_instance_valid(controller):
		return
	var started := bool(manifestation.call(
		"manifest",
		RIDERS_MANIFESTATION_DURATION_S
	))
	if started:
		controller.call(
			"request_post_reveal_hold",
			RIDERS_MANIFESTATION_DURATION_S
		)


func _create_horse_hill_target(
	terrain: BarrageTerrain,
	player: CharacterBody3D
) -> Node3D:
	var surface_point := terrain.get_film_reveal_crest_target_world()
	var surface_normal := terrain.normal_at_world(surface_point.x, surface_point.z, 0.75)
	var normal_axis := surface_normal.normalized()
	var lateral_axis := Vector3.UP.cross(normal_axis)
	if lateral_axis.length_squared() <= 0.000001:
		var toward_player := player.global_position - surface_point
		toward_player.y = 0.0
		lateral_axis = toward_player.normalized().cross(Vector3.UP)
	if lateral_axis.length_squared() <= 0.000001:
		lateral_axis = Vector3.RIGHT
	lateral_axis = lateral_axis.normalized()
	var slope_axis := normal_axis.cross(lateral_axis).normalized()
	var target_basis := Basis(lateral_axis, slope_axis, normal_axis).orthonormalized()

	var target := FILM_REVEAL_TARGET_SCRIPT.new() as Node3D
	target.name = "HorseHillTarget"
	target.global_transform = Transform3D(target_basis, surface_point)
	target.set("film_id", TWO_WHITE_HORSES_FILM_ID)
	target.set("one_shot", true)
	target.set("developed", GameState.is_film_archived(TWO_WHITE_HORSES_FILM_ID))
	target.set_meta(&"terrain_anchor_kind", &"crest_edge")
	target.set_meta(&"terrain_anchor_world", surface_point)
	target.set_meta(
		&"crest_edge_offsets_m",
		terrain.get_film_reveal_crest_edge_offsets_m()
	)

	var aim_marker := Marker3D.new()
	aim_marker.name = "AimMarker"
	aim_marker.position = Vector3(0.0, 0.0, FILM_TARGET_OFFSET_M)
	target.add_child(aim_marker)

	var hit_area := Area3D.new()
	hit_area.name = "HitArea"
	hit_area.position = Vector3(0.0, 0.0, FILM_TARGET_OFFSET_M)
	hit_area.collision_layer = FILM_TARGET_LAYER
	hit_area.collision_mask = 0
	target.add_child(hit_area)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(24.0, 16.0, 2.0)
	collision_shape.shape = box
	hit_area.add_child(collision_shape)

	target.set("aim_marker", aim_marker)
	target.set("hit_area", hit_area)
	add_child(target)
	return target


func _create_film_radiation_particles(
	player: CharacterBody3D,
	performance_mode: bool
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "FilmRadiationParticles"
	particles.position = Vector3(0.0, 1.8, 0.0)
	particles.amount = 180 if performance_mode else 320
	particles.amount_ratio = 0.12
	particles.lifetime = 2.1
	particles.preprocess = 1.4
	particles.local_coords = false
	particles.speed_scale = 1.0
	particles.visibility_aabb = AABB(Vector3(-8.0, -6.0, -8.0), Vector3(16.0, 12.0, 16.0))

	var draw_material := COLD_ION_PARTICLE_MATERIAL.duplicate(true) as ShaderMaterial
	draw_material.set_shader_parameter("ion_color", Color(0.86, 0.94, 1.0, 0.30))
	draw_material.set_shader_parameter("core_power", 1.35)
	draw_material.set_shader_parameter("flicker", 0.28)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	quad.material = draw_material
	particles.draw_pass_1 = quad

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(2.8, 1.8, 2.8)
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.05
	process_material.initial_velocity_max = 0.18
	process_material.damping_min = 0.08
	process_material.damping_max = 0.28
	process_material.scale_min = 0.65
	process_material.scale_max = 2.35
	process_material.angle_min = -180.0
	process_material.angle_max = 180.0
	process_material.angular_velocity_min = -18.0
	process_material.angular_velocity_max = 18.0
	particles.process_material = process_material
	particles.emitting = true
	player.add_child(particles)
	return particles


func _layout_film_card(film_card: TextureRect) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var side := viewport_size.y * FILM_CARD_HEIGHT_RATIO
	var bottom_margin := viewport_size.y * 0.0555556
	film_card.position = Vector2(
		(viewport_size.x - side) * 0.5,
		viewport_size.y - bottom_margin - side
	)
	film_card.size = Vector2(side, side)


func _build_film_low_frequency_hum() -> AudioStreamWAV:
	# One-second integer-frequency loop: periodic endpoints avoid an audible seam.
	var sample_count := FILM_HUM_MIX_RATE
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time_s := float(sample_index) / float(FILM_HUM_MIX_RATE)
		var sample_value := (
			sin(TAU * 43.0 * time_s) * 0.46
			+ sin(TAU * 86.0 * time_s + 0.31) * 0.17
			+ sin(TAU * 7.0 * time_s + 1.17) * 0.07
		)
		var encoded := clampi(int(round(sample_value * 32767.0)), -32768, 32767)
		sample_data.encode_s16(sample_index * 2, encoded)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = FILM_HUM_MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = sample_data
	return stream
