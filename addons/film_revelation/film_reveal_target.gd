class_name FilmRevealTarget
extends Node3D

## Put this node on the special hill. The hit area should sit 0.3-0.6 m in
## front of the visible slope so the terrain collider cannot steal the ray hit.

@export var film_id: StringName = &"two_white_horses"
@export var aim_marker: Node3D
@export var hit_area: CollisionObject3D
@export var one_shot: bool = true
@export var developed: bool = false

func get_aim_point() -> Vector3:
	return aim_marker.global_position if is_instance_valid(aim_marker) else global_position

func accepts_collider(collider: Object) -> bool:
	if not is_instance_valid(hit_area) or not is_instance_valid(collider):
		return false
	if collider == hit_area:
		return true
	return collider is Node and hit_area.is_ancestor_of(collider as Node)

func can_reveal() -> bool:
	return not (one_shot and developed)

func mark_developed() -> void:
	developed = true

