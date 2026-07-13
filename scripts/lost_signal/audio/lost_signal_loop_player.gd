class_name LostSignalLoopPlayer
extends AudioStreamPlayer


func _exit_tree() -> void:
	stop()
	stream = null
