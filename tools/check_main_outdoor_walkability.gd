extends SceneTree

const WALK_SPEED := 4.0
const GRAVITY := 16.0

var _scene: Node3D
var _player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load Main.tscn.")
		quit(1)
		return

	_scene = packed.instantiate() as Node3D
	var visual_runtime := _scene.get_node_or_null("VisualEffectsRuntime")
	if visual_runtime != null:
		visual_runtime.get_parent().remove_child(visual_runtime)
		visual_runtime.free()

	var steppe_environment := _scene.get_node_or_null("SteppeEnvironment")
	if steppe_environment != null:
		steppe_environment.set("enable_albasty_prototype", false)

	root.add_child(_scene)
	current_scene = _scene
	await process_frame
	await physics_frame

	_player = _scene.get_node_or_null("Player") as CharacterBody3D
	if _player == null:
		push_error("Main.tscn has no Player.")
		quit(1)
		return

	_player.set_physics_process(false)
	_player.global_position = Vector3(0.0, 0.05, 3.0)
	await physics_frame

	var waypoints: Array[Vector3] = [
		Vector3(0.0, 0.0, -8.2),
		Vector3(0.0, 0.0, -13.0),
		Vector3(0.0, 0.0, -24.0),
		Vector3(3.0, 0.0, -39.0),
		Vector3(8.0, 0.0, -58.0),
		Vector3(2.0, 0.0, -78.0)
	]

	for index in range(waypoints.size()):
		var ok := await _walk_to(waypoints[index])
		if not ok:
			push_error("Main outdoor walkability failed at waypoint %d target=%s current=%s" % [index, waypoints[index], _player.global_position])
			quit(1)
			return

	print("Main outdoor walkability probe reached outdoor path.")
	quit(0)


func _walk_to(target: Vector3) -> bool:
	var stuck_timer := 0.0
	var last_position := _player.global_position

	for _step in range(720):
		await physics_frame
		var offset := target - _player.global_position
		offset.y = 0.0
		if offset.length() <= 0.28:
			_player.velocity = Vector3.ZERO
			return true

		var assisted := false
		if _player.has_method("_apply_landscape_ground_assist"):
			assisted = bool(_player.call("_apply_landscape_ground_assist", true))

		var direction := offset.normalized()
		if not assisted and not _player.is_on_floor():
			_player.velocity.y -= GRAVITY / 60.0
		else:
			_player.velocity.y = -0.1
		_player.velocity.x = direction.x * WALK_SPEED
		_player.velocity.z = direction.z * WALK_SPEED
		_player.move_and_slide()

		if _player.has_method("_apply_landscape_ground_assist"):
			_player.call("_apply_landscape_ground_assist", false)

		if _player.global_position.y < -4.0:
			_print_collisions()
			return false

		var moved := (_player.global_position - last_position).length()
		if moved < 0.003:
			stuck_timer += 1.0 / 60.0
			if stuck_timer > 1.0:
				_print_collisions()
				return false
		else:
			stuck_timer = 0.0
			last_position = _player.global_position

	return false


func _print_collisions() -> void:
	print("player_position=", _player.global_position, " on_floor=", _player.is_on_floor(), " velocity=", _player.velocity)
	for index in range(_player.get_slide_collision_count()):
		var collision := _player.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as Node
		var collider_name := "<unknown>"
		if collider != null:
			collider_name = collider.name
		print("collision ", index, " collider=", collider_name, " normal=", collision.get_normal(), " point=", collision.get_position())
