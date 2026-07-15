class_name WomanWaitressRoute
extends Node3D

const IDLE_CLIP: StringName = &"Idle_Elegant"
const WALK_CLIP: StringName = &"Walk_Catwalk_InPlace"
const LONGEST_CLIP: StringName = &"Approach_Turn_Look_Leave"
const WALK_REFERENCE_SPEED := 1.02

@export_range(0.2, 5.0, 0.05) var walking_speed := 1.65
@export_range(0.0, 1.0, 0.01) var animation_blend := 0.16

var performer: Node3D
var animation_player: AnimationPlayer


func configure(model: Node3D) -> void:
	performer = model
	animation_player = _find_animation_player(model)
	_configure_loop(IDLE_CLIP, true)
	_configure_loop(WALK_CLIP, true)
	_configure_loop(LONGEST_CLIP, false)
	play_idle()


func play_idle() -> void:
	_play_clip(IDLE_CLIP)


func play_gesture(clip: StringName) -> void:
	_play_clip(clip)


func walk_points(points: Array[Vector3], speed := -1.0) -> void:
	if points.is_empty():
		return
	var resolved_speed := walking_speed if speed <= 0.0 else speed
	_play_clip(WALK_CLIP, -1.0, resolved_speed / WALK_REFERENCE_SPEED)
	for target in points:
		if not is_inside_tree():
			return
		await _walk_segment(target, resolved_speed)
	play_idle()


func play_longest_sequence(facing_yaw: float) -> void:
	rotation.y = facing_yaw
	_play_clip(LONGEST_CLIP, 0.12)
	var duration := _clip_length(LONGEST_CLIP)
	if duration <= 0.0:
		duration = 9.0
	await get_tree().create_timer(duration).timeout
	if is_inside_tree():
		play_idle()


func _walk_segment(target: Vector3, speed: float) -> void:
	var start := position
	var horizontal := target - start
	horizontal.y = 0.0
	var distance := horizontal.length()
	if distance <= 0.001:
		position = target
		return
	var duration := distance / maxf(speed, 0.01)
	var start_yaw := rotation.y
	var target_yaw := atan2(horizontal.x, horizontal.z)
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
		var ratio := clampf(elapsed / duration, 0.0, 1.0)
		var eased := ratio * ratio * (3.0 - 2.0 * ratio)
		position = start.lerp(target, eased)
		rotation.y = lerp_angle(start_yaw, target_yaw, minf(ratio * 3.5, 1.0))
	position = target
	rotation.y = target_yaw


func _play_clip(clip: StringName, blend := -1.0, speed := 1.0) -> void:
	var resolved_blend := animation_blend if blend < 0.0 else blend
	if performer != null and performer.has_method("play_clip"):
		performer.call("play_clip", clip, resolved_blend, speed)
		return
	if animation_player == null:
		return
	var resolved := _resolve_clip(clip)
	if resolved != &"":
		animation_player.play(resolved, resolved_blend, speed)


func _clip_length(clip: StringName) -> float:
	if animation_player == null:
		return 0.0
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return 0.0
	var animation := animation_player.get_animation(resolved)
	return animation.length if animation != null else 0.0


func _configure_loop(clip: StringName, looped: bool) -> void:
	if animation_player == null:
		return
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	var animation := animation_player.get_animation(resolved)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE


func _resolve_clip(requested: StringName) -> StringName:
	if animation_player == null:
		return &""
	if animation_player.has_animation(requested):
		return requested
	var suffix := "/" + String(requested)
	for candidate in animation_player.get_animation_list():
		var candidate_text := String(candidate)
		if candidate_text.ends_with(suffix) or candidate_text.ends_with(String(requested)):
			return candidate
	return &""


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
