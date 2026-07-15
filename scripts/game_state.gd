extends Node

const ALBASTY_RITUAL_HIDE_SECONDS := 600.0

signal film_archived(film_id: StringName, texture: Texture2D)

var albasty_ritual_completed := false
var albasty_hidden_until_msec := 0

# Session-persistent archive film progression. This autoload already survives
# scene transitions, so a separate inventory/save singleton is unnecessary.
var film_01_collected := false
var film_01_viewed := false
var film_01_fully_revealed := false

var _film_archive: Dictionary = {}


func archive_film(id: StringName, texture: Texture2D) -> void:
	_film_archive[id] = texture
	film_archived.emit(id, texture)


func is_film_archived(id: StringName) -> bool:
	return _film_archive.has(id)


func get_archived_film_texture(id: StringName) -> Texture2D:
	return _film_archive.get(id) as Texture2D


func pacify_albasty_from_blood_ritual() -> void:
	albasty_ritual_completed = true
	albasty_hidden_until_msec = Time.get_ticks_msec() + int(ALBASTY_RITUAL_HIDE_SECONDS * 1000.0)
	for node in get_tree().get_nodes_in_group("albasty"):
		if node != null and is_instance_valid(node):
			node.queue_free()


func is_albasty_hidden_by_ritual() -> bool:
	if not albasty_ritual_completed:
		return false
	if Time.get_ticks_msec() < albasty_hidden_until_msec:
		return true
	albasty_ritual_completed = false
	albasty_hidden_until_msec = 0
	return false


func is_albasty_peaceful_after_ritual() -> bool:
	return false
