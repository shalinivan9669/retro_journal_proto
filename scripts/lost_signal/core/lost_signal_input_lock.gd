extends Node

signal lock_changed(locked: bool, owners: Array[StringName])

var _owners: Dictionary = {}


func acquire(owner: StringName) -> void:
	if owner == StringName():
		push_warning("LostSignalInputLock: empty owner ignored")
		return
	_owners[owner] = int(_owners.get(owner, 0)) + 1
	_emit_changed()


func release(owner: StringName) -> void:
	if not _owners.has(owner):
		return
	var count := int(_owners[owner]) - 1
	if count <= 0:
		_owners.erase(owner)
	else:
		_owners[owner] = count
	_emit_changed()


func release_all(owner: StringName) -> void:
	if _owners.erase(owner):
		_emit_changed()


func clear() -> void:
	if _owners.is_empty():
		return
	_owners.clear()
	_emit_changed()


func is_locked() -> bool:
	return not _owners.is_empty()


func is_locked_by(owner: StringName) -> bool:
	return _owners.has(owner)


func owners() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in _owners.keys():
		result.append(StringName(key))
	return result


func _emit_changed() -> void:
	lock_changed.emit(is_locked(), owners())
