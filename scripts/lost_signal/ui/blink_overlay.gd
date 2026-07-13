class_name LostSignalBlinkOverlay
extends CanvasLayer

signal full_dark
signal blink_finished

const LOCK_OWNER: StringName = &"lost_signal_blink"

@export_range(0.03, 1.0, 0.01) var close_duration := 0.15
@export_range(0.0, 1.0, 0.01) var hold_duration := 0.08
@export_range(0.03, 1.0, 0.01) var open_duration := 0.20

var _mask: LostSignalEyelidMask
var _busy := false


func _ready() -> void:
	layer = 175
	_mask = LostSignalEyelidMask.new()
	_mask.name = "CurvedEyelidMask"
	add_child(_mask)
	visible = false


func is_busy() -> bool:
	return _busy


func blink(custom_hold := -1.0) -> void:
	if _busy:
		return
	_busy = true
	visible = true
	LostSignalInputLock.acquire(LOCK_OWNER)
	var close_tween := create_tween()
	close_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_tween.tween_property(_mask, "closure", 1.0, close_duration)
	await close_tween.finished
	full_dark.emit()
	var actual_hold := hold_duration if custom_hold < 0.0 else custom_hold
	if actual_hold > 0.0:
		await get_tree().create_timer(actual_hold).timeout
	var open_tween := create_tween()
	open_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(_mask, "closure", 0.0, open_duration)
	await open_tween.finished
	visible = false
	_busy = false
	LostSignalInputLock.release_all(LOCK_OWNER)
	blink_finished.emit()


func _exit_tree() -> void:
	LostSignalInputLock.release_all(LOCK_OWNER)
