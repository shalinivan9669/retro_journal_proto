extends Area3D
class_name HorseGuardZone

signal albasty_entered(albasty: Node3D)

@export var albasty_group: StringName = &"albasty"

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_node_entered)
	area_entered.connect(_on_node_entered)


func _on_node_entered(node: Node) -> void:
	if _triggered:
		return

	var albasty := _find_albasty_root(node)
	if albasty == null:
		return

	_triggered = true
	albasty_entered.emit(albasty)
	if albasty.has_method("on_horse_zone_reached"):
		albasty.call("on_horse_zone_reached")
	else:
		print("Albasty reached horses")


func _find_albasty_root(node: Node) -> Node3D:
	var current := node
	while current != null:
		if current.is_in_group(albasty_group) and current is Node3D:
			return current as Node3D
		current = current.get_parent()
	return null
