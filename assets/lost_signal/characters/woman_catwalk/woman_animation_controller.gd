class_name WomanAnimationController
extends Node3D

@export var autoplay := true
@export var initial_clip: StringName = &"Idle_Elegant"
@export_range(0.0, 1.0, 0.01) var default_blend := 0.18

var animation_player: AnimationPlayer

const LOOPED_CLIPS: Array[StringName] = [
	&"Idle_Elegant",
	&"Walk_Catwalk_InPlace",
]


func _ready() -> void:
	animation_player = _find_animation_player(self)
	if animation_player == null:
		push_error("WomanAnimationController: AnimationPlayer was not found in the imported GLB.")
		return
	_configure_loop_modes()
	if autoplay:
		play_clip(initial_clip, 0.0)


func play_clip(clip: StringName, blend: float = -1.0, speed: float = 1.0) -> bool:
	if animation_player == null:
		return false
	if blend < 0.0:
		blend = default_blend
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		push_warning("WomanAnimationController: clip '%s' was not found." % clip)
		return false
	animation_player.play(resolved, blend, speed)
	return true


func play_idle() -> bool:
	return play_clip(&"Idle_Elegant")


func play_walk_in_place() -> bool:
	return play_clip(&"Walk_Catwalk_InPlace")


func play_forward() -> bool:
	return play_clip(&"Walk_Catwalk_Forward_Root")


func play_backward() -> bool:
	return play_clip(&"Walk_Backward_Root")


func play_away() -> bool:
	return play_clip(&"Walk_Away_Root")


func turn_left() -> bool:
	return play_clip(&"Turn_180_Left")


func turn_right() -> bool:
	return play_clip(&"Turn_180_Right")


func look_back() -> bool:
	return play_clip(&"Look_Back_Over_Shoulder")


func play_full_sequence() -> bool:
	return play_clip(&"Approach_Turn_Look_Leave", 0.12)


func _configure_loop_modes() -> void:
	for requested in LOOPED_CLIPS:
		var resolved := _resolve_clip(requested)
		if resolved == &"":
			continue
		var animation := animation_player.get_animation(resolved)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR


func _resolve_clip(requested: StringName) -> StringName:
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
