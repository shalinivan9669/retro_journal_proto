extends SceneTree

const MAZE := [
	"###############",
	"#S#.#.........#",
	"#.#.#.#.#####.#",
	"#.#...#....o#.#",
	"#.#.#######.#.#",
	"#.#.#...#...#l#",
	"#.#.###.#.###.#",
	"#.#.....#.#...#",
	"#.#.#####.#.###",
	"#l#.#..h#.#...#",
	"#.###.#.#.###.#",
	"#.....#...#..E#",
	"###############"
]

const STANDING_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const PLAYER_RADIUS := 0.35
const GRAVITY := 16.0
const WALK_SPEED := 4.0

var _body: CharacterBody3D
var _shape: CapsuleShape3D
var _collision: CollisionShape3D
var _level: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/levels/UndergroundSteppe.tscn") as PackedScene
	if packed == null:
		push_error("Could not load UndergroundSteppe.")
		quit(1)
		return

	_level = packed.instantiate() as Node3D
	root.add_child(_level)
	await process_frame
	await physics_frame

	var scene_player := _level.get_node_or_null("Player")
	if scene_player != null:
		scene_player.queue_free()
	var return_hatch := _level.get_node_or_null("ReturnHatch")
	if return_hatch != null:
		return_hatch.queue_free()
	await process_frame
	await physics_frame

	_create_probe()
	_set_probe_height(STANDING_HEIGHT)
	_body.global_position = Vector3(0.0, 0.05, 6.2)
	await physics_frame

	var waypoints: Array[Vector3] = [
		Vector3(0.0, 0.0, 4.5),
		Vector3(0.0, -1.866667, -0.82),
		Vector3(0.0, -1.866667, -1.92),
		Vector3(4.9, -3.2, -1.92),
		Vector3(6.0, -3.2, -1.92)
	]
	var crouch_flags: Array[bool] = [false, false, false, false, false]

	var maze_path := _find_maze_path()
	if maze_path.is_empty():
		push_error("No BFS path from S to E.")
		quit(1)
		return

	for path_index in range(maze_path.size()):
		var cell: Vector2i = maze_path[path_index]
		var waypoint: Vector3 = _level.call("_maze_cell_to_world", cell)
		waypoints.append(waypoint)
		crouch_flags.append(_needs_crouch_for_path_index(maze_path, path_index))

	for index in range(waypoints.size()):
		_set_probe_height(CROUCH_HEIGHT if crouch_flags[index] else STANDING_HEIGHT)
		var ok := await _walk_to(waypoints[index])
		if not ok:
			push_error("Walkability failed at waypoint %d: %s current=%s" % [index, waypoints[index], _body.global_position])
			quit(1)
			return

	print("Underground walkability probe reached E.")
	quit(0)


func _create_probe() -> void:
	_body = CharacterBody3D.new()
	_body.name = "WalkabilityProbe"
	_body.floor_snap_length = 0.6
	root.add_child(_body)

	_collision = CollisionShape3D.new()
	_shape = CapsuleShape3D.new()
	_shape.radius = PLAYER_RADIUS
	_shape.height = STANDING_HEIGHT
	_collision.shape = _shape
	_collision.position.y = STANDING_HEIGHT * 0.5
	_body.add_child(_collision)


func _set_probe_height(height: float) -> void:
	_shape.height = height
	_collision.position.y = height * 0.5


func _walk_to(target: Vector3) -> bool:
	var stuck_timer := 0.0
	var last_position := _body.global_position

	for _step in range(420):
		await physics_frame
		var offset := target - _body.global_position
		offset.y = 0.0
		if offset.length() <= 0.22:
			_body.velocity = Vector3.ZERO
			return true

		var direction := offset.normalized()
		if _body.is_on_floor():
			_body.velocity.y = -0.1
		else:
			_body.velocity.y -= GRAVITY / 60.0
		_body.velocity.x = direction.x * WALK_SPEED
		_body.velocity.z = direction.z * WALK_SPEED
		_body.move_and_slide()

		if _body.global_position.y < -8.0:
			return false

		var moved := (_body.global_position - last_position).length()
		if moved < 0.003:
			stuck_timer += 1.0 / 60.0
			if stuck_timer > 1.0:
				_print_collisions()
				return false
		else:
			stuck_timer = 0.0
			last_position = _body.global_position

	return false


func _print_collisions() -> void:
	print("probe_position=", _body.global_position, " on_floor=", _body.is_on_floor(), " velocity=", _body.velocity)
	for index in range(_body.get_slide_collision_count()):
		var collision := _body.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as Node
		var collider_name := "<unknown>"
		if collider != null:
			collider_name = collider.name
		print("collision ", index, " collider=", collider_name, " normal=", collision.get_normal(), " point=", collision.get_position())


func _find_maze_path() -> Array[Vector2i]:
	var start := Vector2i.ZERO
	var exit := Vector2i.ZERO
	for y in range(MAZE.size()):
		for x in range(MAZE[y].length()):
			var cell := _maze_cell(x, y)
			if cell == "S":
				start = Vector2i(x, y)
			elif cell == "E":
				exit = Vector2i(x, y)

	var queue: Array[Vector2i] = [start]
	var came_from := {}
	came_from[_cell_key(start)] = start
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == exit:
			break

		for direction in directions:
			var next: Vector2i = current + direction
			if not _is_in_maze(next.x, next.y):
				continue
			if _maze_cell(next.x, next.y) == "#":
				continue
			var key := _cell_key(next)
			if came_from.has(key):
				continue
			came_from[key] = current
			queue.append(next)

	if not came_from.has(_cell_key(exit)):
		return []

	var path: Array[Vector2i] = []
	var current := exit
	while current != start:
		path.push_front(current)
		current = came_from[_cell_key(current)]
	path.push_front(start)
	return path


func _needs_crouch_for_path_index(path: Array[Vector2i], index: int) -> bool:
	for offset in range(-1, 2):
		var check_index := index + offset
		if check_index < 0 or check_index >= path.size():
			continue
		var cell := path[check_index]
		if _maze_cell(cell.x, cell.y) == "l":
			return true
	return false


func _is_in_maze(x: int, y: int) -> bool:
	if y < 0 or y >= MAZE.size():
		return false
	return x >= 0 and x < MAZE[y].length()


func _maze_cell(x: int, y: int) -> String:
	return MAZE[y].substr(x, 1)


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
