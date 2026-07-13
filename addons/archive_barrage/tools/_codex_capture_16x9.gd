extends Node3D

const BARRAGE := preload("res://addons/archive_barrage/scenes/ArchiveNightBarrage.tscn")


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	add_child(BARRAGE.instantiate())
