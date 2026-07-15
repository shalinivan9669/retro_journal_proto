class_name FilmRevealController
extends CanvasLayer

## Reusable one-film/one-target controller. It owns no player-controller logic:
## connect the lock signals, or assign input_lock_receiver and implement the
## documented two small methods on the player.

signal input_lock_requested(locked: bool)
signal equipment_changed(equipped: bool)
signal aim_progress_changed(progress: float)
signal reveal_started(film_id: StringName)
signal reveal_progress_changed(film_id: StringName, progress: float)
signal final_reveal_reached(film_id: StringName, texture: Texture2D)
signal radiation_intensity_changed(intensity: float)
signal film_archived(film_id: StringName, texture: Texture2D)

enum State {
	STOWED,
	EQUIPPING,
	IDLE_NEGATIVE,
	TARGET_REACTION,
	CAMERA_LOCK,
	REVEALING_TO_ORIGINAL,
	REVEALED,
}

const LARGE_WALL_GAP_S := 0.25
const CARD_HEIGHT_RATIO := 0.58
const CARD_BOTTOM_MARGIN_RATIO := 0.0555556
const AIM_INDICATOR_SIZE_PX := 4.0
const TARGET_REACTION_RADIATION_PEAK := 0.18
const PARTICLE_AMOUNT_PEAK_MULTIPLIER := 1.40
const HUM_PEAK_BOOST_DB := 3.5
const DEFAULT_POST_REVEAL_HOLD_S := 1.05

@export var profile: FilmRevealProfile
@export var camera: Camera3D
@export var film_rect: TextureRect
@export var revealed_texture: Texture2D
@export var target: FilmRevealTarget
@export var input_lock_receiver: Node
@export var geiger_emitter: GeigerClickEmitter
@export var low_frequency_hum: AudioStreamPlayer
@export var radiation_particles: GPUParticles3D
@export var aim_indicator: Control
@export_flags_3d_physics var target_collision_mask: int = 1 << 26
@export_flags_3d_physics var occlusion_collision_mask: int = 0
@export var allow_angular_target_assist: bool = true

var state: State = State.STOWED
var _equipped: bool = false
var _equip_blend: float = 0.0
var _candidate_latched: bool = false
var _dwell_s: float = 0.0
var _reveal_progress: float = 0.0

var _last_wall_usec: int = 0
var _visual_clock_origin_usec: int = 0
var _visual_clock_s: float = 0.0
var _phase_started_usec: int = 0
var _unlock_deadline_usec: int = -1
var _completion_reached_usec: int = -1
var _post_reveal_extra_hold_s: float = 0.0
var _completion_stow_in_progress: bool = false
var _final_reveal_emitted: bool = false
var _application_focused: bool = true
var _owns_external_lock: bool = false

var _film_material: ShaderMaterial
var _film_base_position: Vector2
var _film_base_rotation: float
var _film_base_modulate: Color
var _card_shake_offset := Vector2.ZERO
var _card_shake_rotation: float = 0.0
var _camera_lock_from: Transform3D
var _camera_lock_to: Transform3D
var _particles_base_amount_ratio: float = 1.0
var _particles_base_speed_scale: float = 1.0
var _hum_base_volume_db: float = 0.0
var _aim_indicator_base_modulate := Color.WHITE
var _aim_indicator_base_scale := Vector2.ONE


func _enter_tree() -> void:
	add_to_group(&"film_reveal_controller")


func _ready() -> void:
	_last_wall_usec = Time.get_ticks_usec()
	_visual_clock_origin_usec = _last_wall_usec
	if profile == null:
		profile = FilmRevealProfile.new()
	if not is_instance_valid(film_rect):
		push_error("FilmRevealController: film_rect is required")
		set_process(false)
		return

	_film_base_rotation = film_rect.rotation
	_film_base_modulate = film_rect.modulate
	film_rect.visible = false
	film_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	film_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if film_rect.material is ShaderMaterial:
		_film_material = (film_rect.material as ShaderMaterial).duplicate() as ShaderMaterial
		film_rect.material = _film_material
	else:
		push_error("FilmRevealController: film_rect needs film_reveal.gdshader")

	if is_instance_valid(radiation_particles):
		_particles_base_amount_ratio = radiation_particles.amount_ratio
		_particles_base_speed_scale = radiation_particles.speed_scale
	if is_instance_valid(low_frequency_hum):
		_hum_base_volume_db = low_frequency_hum.volume_db
	if is_instance_valid(aim_indicator):
		_aim_indicator_base_modulate = aim_indicator.modulate
		_aim_indicator_base_scale = aim_indicator.scale
		aim_indicator.custom_minimum_size = Vector2.ONE * AIM_INDICATOR_SIZE_PX
		aim_indicator.size = Vector2.ONE * AIM_INDICATOR_SIZE_PX
		aim_indicator.pivot_offset = Vector2.ONE * (AIM_INDICATOR_SIZE_PX * 0.5)

	var viewport := get_viewport()
	var resize_callback := Callable(self, "_update_film_layout")
	if is_instance_valid(viewport) and not viewport.size_changed.is_connected(resize_callback):
		viewport.size_changed.connect(resize_callback)
	_update_film_layout()
	_update_aim_indicator(0.0, false)

	_set_shader_float(&"reveal_progress", 1.0 if is_instance_valid(target) and target.developed else 0.0)
	_set_shader_float(&"ghost_amount", profile.undeveloped_trace)
	_set_shader_float(&"film_opacity", profile.film_opacity)
	_set_shader_float(&"exposure_gain", profile.exposure_gain)
	_set_shader_float(&"bleach_low", profile.bleach_low)
	_set_shader_float(&"bleach_high", profile.bleach_high)
	_set_shader_float(&"aim_strength", 0.0)
	_set_shader_texture(&"original_revealed_texture", revealed_texture)
	_set_shader_float(&"equip_alpha", 0.0)


func _exit_tree() -> void:
	_clear_completion_hold_state()
	_set_radiation_intensity(0.0)
	_release_external_lock(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
		_reset_acquisition()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true
		_last_wall_usec = Time.get_ticks_usec()
		_reset_acquisition()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_slot_four_event(event):
		return
	get_viewport().set_input_as_handled()
	if _equipped:
		request_stow()
	else:
		request_equip()


func _process(_delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	if _last_wall_usec <= 0:
		_last_wall_usec = now_usec
	var wall_delta_s := maxf(float(now_usec - _last_wall_usec) / 1000000.0, 0.0)
	_last_wall_usec = now_usec
	var acquisition_delta_s := wall_delta_s
	if wall_delta_s > LARGE_WALL_GAP_S:
		_reset_acquisition()
		acquisition_delta_s = 0.0

	_visual_clock_s = float(now_usec - _visual_clock_origin_usec) / 1000000.0
	_set_shader_float(&"time_sec", _visual_clock_s)
	_update_equip_animation(wall_delta_s)
	_update_completion_stow()

	if (_equipped or _owns_external_lock) and not _active_references_are_valid():
		_abort_and_stow()
		return

	match state:
		State.STOWED:
			pass
		State.EQUIPPING:
			_update_equipping_state()
		State.IDLE_NEGATIVE, State.TARGET_REACTION:
			_update_scanning(acquisition_delta_s, now_usec)
		State.CAMERA_LOCK:
			_update_camera_lock(now_usec)
		State.REVEALING_TO_ORIGINAL:
			_update_reveal(now_usec)
		State.REVEALED:
			_update_complete(now_usec)


func request_equip() -> bool:
	if _switching_is_locked():
		return false
	if _equipped:
		return true
	if not _active_references_are_valid():
		return false
	_set_equipped_internal(true, false)
	return true


func request_stow(immediate: bool = false) -> bool:
	if _switching_is_locked():
		return false
	if not _equipped:
		if immediate:
			_snap_card_stowed()
		return true
	_set_equipped_internal(false, immediate)
	return true


func is_equipped() -> bool:
	return _equipped


func request_post_reveal_hold(extra_hold_s: float = DEFAULT_POST_REVEAL_HOLD_S) -> bool:
	if (
		state != State.REVEALED
		or not _final_reveal_emitted
		or not _owns_external_lock
		or _completion_reached_usec < 0
		or _completion_stow_in_progress
		or not is_finite(extra_hold_s)
		or extra_hold_s < 0.0
	):
		return false
	# Multiple listeners may need the same completion window. Longest-wins keeps
	# their requests deterministic and prevents accidental additive lock stacking.
	_post_reveal_extra_hold_s = maxf(
		_post_reveal_extra_hold_s,
		clampf(extra_hold_s, 0.0, 10.0)
	)
	_schedule_completion_deadline()
	return true


func configure_film(
	new_texture: Texture2D,
	new_target: FilmRevealTarget,
	new_profile: FilmRevealProfile = null,
	new_revealed_texture: Texture2D = null
) -> bool:
	if _switching_is_locked():
		return false
	if new_texture == null or not is_instance_valid(new_target) or not is_instance_valid(film_rect):
		return false
	if new_profile != null:
		profile = new_profile
	film_rect.texture = new_texture
	if new_revealed_texture != null:
		revealed_texture = new_revealed_texture
	_set_shader_texture(&"original_revealed_texture", revealed_texture)
	target = new_target
	_reset_acquisition()
	_reveal_progress = 1.0 if target.developed else 0.0
	_set_shader_float(&"reveal_progress", _reveal_progress)
	_set_shader_float(&"ghost_amount", profile.undeveloped_trace)
	_set_shader_float(&"film_opacity", profile.film_opacity)
	_set_shader_float(&"exposure_gain", profile.exposure_gain)
	_set_shader_float(&"bleach_low", profile.bleach_low)
	_set_shader_float(&"bleach_high", profile.bleach_high)
	state = _state_for_equipped_target() if _equipped else State.STOWED
	_update_aim_indicator(0.0, _equipped and _is_scanning_state())
	return true


func _set_equipped_internal(value: bool, immediate: bool) -> void:
	if _equipped == value:
		if not value and immediate:
			_snap_card_stowed()
		return
	_equipped = value
	_reset_acquisition()
	if _equipped:
		film_rect.visible = true
		state = State.EQUIPPING
		_reveal_progress = 1.0 if target.developed else 0.0
		_set_shader_float(&"reveal_progress", _reveal_progress)
		_update_aim_indicator(0.0, false)
	else:
		state = State.STOWED
		_update_aim_indicator(0.0, false)
		if immediate:
			_snap_card_stowed()
	equipment_changed.emit(_equipped)


func _state_for_equipped_target() -> State:
	if is_instance_valid(target) and target.one_shot and target.developed:
		return State.REVEALED
	return State.IDLE_NEGATIVE


func _switching_is_locked() -> bool:
	return (
		state == State.CAMERA_LOCK
		or state == State.REVEALING_TO_ORIGINAL
		or _unlock_deadline_usec >= 0
		or _completion_stow_in_progress
		or _owns_external_lock
	)


func _is_scanning_state() -> bool:
	return state == State.IDLE_NEGATIVE or state == State.TARGET_REACTION


func _update_equipping_state() -> void:
	if _equip_blend < 0.999:
		return
	state = _state_for_equipped_target()
	_update_aim_indicator(0.0, _is_scanning_state())


func _active_references_are_valid() -> bool:
	return (
		is_instance_valid(film_rect)
		and is_instance_valid(camera)
		and camera.is_inside_tree()
		and camera.get_world_3d() != null
		and is_instance_valid(target)
		and target.is_inside_tree()
	)


func _update_scanning(delta_s: float, now_usec: int) -> void:
	if not _application_focused:
		_reset_acquisition()
		return
	if not target.can_reveal():
		state = State.REVEALED
		_reset_acquisition()
		_update_aim_indicator(0.0, false)
		return

	var threshold_deg := profile.release_angle_deg if _candidate_latched else profile.acquire_angle_deg
	var target_is_valid := _is_target_under_crosshair(threshold_deg)
	if target_is_valid:
		_candidate_latched = true
		_dwell_s = minf(_dwell_s + delta_s, profile.dwell_s)
	else:
		_dwell_s = maxf(0.0, _dwell_s - delta_s * profile.dwell_decay_multiplier)
		if _dwell_s <= 0.0:
			_candidate_latched = false
	var dwell_ratio := _dwell_s / maxf(profile.dwell_s, 0.001)
	var angular_strength := _get_angular_aim_strength()
	var target_reaction_strength := angular_strength * dwell_ratio
	state = State.TARGET_REACTION if target_reaction_strength > 0.001 else State.IDLE_NEGATIVE
	_set_target_reaction_strength(target_reaction_strength)
	aim_progress_changed.emit(dwell_ratio)
	_update_aim_indicator(dwell_ratio, true)
	if dwell_ratio >= 1.0:
		_begin_camera_lock(now_usec)


func _begin_camera_lock(now_usec: int) -> void:
	if not _active_references_are_valid():
		_abort_and_stow()
		return
	state = State.CAMERA_LOCK
	_phase_started_usec = now_usec
	_dwell_s = 0.0
	aim_progress_changed.emit(1.0)
	_update_aim_indicator(1.0, false)
	_set_target_reaction_strength(1.0)
	_camera_lock_from = camera.global_transform
	_camera_lock_to = camera.global_transform.looking_at(target.get_aim_point(), Vector3.UP)
	_acquire_external_lock()


func _update_camera_lock(now_usec: int) -> void:
	if not _active_references_are_valid():
		_abort_and_stow()
		return
	var phase_s := float(now_usec - _phase_started_usec) / 1000000.0
	var linear_t := clampf(phase_s / maxf(profile.camera_lock_s, 0.001), 0.0, 1.0)
	var eased_t := 1.0 - pow(1.0 - linear_t, 3.0)
	var from_q := _camera_lock_from.basis.get_rotation_quaternion()
	var to_q := _camera_lock_to.basis.get_rotation_quaternion()
	var frame := _camera_lock_from
	frame.basis = Basis(from_q.slerp(to_q, eased_t))
	camera.global_transform = frame
	if linear_t >= 1.0:
		camera.global_transform = _camera_lock_to
		_begin_reveal(now_usec)


func _begin_reveal(now_usec: int) -> void:
	if not _active_references_are_valid():
		_abort_and_stow()
		return
	state = State.REVEALING_TO_ORIGINAL
	_phase_started_usec = now_usec
	_reveal_progress = 0.0
	_clear_completion_hold_state()
	_final_reveal_emitted = false
	_set_target_reaction_strength(0.0)
	reveal_started.emit(target.film_id)
	_set_shader_float(&"reveal_active", 1.0)


func _update_reveal(now_usec: int) -> void:
	if not _active_references_are_valid():
		_abort_and_stow()
		return
	var phase_s := float(now_usec - _phase_started_usec) / 1000000.0
	_reveal_progress = clampf(phase_s / maxf(profile.reveal_s, 0.001), 0.0, 1.0)
	_set_shader_float(&"reveal_progress", _reveal_progress)
	reveal_progress_changed.emit(target.film_id, _reveal_progress)

	var envelope := _reveal_envelope(_reveal_progress)
	var radiation := profile.radiation_peak * envelope
	_set_radiation_intensity(radiation)
	_apply_card_shake(envelope)
	_apply_camera_shake(envelope)

	if _reveal_progress >= 1.0:
		_finish_reveal(now_usec)


func _finish_reveal(now_usec: int) -> void:
	if not _active_references_are_valid():
		_abort_and_stow()
		return
	if _final_reveal_emitted:
		return
	state = State.REVEALED
	_final_reveal_emitted = true
	_completion_reached_usec = now_usec
	_post_reveal_extra_hold_s = 0.0
	_completion_stow_in_progress = false
	_schedule_completion_deadline()
	_reveal_progress = 1.0
	_set_shader_float(&"reveal_progress", 1.0)
	_set_shader_float(&"reveal_active", 0.0)
	_set_radiation_intensity(0.0)
	_card_shake_offset = Vector2.ZERO
	_card_shake_rotation = 0.0
	camera.global_transform = _camera_lock_to
	target.mark_developed()
	var archive_texture := revealed_texture if revealed_texture != null else film_rect.texture
	# Emitted synchronously after the final image/target state is committed. A
	# manifestation listener can request_post_reveal_hold(1.05) from this callback.
	final_reveal_reached.emit(target.film_id, archive_texture)
	film_archived.emit(target.film_id, archive_texture)


func _update_complete(now_usec: int) -> void:
	if _unlock_deadline_usec >= 0 and now_usec >= _unlock_deadline_usec:
		_begin_completion_stow()


func _schedule_completion_deadline() -> void:
	if _completion_reached_usec < 0:
		return
	var total_hold_s := (
		_post_reveal_extra_hold_s
		+ maxf(profile.post_lock_hold_s, 0.0)
	)
	_unlock_deadline_usec = (
		_completion_reached_usec
		+ int(round(total_hold_s * 1000000.0))
	)


func _begin_completion_stow() -> void:
	if _completion_stow_in_progress:
		return
	_unlock_deadline_usec = -1
	_completion_stow_in_progress = true
	if _equipped:
		_equipped = false
		_reset_acquisition()
		_update_aim_indicator(0.0, false)
		equipment_changed.emit(false)


func _update_completion_stow() -> void:
	if not _completion_stow_in_progress or _equip_blend > 0.001:
		return
	_completion_stow_in_progress = false
	_completion_reached_usec = -1
	_post_reveal_extra_hold_s = 0.0
	state = State.STOWED
	_snap_card_stowed()
	_release_external_lock(true)


func _clear_completion_hold_state() -> void:
	_unlock_deadline_usec = -1
	_completion_reached_usec = -1
	_post_reveal_extra_hold_s = 0.0
	_completion_stow_in_progress = false


func _get_angular_aim_strength() -> float:
	if not is_instance_valid(camera) or not is_instance_valid(target):
		return 0.0
	var to_target := target.get_aim_point() - camera.global_position
	var distance_m := to_target.length()
	if distance_m <= 0.001 or distance_m > profile.maximum_target_distance_m:
		return 0.0
	var camera_forward := -camera.global_transform.basis.z.normalized()
	var angular_error_deg := rad_to_deg(acos(clampf(
		camera_forward.dot(to_target / distance_m),
		-1.0,
		1.0
	)))
	return 1.0 - smoothstep(
		profile.acquire_angle_deg,
		profile.release_angle_deg,
		angular_error_deg
	)


func _is_target_under_crosshair(angle_threshold_deg: float) -> bool:
	var camera_origin := camera.global_position
	var camera_forward := -camera.global_transform.basis.z.normalized()
	var to_target := target.get_aim_point() - camera_origin
	var distance_m := to_target.length()
	if distance_m <= 0.001 or distance_m > profile.maximum_target_distance_m:
		return false
	var target_direction := to_target / distance_m
	var angular_error_rad := acos(clampf(camera_forward.dot(target_direction), -1.0, 1.0))
	if angular_error_rad > deg_to_rad(angle_threshold_deg):
		return false

	var query := PhysicsRayQueryParameters3D.create(
		camera_origin,
		camera_origin + camera_forward * profile.maximum_target_distance_m,
		target_collision_mask
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_target_area := (
		not hit.is_empty() and target.accepts_collider(hit.get("collider"))
	)
	# The physical area remains the primary hit test, but a generous angular
	# assist makes acquisition reliable on low resolutions and uneven terrain.
	# Distance, the target's exact aim marker, and optional occlusion are still
	# enforced, so unrelated terrain cannot become a reveal target.
	if not hit_target_area and not allow_angular_target_assist:
		return false

	if occlusion_collision_mask != 0:
		var occlusion_query := PhysicsRayQueryParameters3D.create(
			camera_origin,
			target.get_aim_point(),
			occlusion_collision_mask
		)
		occlusion_query.collide_with_areas = false
		occlusion_query.collide_with_bodies = true
		var obstruction := camera.get_world_3d().direct_space_state.intersect_ray(occlusion_query)
		if not obstruction.is_empty():
			var obstruction_distance := camera_origin.distance_to(obstruction.get("position", camera_origin))
			if obstruction_distance < distance_m - 0.65:
				return false
	return true


func _apply_card_shake(envelope: float) -> void:
	var x_noise := sin(_visual_clock_s * 41.7) * 0.58 + sin(_visual_clock_s * 73.1 + 1.4) * 0.27
	var y_noise := sin(_visual_clock_s * 47.3 + 2.2) * 0.54 + sin(_visual_clock_s * 89.7) * 0.25
	var rotation_noise := sin(_visual_clock_s * 29.3 + 0.7) * 0.68 + sin(_visual_clock_s * 61.9) * 0.22
	_card_shake_offset = Vector2(x_noise, y_noise) * profile.film_shake_px * envelope
	_card_shake_rotation = deg_to_rad(rotation_noise * profile.film_tilt_deg * envelope)


func _apply_camera_shake(envelope: float) -> void:
	if not is_instance_valid(camera):
		return
	var pitch := deg_to_rad(sin(_visual_clock_s * 36.1) * profile.camera_shake_deg * envelope)
	var yaw := deg_to_rad(sin(_visual_clock_s * 31.7 + 1.1) * profile.camera_shake_deg * envelope)
	var frame := _camera_lock_to
	frame.basis = frame.basis * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
	frame.origin += frame.basis * Vector3(
		sin(_visual_clock_s * 27.9) * profile.camera_shake_m * envelope,
		sin(_visual_clock_s * 42.7 + 0.4) * profile.camera_shake_m * 0.55 * envelope,
		0.0
	)
	camera.global_transform = frame


func _update_equip_animation(delta_s: float) -> void:
	if not is_instance_valid(film_rect):
		return
	var target_blend := 1.0 if _equipped else 0.0
	_equip_blend = move_toward(_equip_blend, target_blend, delta_s / maxf(profile.equip_time_s, 0.001))
	_apply_film_card_transform()


func _apply_film_card_transform() -> void:
	if not is_instance_valid(film_rect):
		return
	var eased_blend := 1.0 - pow(1.0 - _equip_blend, 3.0)
	film_rect.position = _film_base_position + Vector2(0.0, profile.stow_offset_px * (1.0 - eased_blend)) + _card_shake_offset
	film_rect.rotation = _film_base_rotation + _card_shake_rotation
	_set_shader_float(&"equip_alpha", eased_blend * _film_base_modulate.a)
	if not _equipped and _equip_blend <= 0.001:
		film_rect.visible = false


func _snap_card_stowed() -> void:
	_equip_blend = 0.0
	_card_shake_offset = Vector2.ZERO
	_card_shake_rotation = 0.0
	_apply_film_card_transform()
	if is_instance_valid(film_rect):
		film_rect.visible = false


func _update_film_layout() -> void:
	if not is_instance_valid(film_rect):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var side := viewport_size.y * CARD_HEIGHT_RATIO
	var bottom_margin := viewport_size.y * CARD_BOTTOM_MARGIN_RATIO
	film_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	film_rect.size = Vector2(side, side)
	_film_base_position = Vector2(
		(viewport_size.x - side) * 0.5,
		viewport_size.y - bottom_margin - side
	)
	_apply_film_card_transform()


func _update_aim_indicator(progress: float, should_show: bool) -> void:
	if not is_instance_valid(aim_indicator):
		return
	var normalized := clampf(progress, 0.0, 1.0)
	var acquired_tint := _aim_indicator_base_modulate.lerp(
		Color(0.56, 1.0, 0.78, _aim_indicator_base_modulate.a),
		normalized
	)
	aim_indicator.visible = should_show
	aim_indicator.modulate = Color(
		acquired_tint.r,
		acquired_tint.g,
		acquired_tint.b,
		_aim_indicator_base_modulate.a * lerpf(0.35, 1.0, normalized)
	)
	aim_indicator.scale = _aim_indicator_base_scale * lerpf(0.75, 1.5, normalized)


func _reset_acquisition() -> void:
	_dwell_s = 0.0
	_candidate_latched = false
	if state == State.TARGET_REACTION:
		state = State.IDLE_NEGATIVE
	_set_target_reaction_strength(0.0)
	aim_progress_changed.emit(0.0)
	_update_aim_indicator(0.0, _equipped and _is_scanning_state() and _application_focused)


func _set_target_reaction_strength(value: float) -> void:
	var normalized := clampf(value, 0.0, 1.0)
	_set_shader_float(&"aim_strength", normalized)
	_set_radiation_intensity(normalized * TARGET_REACTION_RADIATION_PEAK)


func _set_radiation_intensity(value: float) -> void:
	var normalized := clampf(value, 0.0, 1.0)
	if is_instance_valid(geiger_emitter):
		geiger_emitter.intensity = normalized
	if is_instance_valid(radiation_particles):
		var particle_peak := minf(
			_particles_base_amount_ratio * PARTICLE_AMOUNT_PEAK_MULTIPLIER,
			1.0
		)
		radiation_particles.amount_ratio = lerpf(
			_particles_base_amount_ratio,
			particle_peak,
			normalized
		)
		radiation_particles.speed_scale = _particles_base_speed_scale * lerpf(1.0, 1.12, normalized)
	if is_instance_valid(low_frequency_hum):
		low_frequency_hum.volume_db = _hum_base_volume_db + HUM_PEAK_BOOST_DB * normalized
	radiation_intensity_changed.emit(normalized)


func _acquire_external_lock() -> void:
	if _owns_external_lock:
		return
	_owns_external_lock = true
	input_lock_requested.emit(true)
	if is_instance_valid(input_lock_receiver) and input_lock_receiver.has_method("set_external_input_locked"):
		input_lock_receiver.call("set_external_input_locked", true)


func _release_external_lock(sync_view: bool) -> void:
	if not _owns_external_lock:
		return
	if sync_view and is_instance_valid(input_lock_receiver) and is_instance_valid(camera):
		if input_lock_receiver.has_method("sync_view_from_camera"):
			input_lock_receiver.call("sync_view_from_camera", camera.global_transform)
	if is_instance_valid(input_lock_receiver) and input_lock_receiver.has_method("set_external_input_locked"):
		input_lock_receiver.call("set_external_input_locked", false)
	input_lock_requested.emit(false)
	_owns_external_lock = false


func _abort_and_stow() -> void:
	_clear_completion_hold_state()
	_set_shader_float(&"reveal_active", 0.0)
	_set_radiation_intensity(0.0)
	_card_shake_offset = Vector2.ZERO
	_card_shake_rotation = 0.0
	_release_external_lock(true)
	if _equipped:
		_set_equipped_internal(false, true)
	else:
		state = State.STOWED
		_snap_card_stowed()


func _reveal_envelope(progress: float) -> float:
	var attack := smoothstep(0.02, 0.16, progress)
	var release := 1.0 - smoothstep(0.84, 1.0, progress)
	return attack * release


func _set_shader_float(parameter: StringName, value: float) -> void:
	if is_instance_valid(_film_material):
		_film_material.set_shader_parameter(parameter, value)


func _set_shader_texture(parameter: StringName, value: Texture2D) -> void:
	if is_instance_valid(_film_material):
		_film_material.set_shader_parameter(parameter, value)


func _is_slot_four_event(event: InputEvent) -> bool:
	if InputMap.has_action(profile.slot_action) and event.is_action_pressed(profile.slot_action):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and (
			key_event.physical_keycode == KEY_4 or key_event.keycode == KEY_4
		)
	return false
