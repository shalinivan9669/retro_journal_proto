extends SceneTree


const CINEMATIC_SCENE_PATH := "res://addons/archive_barrage/scenes/ArchiveNightBarrage.tscn"
const PERFORMANCE_SCENE_PATH := (
	"res://addons/archive_barrage/scenes/ArchiveNightBarragePerformance.tscn"
)
const NEGATIVE_TEXTURE_PATH := "res://assets/film/two_white_horses/negative_initial.png"
const ORIGINAL_TEXTURE_PATH := "res://assets/film/two_white_horses/original_revealed.png"
const NEGATIVE_SOURCE_SHA256 := "a360da0835dc35cb64e225c0d48259725e9b93a866d985cca6e9a6d7dd2541e7"
const ORIGINAL_SOURCE_SHA256 := "0ad268d8d2a08bb26510c66917564bffb29aed9cf46942c1978cec788bdcf68d"
const FILM_SHADER_PATH := "res://addons/film_revelation/film_reveal.gdshader"
const FILM_ID := &"two_white_horses"
const TARGET_LAYER := 67_108_864
const PLAYER_ORIGIN_XZ := Vector2(0.0, 92.0)
const MOON_DIRECTION_XZ := Vector2(0.6422199, -0.7665205)
const EXPECTED_HILL_DISTANCE_M := 92.0
const INITIAL_VIEW_FORWARD_XZ := Vector2(0.0, -1.0)

const REQUIRED_PATHS := [
	"SteppeEnvironment",
	"Player",
	"Player/Head/Camera3D",
	"Player/FilmRadiationParticles",
	"HorseHillTarget",
	"HorseHillTarget/AimMarker",
	"HorseHillTarget/HitArea",
	"HorseHillTarget/HitArea/CollisionShape3D",
	"RidersManifestation",
	"FilmRevealController",
	"FilmRevealController/BackBufferCopy",
	"FilmRevealController/FilmCard",
	"FilmRevealController/CenterDot",
	"FilmRevealController/GeigerClickEmitter/ClickPlayer",
	"FilmRevealController/LowFrequencyHum",
]

var _failure_count := 0
var _scene_path := CINEMATIC_SCENE_PATH
var _run_wall_clock_timing := false


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if "--performance" in user_args:
		_scene_path = PERFORMANCE_SCENE_PATH
	_run_wall_clock_timing = "--timing" in user_args
	call_deferred("_run")


func _run() -> void:
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		_fail("Could not load %s" % _scene_path)
		quit(1)
		return

	var barrage := packed.instantiate() as Node3D
	if barrage == null:
		_fail("Could not instantiate %s" % _scene_path)
		quit(1)
		return

	get_root().add_child(barrage)
	current_scene = barrage
	# The builder currently creates its graph synchronously in _ready(). These
	# frames also let deferred ready work and PhysicsServer registrations settle.
	for _frame in range(3):
		await process_frame
		await physics_frame

	var nodes: Dictionary = {}
	for path in REQUIRED_PATHS:
		var node := barrage.get_node_or_null(path)
		_check(node != null, "Missing runtime node: %s" % path)
		if node != null:
			nodes[path] = node
	if _failure_count > 0:
		await _finish(barrage)
		return

	# Stop the live barrage after its runtime graph and physics objects exist. The
	# remaining checks are structural and do not need rendering or audio playback.
	barrage.process_mode = Node.PROCESS_MODE_DISABLED

	var terrain := nodes["SteppeEnvironment"] as Node3D
	var player := nodes["Player"] as Node3D
	var camera := nodes["Player/Head/Camera3D"] as Camera3D
	var particles := nodes["Player/FilmRadiationParticles"] as GPUParticles3D
	var target := nodes["HorseHillTarget"] as Node3D
	var aim_marker := nodes["HorseHillTarget/AimMarker"] as Marker3D
	var hit_area := nodes["HorseHillTarget/HitArea"] as Area3D
	var collision_shape := (
		nodes["HorseHillTarget/HitArea/CollisionShape3D"] as CollisionShape3D
	)
	var controller := nodes["FilmRevealController"] as CanvasLayer
	var back_buffer := nodes["FilmRevealController/BackBufferCopy"] as BackBufferCopy
	var film_card := nodes["FilmRevealController/FilmCard"] as TextureRect
	var center_dot := nodes["FilmRevealController/CenterDot"] as ColorRect
	var click_player := (
		nodes["FilmRevealController/GeigerClickEmitter/ClickPlayer"] as AudioStreamPlayer
	)
	var low_frequency_hum := (
		nodes["FilmRevealController/LowFrequencyHum"] as AudioStreamPlayer
	)
	var negative_texture := load(NEGATIVE_TEXTURE_PATH) as Texture2D
	var original_texture := load(ORIGINAL_TEXTURE_PATH) as Texture2D

	_check(terrain != null, "SteppeEnvironment is not Node3D")
	_check(player != null, "Player is not Node3D")
	_check(camera != null, "Player camera is not Camera3D")
	_check(particles != null, "FilmRadiationParticles is not GPUParticles3D")
	_check(target != null, "HorseHillTarget is not Node3D")
	_check(aim_marker != null, "AimMarker is not Marker3D")
	_check(hit_area != null, "HitArea is not Area3D")
	_check(collision_shape != null, "HitArea collision is not CollisionShape3D")
	_check(controller != null, "FilmRevealController is not CanvasLayer")
	_check(back_buffer != null, "BackBufferCopy has the wrong type")
	_check(film_card != null, "FilmCard is not TextureRect")
	_check(center_dot != null, "CenterDot is not ColorRect")
	_check(click_player != null, "ClickPlayer is not AudioStreamPlayer")
	_check(low_frequency_hum != null, "LowFrequencyHum is not AudioStreamPlayer")
	_check(negative_texture != null, "Could not load the initial negative texture")
	_check(original_texture != null, "Could not load the revealed original texture")
	if _failure_count > 0:
		await _finish(barrage)
		return

	_assert_source_assets(negative_texture, original_texture)
	_assert_ui(
		controller,
		back_buffer,
		film_card,
		center_dot,
		click_player,
		low_frequency_hum,
		negative_texture,
		original_texture
	)
	_assert_target(target, aim_marker, hit_area, collision_shape)
	_assert_controller_profile(controller)
	_assert_angular_target_assist(controller, camera, target, player)
	_assert_terrain_geometry(terrain, player, target)
	_assert_particles(barrage, controller, particles)
	_assert_player_interfaces(player, camera, controller)
	if _run_wall_clock_timing:
		await _assert_wall_clock_timeline(controller, target, player, camera)
	_assert_final_reveal_hold_contract(
		controller,
		target,
		player,
		camera,
		film_card,
		original_texture
	)
	_assert_game_state_round_trip(
		barrage,
		terrain,
		player,
		controller,
		original_texture
	)

	await _finish(barrage)


func _assert_ui(
	controller: CanvasLayer,
	back_buffer: BackBufferCopy,
	film_card: TextureRect,
	center_dot: ColorRect,
	click_player: AudioStreamPlayer,
	low_frequency_hum: AudioStreamPlayer,
	negative_texture: Texture2D,
	original_texture: Texture2D
) -> void:
	_check(controller.layer == 110, "Controller layer must be 110, got %d" % controller.layer)
	_check(
		back_buffer.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT,
		"BackBufferCopy must use COPY_MODE_VIEWPORT"
	)
	_check(
		back_buffer.get_parent() == film_card.get_parent()
		and back_buffer.get_index() < film_card.get_index(),
		"BackBufferCopy must precede FilmCard in the controller tree"
	)
	_check(
		film_card.texture != null,
		"FilmCard texture is missing"
	)
	if film_card.texture != null:
		_check(
			film_card.texture.get_width() == 1254 and film_card.texture.get_height() == 1254,
			"FilmCard texture must be 1254x1254, got %dx%d"
			% [film_card.texture.get_width(), film_card.texture.get_height()]
		)
		_check(
			film_card.texture.resource_path == NEGATIVE_TEXTURE_PATH,
			"FilmCard uses an unexpected texture: %s" % film_card.texture.resource_path
		)
		_check(
			film_card.texture == negative_texture,
			"FilmCard must display negative_initial.png before the reveal"
		)
	_check(
		_has_property(controller, &"revealed_texture"),
		"Controller lacks the revealed_texture export"
	)
	if _has_property(controller, &"revealed_texture"):
		var revealed_texture := controller.get("revealed_texture") as Texture2D
		_check(revealed_texture != null, "Controller revealed_texture is missing")
		if revealed_texture != null:
			_check(
				revealed_texture == original_texture
				and revealed_texture.resource_path == ORIGINAL_TEXTURE_PATH,
				"Controller revealed_texture must be original_revealed.png"
			)
	_check(
		film_card.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"FilmCard must preserve and center its aspect ratio"
	)
	_check(
		film_card.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"FilmCard must use linear filtering without mipmaps"
	)
	_check(
		film_card.texture_repeat == CanvasItem.TEXTURE_REPEAT_DISABLED,
		"FilmCard texture repeat must be disabled"
	)
	_check(
		is_equal_approx(film_card.size.x, film_card.size.y),
		"FilmCard control must remain square"
	)
	var viewport_height := controller.get_viewport().get_visible_rect().size.y
	var viewport_width := controller.get_viewport().get_visible_rect().size.x
	var expected_card_side := viewport_height * 0.64
	_check(
		absf(film_card.size.x - expected_card_side) <= 0.05,
		"FilmCard side must track viewport height, expected %.3f got %.3f"
		% [expected_card_side, film_card.size.x]
	)
	var base_position_value: Variant = controller.get("_film_base_position")
	_check(base_position_value is Vector2, "Controller lacks the equipped FilmCard base position")
	var equipped_position := (
		base_position_value as Vector2 if base_position_value is Vector2 else film_card.position
	)
	_check(
		absf(equipped_position.x - (viewport_width - expected_card_side) * 0.5) <= 0.05,
		"Equipped FilmCard must remain horizontally centered"
	)
	var card_center_y := equipped_position.y + film_card.size.y * 0.5
	_check(
		card_center_y >= viewport_height * 0.55
		and card_center_y <= viewport_height * 0.72
		and equipped_position.y + film_card.size.y <= viewport_height,
		"Equipped FilmCard must sit in the lower-center, got center Y %.3f of %.3f"
		% [card_center_y, viewport_height]
	)
	var shader_material := film_card.material as ShaderMaterial
	_check(shader_material != null, "FilmCard material is not ShaderMaterial")
	if shader_material != null:
		_check(shader_material.shader != null, "FilmCard shader is missing")
		if shader_material.shader != null:
			_check(
				shader_material.shader.resource_path == FILM_SHADER_PATH,
				"FilmCard uses an unexpected shader: %s"
				% shader_material.shader.resource_path
			)
			_assert_shader_contract(shader_material.shader)
		var bound_original := shader_material.get_shader_parameter(
			&"original_revealed_texture"
		) as Texture2D
		_check(bound_original != null, "Shader original_revealed_texture is not bound")
		if bound_original != null:
			_check(
				bound_original == original_texture
				and bound_original.resource_path == ORIGINAL_TEXTURE_PATH,
				"Shader must bind original_revealed.png as the second photograph"
			)
	_check(
		center_dot.size.is_equal_approx(Vector2(4.0, 4.0)),
		"CenterDot must be 4x4 px, got %s" % center_dot.size
	)
	_check(
		is_equal_approx(click_player.volume_db, -20.0),
		"Geiger click base volume must be -20 dB, got %.3f" % click_player.volume_db
	)
	var expected_bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_check(click_player.bus == expected_bus, "Geiger click uses an unexpected audio bus")
	var geiger := click_player.get_parent()
	_check(geiger is GeigerClickEmitter, "ClickPlayer parent must be GeigerClickEmitter")
	if geiger is GeigerClickEmitter:
		_assert_float_property(geiger, &"base_rate_hz", 4.5)
		_assert_float_property(geiger, &"peak_rate_hz", 22.0)
		_assert_float_property(geiger, &"peak_volume_boost_db", 5.8)
	var click_wave := click_player.stream as AudioStreamWAV
	_check(click_wave != null, "Geiger click must be synthesized as AudioStreamWAV")
	if click_wave != null:
		_check(click_wave.mix_rate == 22_050, "Geiger click mix rate must be 22.05 kHz")
		_check(not click_wave.stereo, "Geiger click must be mono")
		_check(
			click_wave.format == AudioStreamWAV.FORMAT_16_BITS,
			"Geiger click must use 16-bit samples"
		)
		_check(
			click_wave.data.size() == 530,
			"Geiger click must contain 265 mono samples, got %d bytes" % click_wave.data.size()
		)
		if click_wave.data.size() >= 4:
			_check(
				click_wave.data.decode_s16(0) == 0
				and click_wave.data.decode_s16(click_wave.data.size() - 2) == 0,
				"Geiger click endpoints must be zeroed"
			)
	_assert_low_frequency_hum(controller, low_frequency_hum)


func _assert_source_assets(negative_texture: Texture2D, original_texture: Texture2D) -> void:
	_check(
		FileAccess.file_exists(NEGATIVE_TEXTURE_PATH),
		"Missing source asset: %s" % NEGATIVE_TEXTURE_PATH
	)
	_check(
		FileAccess.file_exists(ORIGINAL_TEXTURE_PATH),
		"Missing source asset: %s" % ORIGINAL_TEXTURE_PATH
	)
	_check(
		negative_texture.resource_path == NEGATIVE_TEXTURE_PATH,
		"Initial negative loaded from an unexpected path"
	)
	_check(
		original_texture.resource_path == ORIGINAL_TEXTURE_PATH,
		"Revealed original loaded from an unexpected path"
	)
	_check(
		negative_texture != original_texture
		and NEGATIVE_TEXTURE_PATH != ORIGINAL_TEXTURE_PATH,
		"The reveal must use two distinct Texture2D resources"
	)
	_check(
		negative_texture.get_width() == 1254 and negative_texture.get_height() == 1254,
		"negative_initial.png must remain 1254x1254"
	)
	_check(
		original_texture.get_width() == 736 and original_texture.get_height() == 736,
		"original_revealed.png must remain the supplied 736x736 image"
	)
	_check(
		FileAccess.get_sha256(NEGATIVE_TEXTURE_PATH).to_lower() == NEGATIVE_SOURCE_SHA256,
		"negative_initial.png does not match the supplied negative master bytes"
	)
	_check(
		FileAccess.get_sha256(ORIGINAL_TEXTURE_PATH).to_lower() == ORIGINAL_SOURCE_SHA256,
		"original_revealed.png must be an unchanged copy of the supplied image"
	)
	_assert_texture_import_settings(NEGATIVE_TEXTURE_PATH)
	_assert_texture_import_settings(ORIGINAL_TEXTURE_PATH)


func _assert_texture_import_settings(texture_path: String) -> void:
	var import_config := ConfigFile.new()
	var import_error := import_config.load(texture_path + ".import")
	_check(
		import_error == OK,
		"Could not read import settings for %s (error %d)" % [texture_path, import_error]
	)
	if import_error != OK:
		return
	_check(
		String(import_config.get_value("deps", "source_file", "")) == texture_path,
		"Import metadata points at the wrong source for %s" % texture_path
	)
	_check(
		not bool(import_config.get_value("params", "mipmaps/generate", true)),
		"UI film texture mipmaps must be disabled: %s" % texture_path
	)
	var compression_mode := int(import_config.get_value("params", "compress/mode", -1))
	_check(
		compression_mode == 0 or compression_mode == 2,
		"Film texture compression must be lossless or VRAM-compressed: %s" % texture_path
	)


func _assert_shader_contract(shader: Shader) -> void:
	var code := shader.code
	_check(
		code.contains("uniform sampler2D original_revealed_texture"),
		"Film shader lacks the second photograph sampler"
	)
	_check(
		code.contains("texture(TEXTURE, UV)"),
		"Film shader must sample the initial negative at the normal UI LOD"
	)
	_check(
		code.contains("texture(original_revealed_texture, UV)"),
		"Film shader must sample the revealed original at the normal UI LOD"
	)
	_check(
		not code.contains("textureLod(TEXTURE")
		and not code.contains("textureLod(original_revealed_texture"),
		"Horse photographs must never be blurred with textureLod"
	)
	_check(
		code.contains("calculate_reveal_mask")
		and code.contains("mix(aimed_negative, transition_original, reveal_mask)"),
		"Film shader must transform between both photographs through a reveal mask"
	)
	_check(
		code.contains("reveal_progress >= 0.999")
		and code.contains("transformed_photo = original_photo.rgb"),
		"Completed reveal must resolve to the sharp supplied original"
	)
	_check(
		code.contains("aim_strength") and code.contains("light_bleach"),
		"Aiming feedback and external-light bleaching must remain independent"
	)
	_check(
		code.contains("inner_edge")
		and code.contains("outer_edge")
		and code.contains("trailing_band"),
		"Film shader lacks the cold two-layer front and trailing emulsion wake"
	)
	_check(
		code.contains("front_micro_dots")
		and code.contains("front_branch_tracks")
		and code.contains("0.0022"),
		"Film shader lacks localized chemical detail or front-only UV deformation"
	)
	_check(
		code.contains("negative_ghost = texture(TEXTURE")
		and code.contains("completion_gate"),
		"Negative ghosting must stay on the source negative and vanish at completion"
	)


func _assert_low_frequency_hum(
	controller: CanvasLayer,
	low_frequency_hum: AudioStreamPlayer
) -> void:
	_check(
		_has_property(controller, &"low_frequency_hum"),
		"Controller lacks the low_frequency_hum assignment"
	)
	if _has_property(controller, &"low_frequency_hum"):
		_check(
			controller.get("low_frequency_hum") == low_frequency_hum,
			"Controller is not assigned to FilmRevealController/LowFrequencyHum"
		)
	_check(
		is_equal_approx(low_frequency_hum.volume_db, -34.0),
		"Low-frequency hum base volume must be -34 dB"
	)
	var expected_bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_check(low_frequency_hum.bus == expected_bus, "Low-frequency hum uses an unexpected audio bus")
	var hum_wave := low_frequency_hum.stream as AudioStreamWAV
	_check(hum_wave != null, "Low-frequency hum must be an AudioStreamWAV")
	if hum_wave == null:
		return
	_check(hum_wave.mix_rate == 22_050, "Low-frequency hum mix rate must be 22.05 kHz")
	_check(not hum_wave.stereo, "Low-frequency hum must be mono")
	_check(
		hum_wave.format == AudioStreamWAV.FORMAT_16_BITS,
		"Low-frequency hum must use 16-bit samples"
	)
	_check(
		hum_wave.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Low-frequency hum must use a seamless forward loop"
	)
	_check(
		hum_wave.loop_begin == 0 and hum_wave.loop_end == 22_050,
		"Low-frequency hum loop must span exactly one second"
	)
	_check(
		hum_wave.data.size() == 44_100,
		"Low-frequency hum must contain one second of mono 16-bit audio"
	)


func _assert_target(
	target: Node3D,
	aim_marker: Marker3D,
	hit_area: Area3D,
	collision_shape: CollisionShape3D
) -> void:
	_check(
		StringName(target.get("film_id")) == FILM_ID,
		"Target film_id must be two_white_horses"
	)
	_check(hit_area.collision_layer == TARGET_LAYER, "HitArea collision layer must be %d" % TARGET_LAYER)
	_check(hit_area.collision_mask == 0, "HitArea collision mask must be 0")
	var box := collision_shape.shape as BoxShape3D
	_check(box != null, "HitArea must use BoxShape3D")
	if box != null:
		_check(
			box.size.is_equal_approx(Vector3(24.0, 16.0, 2.0)),
			"HitArea box must be (24, 16, 2), got %s" % box.size
		)
	_check(
		is_equal_approx(aim_marker.position.z, 0.45),
		"AimMarker must sit 0.45 m out from the slope, got %.4f" % aim_marker.position.z
	)
	_check(
		hit_area.position.is_equal_approx(aim_marker.position),
		"HitArea and AimMarker offsets must match"
	)


func _assert_controller_profile(controller: CanvasLayer) -> void:
	_assert_state_enum_contract()
	_check(controller.has_method("request_equip"), "Controller lacks request_equip()")
	_check(controller.has_method("request_stow"), "Controller lacks request_stow()")
	_check(controller.has_method("is_equipped"), "Controller lacks is_equipped()")
	_check(
		controller.has_method("request_post_reveal_hold"),
		"Controller lacks request_post_reveal_hold()"
	)
	_check(controller.has_signal("equipment_changed"), "Controller lacks equipment_changed signal")
	_check(
		controller.has_signal("final_reveal_reached"),
		"Controller lacks final_reveal_reached signal"
	)
	_assert_int_property(controller, &"target_collision_mask", TARGET_LAYER)
	_assert_int_property(controller, &"occlusion_collision_mask", 0)
	_check(
		_has_property(controller, &"allow_angular_target_assist"),
		"Controller lacks allow_angular_target_assist"
	)
	if _has_property(controller, &"allow_angular_target_assist"):
		_check(
			bool(controller.get("allow_angular_target_assist")),
			"Angular target assist must be enabled"
		)

	var profile := controller.get("profile") as Resource
	_check(profile != null, "Controller profile is missing")
	if profile == null:
		return
	_check(
		StringName(profile.get("slot_action")) == &"film_slot_4",
		"Profile slot action must be film_slot_4"
	)
	_assert_float_property(profile, &"equip_time_s", 0.22)
	_assert_float_property(profile, &"acquire_angle_deg", 12.0)
	_assert_float_property(profile, &"release_angle_deg", 18.0)
	_assert_float_property(profile, &"dwell_s", 0.35)
	_assert_float_property(profile, &"camera_lock_s", 0.28)
	_assert_float_property(profile, &"reveal_s", 4.80)
	_assert_float_property(profile, &"post_lock_hold_s", 0.35)
	_assert_float_property(profile, &"film_shake_px", 7.0)
	_assert_float_property(profile, &"film_tilt_deg", 1.35)
	_assert_float_property(profile, &"camera_shake_deg", 0.12)
	_assert_float_property(profile, &"camera_shake_m", 0.0035)
	_assert_float_property(profile, &"capture_flash_s", 0.085)
	_assert_float_property(profile, &"film_opacity", 0.52)
	_assert_float_property(profile, &"aim_brightness_boost", 0.28)
	_assert_float_property(profile, &"aim_contrast_boost", 0.18)
	_assert_float_property(profile, &"radiation_idle_ratio", 0.12)
	_assert_float_property(profile, &"radiation_aim_ratio", 0.35)
	_assert_float_property(profile, &"radiation_peak", 1.0)
	_assert_float_property(profile, &"radiation_release_s", 0.65)
	_assert_float_property(profile, &"hum_peak_boost_db", 7.0)
	_assert_float_property(profile, &"geiger_peak_rate_hz", 22.0)
	_assert_float_property(profile, &"geiger_peak_volume_boost_db", 5.8)


func _assert_state_enum_contract() -> void:
	var required_states := [
		&"STOWED",
		&"EQUIPPING",
		&"IDLE_NEGATIVE",
		&"TARGET_REACTION",
		&"CAMERA_LOCK",
		&"REVEALING_TO_ORIGINAL",
		&"REVEALED",
	]
	for state_name in required_states:
		_check(
			FilmRevealController.State.has(state_name),
			"FilmRevealController.State lacks %s" % state_name
		)


func _assert_angular_target_assist(
	controller: CanvasLayer,
	camera: Camera3D,
	target: Node3D,
	player: Node3D
) -> void:
	if (
		not controller.has_method("_is_target_under_crosshair")
		or not _has_property(controller, &"allow_angular_target_assist")
	):
		_fail("Controller lacks the angular target assist interface")
		return
	var profile := controller.get("profile") as Resource
	if profile == null:
		_fail("Cannot test angular target assist without a profile")
		return
	var aim_point_value: Variant = target.call("get_aim_point")
	if not aim_point_value is Vector3:
		_fail("Target get_aim_point() must return Vector3")
		return

	var saved_camera_transform := camera.global_transform
	var saved_target_mask := int(controller.get("target_collision_mask"))
	var saved_assist := bool(controller.get("allow_angular_target_assist"))
	var saved_target_developed := bool(target.get("developed"))
	var saved_player_transform := player.global_transform
	var head := camera.get_parent() as Node3D
	var saved_head_transform := head.transform if head != null else Transform3D.IDENTITY
	var saved_camera_local_transform := camera.transform
	var saved_player_locked := bool(player.get("controls_locked"))
	var camera_origin := camera.global_position
	var target_direction := ((aim_point_value as Vector3) - camera_origin).normalized()
	var lateral := Vector3.UP.cross(target_direction).normalized()
	if lateral.length_squared() <= 0.000001:
		lateral = Vector3.RIGHT
	var acquire_angle_deg := float(profile.get("acquire_angle_deg"))
	var inside_angle_rad := deg_to_rad(acquire_angle_deg * 0.8)
	var outside_angle_rad := deg_to_rad(acquire_angle_deg + 0.5)
	var inside_direction := (
		target_direction * cos(inside_angle_rad) + lateral * sin(inside_angle_rad)
	).normalized()
	var outside_direction := (
		target_direction * cos(outside_angle_rad) + lateral * sin(outside_angle_rad)
	).normalized()

	# A zero target mask makes the physics ray deterministically miss. This
	# isolates the angular assist from the enlarged Area3D collider.
	controller.set("target_collision_mask", 0)
	controller.set("allow_angular_target_assist", false)
	camera.global_transform = saved_camera_transform.looking_at(
		camera_origin + inside_direction * 10.0,
		Vector3.UP
	)
	_check(
		not bool(controller.call("_is_target_under_crosshair", acquire_angle_deg)),
		"A missed target ray must fail when angular assist is disabled"
	)
	controller.set("allow_angular_target_assist", true)
	_check(
		bool(controller.call("_is_target_under_crosshair", acquire_angle_deg)),
		"Angular assist must accept a narrow ray miss inside the acquire cone"
	)
	camera.global_transform = saved_camera_transform.looking_at(
		camera_origin + outside_direction * 10.0,
		Vector3.UP
	)
	_check(
		not bool(controller.call("_is_target_under_crosshair", acquire_angle_deg)),
		"Angular assist must reject aim outside the acquire cone"
	)

	# Exercise the actual acquisition path, not just its aim predicate. A partial
	# assisted dwell must wake the negative without revealing it; only the full
	# easier-acquisition dwell may enter CAMERA_LOCK.
	camera.global_transform = saved_camera_transform.looking_at(
		camera_origin + inside_direction * 10.0,
		Vector3.UP
	)
	target.set("developed", false)
	var equipped := bool(controller.call("request_equip"))
	_check(equipped, "Controller refused to equip for the assisted acquisition test")
	if equipped:
		_check(
			int(controller.get("state")) == FilmRevealController.State.EQUIPPING,
			"Equipping the card must enter EQUIPPING before scanning"
		)
		# Skip only the cosmetic wall-clock lift here. The separate timing test
		# exercises the controller's monotonic phase transitions end to end.
		controller.set("state", FilmRevealController.State.IDLE_NEGATIVE)
		controller.set("_equip_blend", 1.0)
		var half_dwell_s := float(profile.get("dwell_s")) * 0.5
		var first_scan_usec := Time.get_ticks_usec()
		controller.call(
			"_update_scanning",
			half_dwell_s,
			first_scan_usec
		)
		_check(
			int(controller.get("state")) == FilmRevealController.State.TARGET_REACTION,
			"Partial dwell must enter TARGET_REACTION"
		)
		var film_rect := controller.get("film_rect") as TextureRect
		var film_material := film_rect.material as ShaderMaterial if film_rect != null else null
		_check(film_material != null, "Cannot inspect aiming feedback without FilmCard material")
		if film_material != null:
			var aim_strength := float(film_material.get_shader_parameter(&"aim_strength"))
			var reveal_progress := float(film_material.get_shader_parameter(&"reveal_progress"))
			_check(
				aim_strength > 0.0 and aim_strength < 1.0,
				"Partial dwell must visibly strengthen the negative before reveal"
			)
			_check(
				is_zero_approx(reveal_progress),
				"TARGET_REACTION must not start the two-photo transformation"
			)
		controller.call(
			"_update_scanning",
			float(profile.get("dwell_s")) - half_dwell_s,
			first_scan_usec + int(round(half_dwell_s * 1_000_000.0))
		)
		_check(
			int(controller.get("state")) == FilmRevealController.State.CAMERA_LOCK,
			"One assisted dwell must enter CAMERA_LOCK"
		)
		_check(
			bool(controller.get("_owns_external_lock")),
			"Assisted acquisition did not retain Player lock ownership"
		)
		_check(
			bool(player.get("controls_locked")),
			"Assisted acquisition did not lock Player input"
		)
	controller.call("_abort_and_stow")
	_check(
		not bool(controller.get("_owns_external_lock")),
		"Assisted acquisition cleanup retained lock ownership"
	)
	_check(not bool(controller.call("is_equipped")), "Assisted acquisition cleanup did not stow")

	player.global_transform = saved_player_transform
	if head != null:
		head.transform = saved_head_transform
	camera.transform = saved_camera_local_transform
	target.set("developed", saved_target_developed)
	if player.has_method("set_external_input_locked"):
		player.call("set_external_input_locked", saved_player_locked)
	controller.set("target_collision_mask", saved_target_mask)
	controller.set("allow_angular_target_assist", saved_assist)


func _assert_terrain_geometry(terrain: Node3D, player: Node3D, target: Node3D) -> void:
	_check(
		terrain.has_method("get_film_reveal_hill_center_world"),
		"Terrain lacks get_film_reveal_hill_center_world()"
	)
	_check(
		terrain.has_method("get_film_reveal_crest_target_world"),
		"Terrain lacks get_film_reveal_crest_target_world()"
	)
	_check(
		terrain.has_method("get_film_reveal_crest_edge_offsets_m"),
		"Terrain lacks get_film_reveal_crest_edge_offsets_m()"
	)
	if (
		not terrain.has_method("get_film_reveal_hill_center_world")
		or not terrain.has_method("get_film_reveal_crest_target_world")
		or not terrain.has_method("get_film_reveal_crest_edge_offsets_m")
	):
		return

	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	_check(
		player_xz.distance_to(PLAYER_ORIGIN_XZ) <= 0.05,
		"Player XZ origin must be (0, 92), got %s" % player_xz
	)
	var hill_center_value: Variant = terrain.call("get_film_reveal_hill_center_world")
	_check(hill_center_value is Vector2, "Terrain hill center must be Vector2")
	if not hill_center_value is Vector2:
		return
	var hill_center := hill_center_value as Vector2
	var hill_vector := hill_center - player_xz
	_check(
		absf(hill_vector.length() - EXPECTED_HILL_DISTANCE_M) <= 0.05,
		"Hill center must be 92 m from player, got %.4f m" % hill_vector.length()
	)
	var expected_hill_direction := -MOON_DIRECTION_XZ.normalized()
	_check(
		hill_vector.normalized().dot(expected_hill_direction) >= 0.9999,
		"Hill center is not opposite the normalized moon direction"
	)

	var target_xz := Vector2(target.global_position.x, target.global_position.z)
	var crest_target_value: Variant = terrain.call("get_film_reveal_crest_target_world")
	_check(crest_target_value is Vector3, "Terrain crest target must be Vector3")
	if not crest_target_value is Vector3:
		return
	var crest_target := crest_target_value as Vector3
	_check(
		target.global_position.distance_to(crest_target) <= 0.05,
		"HorseHillTarget must use the terrain crest target, got %s expected %s"
		% [target.global_position, crest_target]
	)

	var offsets_value: Variant = terrain.call("get_film_reveal_crest_edge_offsets_m")
	_check(offsets_value is Vector2, "Terrain crest offsets must be Vector2")
	if not offsets_value is Vector2:
		return
	var crest_offsets := offsets_value as Vector2
	var forward_offset_m := crest_offsets.x
	var lateral_offset_m := crest_offsets.y
	_check(
		forward_offset_m >= 3.0 and forward_offset_m <= 10.0,
		"Crest forward offset must remain on the crown edge, got %.3f m"
		% forward_offset_m
	)
	_check(
		lateral_offset_m >= 16.0 and lateral_offset_m <= 20.0,
		"Crest lateral offset must remain on the readable screen-right edge, got %.3f m"
		% lateral_offset_m
	)

	var toward_player := (player_xz - hill_center).normalized()
	var hill_direction := -toward_player
	var hill_side := Vector2(-hill_direction.y, hill_direction.x)
	var screen_right := hill_side
	var expected_target_xz := (
		hill_center
		+ screen_right * lateral_offset_m
		+ toward_player * forward_offset_m
	)
	_check(
		target_xz.distance_to(expected_target_xz) <= 0.10,
		"Target does not match the reported crest-edge offsets: got %s expected %s"
		% [target_xz, expected_target_xz]
	)
	var player_to_target := target_xz - player_xz
	_check(
		player_to_target.normalized().dot(INITIAL_VIEW_FORWARD_XZ) < -0.50,
		"Crest target must be clearly behind the player's initial -Z view"
	)
	_check(
		StringName(target.get_meta(&"terrain_anchor_kind", &"")) == &"crest_edge",
		"HorseHillTarget terrain anchor metadata must be crest_edge"
	)
	var anchor_value: Variant = target.get_meta(&"terrain_anchor_world", null)
	_check(
		anchor_value is Vector3
		and (anchor_value as Vector3).distance_to(crest_target) <= 0.05,
		"HorseHillTarget terrain_anchor_world metadata is stale"
	)
	var metadata_offsets: Variant = target.get_meta(&"crest_edge_offsets_m", null)
	_check(
		metadata_offsets is Vector2
		and (metadata_offsets as Vector2).distance_to(crest_offsets) <= 0.001,
		"HorseHillTarget crest_edge_offsets_m metadata is stale"
	)
	if terrain.has_method("height_at_world"):
		var surface_y := float(terrain.call("height_at_world", target_xz.x, target_xz.y))
		_check(
			absf(target.global_position.y - surface_y) <= 0.05,
			"Target origin must lie on the final terrain surface"
		)
	if terrain.has_method("normal_at_world"):
		var surface_normal := (
			terrain.call("normal_at_world", target_xz.x, target_xz.y, 0.75) as Vector3
		).normalized()
		var target_outward := target.global_transform.basis.z.normalized()
		_check(
			target_outward.dot(surface_normal) >= 0.9999,
			"Target outward axis must follow the final terrain normal"
		)


func _assert_particles(
	barrage: Node3D,
	controller: CanvasLayer,
	particles: GPUParticles3D
) -> void:
	var performance_mode := int(barrage.get("quality_profile")) == 1
	var expected_amount := 180 if performance_mode else 320
	_check(
		particles.amount == expected_amount,
		"Particle amount must be %d for this profile, got %d"
		% [expected_amount, particles.amount]
	)
	_check(
		absf(particles.amount_ratio - 0.12) <= 0.0001,
		"Particle amount_ratio must start at 0.12, got %.4f" % particles.amount_ratio
	)
	if controller.has_method("_set_target_reaction_strength"):
		controller.call("_set_target_reaction_strength", 1.0)
		_check(
			absf(particles.amount_ratio - 0.35) <= 0.005,
			"Particle aim amount_ratio must be about 0.35, got %.4f"
			% particles.amount_ratio
		)
	if controller.has_method("_set_radiation_intensity"):
		controller.call("_set_radiation_intensity", 1.0)
		_check(
			absf(particles.amount_ratio - 1.0) <= 0.005,
			"Particle peak amount_ratio must reach 1.0, got %.4f"
			% particles.amount_ratio
		)
		_check(
			absf(particles.speed_scale - 1.12) <= 0.005,
			"Particle peak speed must be about 1.12, got %.4f" % particles.speed_scale
		)
		var geiger := controller.get("geiger_emitter") as GeigerClickEmitter
		_check(geiger != null, "Controller Geiger emitter assignment is missing")
		if geiger != null:
			_check(
				is_equal_approx(geiger.intensity, 1.0),
				"Geiger intensity must reach 1.0 at the reveal peak"
			)
		var hum := controller.get("low_frequency_hum") as AudioStreamPlayer
		_check(hum != null, "Controller low-frequency hum assignment is missing")
		if hum != null:
			_check(
				absf(hum.volume_db - (-27.0)) <= 0.001,
				"Low-frequency hum peak must be +7 dB, got %.3f dB" % hum.volume_db
			)
		controller.call("_set_radiation_intensity", 0.0)
		if hum != null:
			_check(
				absf(hum.volume_db - (-34.0)) <= 0.001,
				"Low-frequency hum did not return to its -34 dB baseline"
			)


func _assert_player_interfaces(
	player: Node3D,
	camera: Camera3D,
	controller: CanvasLayer
) -> void:
	var has_lock_method := player.has_method("set_external_input_locked")
	var has_sync_method := player.has_method("sync_view_from_camera")
	_check(has_lock_method, "Player lacks set_external_input_locked()")
	_check(has_sync_method, "Player lacks sync_view_from_camera()")
	if (
		has_lock_method
		and has_sync_method
		and controller.has_method("_acquire_external_lock")
		and controller.has_method("_release_external_lock")
	):
		controller.call("_acquire_external_lock")
		_check(bool(controller.get("_owns_external_lock")), "Controller did not retain lock ownership")
		_check(bool(player.get("controls_locked")), "Controller did not lock the Player")
		camera.transform = Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(-5.0), deg_to_rad(9.0), 0.0)),
			Vector3(0.01, -0.02, 0.03)
		)
		controller.call("_release_external_lock", true)
		_check(not bool(controller.get("_owns_external_lock")), "Controller retained stale lock ownership")
		_check(not bool(player.get("controls_locked")), "Controller did not unlock the Player")
		_check(
			_is_identity_transform(camera.transform),
			"Controller unlock must resynchronize and reset the camera local transform"
		)
	if has_lock_method:
		player.call("set_external_input_locked", true)
		_check(bool(player.get("controls_locked")), "Player did not acquire external input lock")
		player.call("set_external_input_locked", false)
		_check(not bool(player.get("controls_locked")), "Player did not release external input lock")
	if not has_sync_method:
		return

	camera.transform = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(-7.0), deg_to_rad(11.0), 0.0)),
		Vector3(0.02, -0.01, 0.03)
	)
	var shaken_world_transform := camera.global_transform
	player.call("sync_view_from_camera", shaken_world_transform)
	_check(
		_is_identity_transform(camera.transform),
		"sync_view_from_camera() must restore the camera local transform to identity"
	)


func _assert_final_reveal_hold_contract(
	controller: CanvasLayer,
	target: Node3D,
	player: Node3D,
	camera: Camera3D,
	film_card: TextureRect,
	original_texture: Texture2D
) -> void:
	if (
		not controller.has_signal("final_reveal_reached")
		or not controller.has_method("request_post_reveal_hold")
		or not controller.has_method("_finish_reveal")
	):
		return

	var game_state := get_root().get_node_or_null("GameState")
	var archive_snapshot: Dictionary = {}
	if game_state != null and game_state.get("_film_archive") is Dictionary:
		archive_snapshot = (game_state.get("_film_archive") as Dictionary).duplicate()
	var saved_target_developed := bool(target.get("developed"))
	var saved_player_locked := bool(player.get("controls_locked"))
	var saved_player_transform := player.global_transform
	var head := camera.get_parent() as Node3D
	var saved_head_transform := head.transform if head != null else Transform3D.IDENTITY
	var saved_camera_transform := camera.transform

	target.set("developed", false)
	_check(bool(controller.call("request_equip")), "Completion-hold test could not equip film")
	controller.set("_equip_blend", 1.0)
	controller.set("state", FilmRevealController.State.REVEALING_TO_ORIGINAL)
	controller.call("_apply_film_card_transform")
	controller.set("_camera_lock_to", camera.global_transform)
	controller.set("_final_reveal_emitted", false)
	controller.call("_acquire_external_lock")

	var signal_capture := {
		"count": 0,
		"film_id": StringName(),
		"texture": null,
		"hold_accepted": false,
		"shader_progress": -1.0,
	}
	var final_callback := func(film_id: StringName, texture: Texture2D) -> void:
		signal_capture["count"] = int(signal_capture["count"]) + 1
		signal_capture["film_id"] = film_id
		signal_capture["texture"] = texture
		signal_capture["hold_accepted"] = bool(
			controller.call("request_post_reveal_hold", 1.45)
		)
		var material := film_card.material as ShaderMaterial
		if material != null:
			signal_capture["shader_progress"] = float(
				material.get_shader_parameter(&"reveal_progress")
			)
	controller.connect(
		&"final_reveal_reached",
		final_callback,
		Object.CONNECT_ONE_SHOT
	)
	var equipment_capture := {"false_count": 0}
	var equipment_callback := func(equipped: bool) -> void:
		if not equipped:
			equipment_capture["false_count"] = int(equipment_capture["false_count"]) + 1
	controller.connect(
		&"equipment_changed",
		equipment_callback,
		Object.CONNECT_ONE_SHOT
	)

	var completion_usec := Time.get_ticks_usec()
	controller.call("_finish_reveal", completion_usec)
	_check(int(signal_capture["count"]) == 1, "Final reveal signal must emit exactly once")
	_check(
		StringName(signal_capture["film_id"]) == FILM_ID,
		"Final reveal signal used the wrong film id"
	)
	_check(
		signal_capture["texture"] == original_texture,
		"Final reveal signal must carry original_revealed.png"
	)
	_check(
		bool(signal_capture["hold_accepted"]),
		"Synchronous manifestation hold request was rejected"
	)
	_check(
		is_equal_approx(float(signal_capture["shader_progress"]), 1.0),
		"Final reveal signal fired before reveal_progress reached 1.0"
	)
	var deadline_usec := int(controller.get("_unlock_deadline_usec"))
	_check(
		abs(deadline_usec - completion_usec - 1_800_000) <= 2,
		"Manifestation 1.45 s + post-hold 0.35 s deadline is incorrect"
	)
	_check(
		bool(controller.call("request_post_reveal_hold", 0.50)),
		"A shorter concurrent hold request should be accepted"
	)
	_check(
		int(controller.get("_unlock_deadline_usec")) == deadline_usec,
		"Longest-wins hold contract was shortened by a second listener"
	)

	controller.call("_update_complete", deadline_usec - 1)
	_check(bool(controller.call("is_equipped")), "Film stowed before final hold deadline")
	_check(bool(controller.get("_owns_external_lock")), "Lock released before final hold deadline")
	controller.call("_update_complete", deadline_usec)
	_check(
		bool(controller.get("_completion_stow_in_progress")),
		"Final deadline did not begin the non-immediate card stow"
	)
	_check(not bool(controller.call("is_equipped")), "Completion stow did not lower the film")
	_check(
		int(equipment_capture["false_count"]) == 1,
		"Completion stow must emit equipment_changed(false) once"
	)
	_check(
		bool(controller.get("_owns_external_lock")) and bool(player.get("controls_locked")),
		"Completion stow released input lock while the card was still up"
	)
	controller.call("_update_completion_stow")
	_check(
		bool(controller.get("_owns_external_lock")),
		"Completion stow released input lock before equip blend reached zero"
	)
	controller.set("_equip_blend", 0.0)
	controller.call("_update_completion_stow")
	_check(not bool(controller.get("_owns_external_lock")), "Completion stow retained stale lock")
	_check(not bool(player.get("controls_locked")), "Completion stow retained Player lock")
	_check(not film_card.visible, "FilmCard remained visible after completion stow")
	_check(
		not bool(controller.call("request_post_reveal_hold", 1.05)),
		"Manifestation hold was accepted after completion lock ended"
	)
	controller.call("_finish_reveal", completion_usec + 2_000_000)
	_check(int(signal_capture["count"]) == 1, "Final reveal signal emitted more than once")

	if game_state != null:
		game_state.set("_film_archive", archive_snapshot)
	target.set("developed", saved_target_developed)
	controller.set("_reveal_progress", 1.0 if saved_target_developed else 0.0)
	controller.call("_set_shader_float", &"reveal_progress", controller.get("_reveal_progress"))
	player.global_transform = saved_player_transform
	if head != null:
		head.transform = saved_head_transform
	camera.transform = saved_camera_transform
	if player.has_method("set_external_input_locked"):
		player.call("set_external_input_locked", saved_player_locked)


func _assert_wall_clock_timeline(
	controller: CanvasLayer,
	target: Node3D,
	player: Node3D,
	camera: Camera3D
) -> void:
	var game_state := get_root().get_node_or_null("GameState")
	var riders := controller.get_parent().get_node_or_null(
		"RidersManifestation"
	) as RidersManifestation
	var archive_snapshot: Dictionary = {}
	if game_state != null and game_state.get("_film_archive") is Dictionary:
		archive_snapshot = (game_state.get("_film_archive") as Dictionary).duplicate()

	target.set("developed", false)
	if not bool(controller.call("is_equipped")):
		_check(bool(controller.call("request_equip")), "Wall-clock test could not equip film")
	controller.set("_equip_blend", 1.0)
	controller.set("state", FilmRevealController.State.IDLE_NEGATIVE)
	controller.call("_apply_film_card_transform")
	var original_time_scale := Engine.time_scale
	Engine.time_scale = 0.05
	var started_usec := Time.get_ticks_usec()
	controller.call("_begin_camera_lock", started_usec)
	var saw_camera_lock := false
	var saw_reveal := false
	var saw_post_hold := false
	var saw_completion_stow := false
	var stow_rejected_during_lock := true
	var timed_out := false

	while bool(controller.get("_owns_external_lock")):
		var current_state := int(controller.get("state"))
		saw_camera_lock = (
			saw_camera_lock or current_state == FilmRevealController.State.CAMERA_LOCK
		)
		saw_reveal = (
			saw_reveal
			or current_state == FilmRevealController.State.REVEALING_TO_ORIGINAL
		)
		saw_post_hold = saw_post_hold or (
			current_state == FilmRevealController.State.REVEALED
			and int(controller.get("_unlock_deadline_usec")) >= 0
		)
		saw_completion_stow = (
			saw_completion_stow
			or bool(controller.get("_completion_stow_in_progress"))
		)
		stow_rejected_during_lock = (
			stow_rejected_during_lock and not bool(controller.call("request_stow", true))
		)
		_check(
			bool(player.get("controls_locked")),
			"Player input lock was released before post-hold completed"
		)
		controller.call("_process", 0.0)
		if riders != null and bool(riders.get("_manifesting")):
			# The smoke test disables the barrage root to freeze unrelated shells;
			# drive this one monotonic component explicitly under that test-only pause.
			riders.call("_process", 0.0)
		if Time.get_ticks_usec() - started_usec > 8_000_000:
			timed_out = true
			controller.call("_abort_and_stow")
			break
		await create_timer(0.005, true, false, true).timeout

	var elapsed_s := float(Time.get_ticks_usec() - started_usec) / 1_000_000.0
	Engine.time_scale = original_time_scale
	_check(not timed_out, "Wall-clock reveal timeline exceeded 8 seconds")
	_check(saw_camera_lock, "Wall-clock test did not enter CAMERA_LOCK")
	_check(saw_reveal, "Wall-clock test did not enter REVEALING")
	_check(saw_post_hold, "Wall-clock test did not retain lock through post-hold")
	_check(saw_completion_stow, "Wall-clock test did not retain lock through card stow")
	_check(stow_rejected_during_lock, "Slot 4 stow was accepted while the camera lock was owned")
	_check(
		absf(elapsed_s - 7.185) <= 0.32,
		"0.085 + 0.28 + 4.80 + 1.45 + 0.35 + 0.22 second timeline took %.3f wall seconds"
		% elapsed_s
	)
	_check(riders != null, "Integrated wall-clock test lacks RidersManifestation")
	if riders != null:
		_check(
			riders.riders_manifested
			and riders.white_rider.visible
			and riders.black_rider.visible,
			"Riders were not fully materialized before film stow and camera unlock"
		)
	_check(not bool(player.get("controls_locked")), "Player remained locked after post-hold")
	_check(not bool(controller.call("is_equipped")), "Film remained equipped after completion stow")
	_check(
		_is_identity_transform(camera.transform),
		"Camera local transform was not reset after the wall-clock reveal"
	)
	_check(bool(target.get("developed")), "Completed wall-clock reveal did not develop target")
	if target.has_method("can_reveal"):
		_check(not bool(target.call("can_reveal")), "One-shot target can reveal more than once")
	if game_state != null:
		_check(
			bool(game_state.call("is_film_archived", FILM_ID)),
			"Completed wall-clock reveal did not archive the film"
		)
		var archived_texture := game_state.call(
			"get_archived_film_texture",
			FILM_ID
		) as Texture2D
		_check(
			archived_texture != null
			and archived_texture.resource_path == ORIGINAL_TEXTURE_PATH,
			"Completed reveal must archive original_revealed.png, not the negative"
		)
		game_state.set("_film_archive", archive_snapshot)
	target.set("developed", false)


func _assert_game_state_round_trip(
	barrage: Node3D,
	terrain: Node3D,
	player: Node3D,
	controller: CanvasLayer,
	texture: Texture2D
) -> void:
	var game_state := get_root().get_node_or_null("GameState")
	_check(game_state != null, "GameState autoload is missing")
	if game_state == null:
		return
	for method_name in ["archive_film", "is_film_archived", "get_archived_film_texture"]:
		_check(game_state.has_method(method_name), "GameState lacks %s()" % method_name)
	if not (
		game_state.has_method("archive_film")
		and game_state.has_method("is_film_archived")
		and game_state.has_method("get_archived_film_texture")
	):
		return

	var archive_before: Variant = game_state.get("_film_archive")
	var can_restore := archive_before is Dictionary
	var archive_snapshot: Dictionary = {}
	if can_restore:
		archive_snapshot = (archive_before as Dictionary).duplicate()

	controller.emit_signal(&"film_archived", FILM_ID, texture)
	_check(
		bool(game_state.call("is_film_archived", FILM_ID)),
		"Controller film_archived signal did not reach GameState"
	)
	_check(
		game_state.call("get_archived_film_texture", FILM_ID) == texture,
		"GameState did not return the archived texture"
	)
	var hydrated_target: Node3D
	if barrage.has_method("_create_horse_hill_target"):
		hydrated_target = barrage.call(
			"_create_horse_hill_target",
			terrain,
			player
		) as Node3D
		_check(hydrated_target != null, "Could not construct a target for archive hydration")
		if hydrated_target != null:
			_check(
				bool(hydrated_target.get("developed")),
				"New HorseHillTarget did not hydrate developed state from GameState"
			)
	if (
		hydrated_target != null
		and barrage.has_method("_create_riders_manifestation")
	):
		var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
		var hydrated_riders := barrage.call(
			"_create_riders_manifestation",
			terrain,
			hydrated_target,
			player,
			camera
		) as RidersManifestation
		_check(hydrated_riders != null, "Could not construct riders for archive hydration")
		if hydrated_riders != null:
			_check(
				hydrated_riders.riders_manifested
				and hydrated_riders.white_rider.visible
				and hydrated_riders.black_rider.visible,
				"Archived scene hydration did not restore both riders immediately"
			)
			hydrated_riders.queue_free()
	if hydrated_target != null:
		hydrated_target.queue_free()
	if can_restore:
		game_state.set("_film_archive", archive_snapshot)
		_check(
			game_state.get("_film_archive") == archive_snapshot,
			"GameState archive snapshot was not restored after the round-trip"
		)


func _assert_float_property(
	instance: Object,
	property_name: StringName,
	expected: float,
	tolerance: float = 0.0001
) -> void:
	if not _has_property(instance, property_name):
		_fail("%s lacks property %s" % [instance.get_class(), property_name])
		return
	var actual := float(instance.get(property_name))
	_check(
		absf(actual - expected) <= tolerance,
		"%s.%s must be %.4f, got %.4f"
		% [instance.get_class(), property_name, expected, actual]
	)


func _assert_int_property(instance: Object, property_name: StringName, expected: int) -> void:
	if not _has_property(instance, property_name):
		_fail("%s lacks property %s" % [instance.get_class(), property_name])
		return
	var actual := int(instance.get(property_name))
	_check(
		actual == expected,
		"%s.%s must be %d, got %d"
		% [instance.get_class(), property_name, expected, actual]
	)


func _has_property(instance: Object, property_name: StringName) -> bool:
	for property in instance.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _is_identity_transform(value: Transform3D) -> bool:
	return (
		value.origin.length() <= 0.000001
		and value.basis.x.distance_to(Vector3.RIGHT) <= 0.000001
		and value.basis.y.distance_to(Vector3.UP) <= 0.000001
		and value.basis.z.distance_to(Vector3.BACK) <= 0.000001
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failure_count += 1
	push_error("[FilmRevealSmoke] %s" % message)


func _finish(barrage: Node) -> void:
	var exit_code := 0 if _failure_count == 0 else 1
	if exit_code == 0:
		print(
			"FILM_REVELATION_INTEGRATION_SMOKE_PASS profile=%s"
			% ["performance" if _scene_path == PERFORMANCE_SCENE_PATH else "cinematic"]
		)
	else:
		print("FILM_REVELATION_INTEGRATION_SMOKE_FAIL failures=", _failure_count)
	barrage.queue_free()
	await process_frame
	await process_frame
	quit(exit_code)
