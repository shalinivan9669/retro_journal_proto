extends Node

const ALBASTY_RITUAL_HIDE_SECONDS := 480.0

var albasty_ritual_completed := false
var albasty_hidden_until_msec := 0


func pacify_albasty_from_blood_ritual() -> void:
	albasty_ritual_completed = true
	albasty_hidden_until_msec = Time.get_ticks_msec() + int(ALBASTY_RITUAL_HIDE_SECONDS * 1000.0)
	for node in get_tree().get_nodes_in_group("albasty"):
		if node != null and is_instance_valid(node):
			node.queue_free()


func is_albasty_hidden_by_ritual() -> bool:
	return albasty_ritual_completed and Time.get_ticks_msec() < albasty_hidden_until_msec


func is_albasty_peaceful_after_ritual() -> bool:
	return albasty_ritual_completed and not is_albasty_hidden_by_ritual()
