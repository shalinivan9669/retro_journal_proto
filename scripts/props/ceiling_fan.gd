extends Node3D

@export var enabled := true
@export var max_speed_deg := 420.0
@export var acceleration := 720.0

var _rotor: Node3D
var _current_speed_deg := 0.0


func _ready() -> void:
	_rotor = _find_rotor(self)


func _process(delta: float) -> void:
	if _rotor == null:
		return
	var target_speed := max_speed_deg if enabled else 0.0
	_current_speed_deg = move_toward(_current_speed_deg, target_speed, acceleration * delta)
	_rotor.rotate_y(deg_to_rad(_current_speed_deg * delta))


func _find_rotor(node: Node) -> Node3D:
	for child in node.get_children():
		if child is Node3D and "blade" in child.name.to_lower():
			return child as Node3D
		var nested := _find_rotor(child)
		if nested != null:
			return nested
	return null
