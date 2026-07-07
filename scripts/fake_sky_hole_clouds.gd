extends Node3D

@export var rotation_speed: float = 0.16
@export var cloud_spin_speed: float = -0.08


func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)

	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("Cloud"):
			(child as MeshInstance3D).rotate_y(cloud_spin_speed * delta)
