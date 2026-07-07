extends Node3D

const CONCRETE_MATERIAL: Material = preload("res://materials/mat_underground_concrete.tres")
const WET_GRASS_MATERIAL: Material = preload("res://materials/mat_underground_wet_grass.tres")
const WATER_MATERIAL: Material = preload("res://materials/mat_underground_water.tres")
const FLOWER_WHITE_MATERIAL: Material = preload("res://materials/mat_underground_flower_white.tres")
const FAKE_SKY_SCRIPT: Script = preload("res://scripts/fake_sky_hole_clouds.gd")

const GRASS_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_grass_patch.glb"
const FLOWER_WHITE_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_flower_white.glb"
const CLOUD_TEXTURE_DIR := "res://assets/textures/sky/clouds_runtime_clean"

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

const TILE_SIZE := 3.0
const WALL_HEIGHT_BASE := 2.4
const WALL_THICKNESS := 0.28
const LOW_CEILING_HEIGHT := 1.32
const NORMAL_CEILING_HEIGHT := 2.35
const HIGH_CEILING_HEIGHT := 4.2
const CEILING_THICKNESS := 0.24

const TOP_PLATFORM_CENTER := Vector3(0.0, 0.0, 6.2)
const TOP_PLATFORM_SIZE := Vector3(4.2, 0.18, 3.4)
const STAIR_VERTICAL_DROP := 3.2
const STAIR_STEP_COUNT := 24
const STAIR_STEP_HEIGHT := STAIR_VERTICAL_DROP / STAIR_STEP_COUNT
const STAIR_STEP_DEPTH := 0.38
const STAIR_FIRST_RUN_STEPS := 14
const STAIR_SECOND_RUN_STEPS := 10
const STAIR_WIDTH := 2.2
const STAIR_WALKABLE_WIDTH := 2.0
const STAIR_LANDING_SIZE := 2.2
const STAIR_SLAB_THICKNESS := 0.16
const MAZE_FLOOR_Y := -STAIR_VERTICAL_DROP
const MAZE_ENTRY_OFFSET := Vector3(6.0, 0.0, 0.0)

@export_range(0.0, 3.0, 0.1) var flower_density_multiplier: float = 1.0
@export_file("*.tscn") var return_scene_path: String = "res://scenes/Main.tscn"

var _generated_root: Node3D
var _maze_start_cell := Vector2i.ZERO
var _maze_exit_cell := Vector2i.ZERO
var _maze_origin := Vector3.ZERO
var _maze_col_axis := Vector3(0.0, 0.0, -TILE_SIZE)
var _maze_row_axis := Vector3(TILE_SIZE, 0.0, 0.0)
var _passable_cells: Array[Vector2i] = []


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not _validate_maze_path():
		return
	_build_level()
	_position_player_at_entry()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().change_scene_to_file(return_scene_path)


func _build_level() -> void:
	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedUndergroundSteppe"
	add_child(_generated_root)

	_build_entry_stairs()
	_configure_maze_origin()
	_build_stair_to_maze_connector()
	_build_maze()
	_build_water()
	_build_vegetation()
	_build_exit_marker()


func _position_player_at_entry() -> void:
	var player := get_node_or_null("Player") as Node3D
	if player == null:
		return

	player.global_position = TOP_PLATFORM_CENTER + Vector3(0.0, 0.04, 0.0)
	player.rotation = Vector3.ZERO


func _build_entry_stairs() -> void:
	_add_static_box("EntryConcretePlatform", TOP_PLATFORM_SIZE, TOP_PLATFORM_CENTER + Vector3(0.0, -TOP_PLATFORM_SIZE.y * 0.5, 0.0), CONCRETE_MATERIAL)

	var first_start_z := TOP_PLATFORM_CENTER.z - TOP_PLATFORM_SIZE.z * 0.5
	var first_end_z := first_start_z - float(STAIR_FIRST_RUN_STEPS) * STAIR_STEP_DEPTH
	var landing_y := -float(STAIR_FIRST_RUN_STEPS) * STAIR_STEP_HEIGHT
	var landing_z := first_end_z - STAIR_LANDING_SIZE * 0.5
	var second_start_x := STAIR_LANDING_SIZE * 0.5
	var second_end_x := second_start_x + float(STAIR_SECOND_RUN_STEPS) * STAIR_STEP_DEPTH

	_add_walkable_ramp(
		"StairFirstRunWalkableRamp",
		Vector3(0.0, 0.0, first_start_z),
		Vector3(0.0, landing_y, first_end_z),
		STAIR_WALKABLE_WIDTH,
		CONCRETE_MATERIAL
	)
	_add_walkable_ramp(
		"StairSecondRunWalkableRamp",
		Vector3(second_start_x, landing_y, landing_z),
		Vector3(second_end_x, MAZE_FLOOR_Y, landing_z),
		STAIR_WALKABLE_WIDTH,
		CONCRETE_MATERIAL
	)

	for step_index in range(STAIR_FIRST_RUN_STEPS):
		var step_top_y := -float(step_index + 1) * STAIR_STEP_HEIGHT
		var center := Vector3(
			0.0,
			step_top_y - STAIR_SLAB_THICKNESS * 0.5,
			first_start_z - (float(step_index) + 0.5) * STAIR_STEP_DEPTH
		)
		_add_mesh_box("StairFirstRunVisual_%02d" % step_index, Vector3(STAIR_WIDTH, STAIR_SLAB_THICKNESS, STAIR_STEP_DEPTH + 0.02), center, CONCRETE_MATERIAL)

	_add_static_box(
		"StairTurnLanding",
		Vector3(STAIR_LANDING_SIZE, STAIR_SLAB_THICKNESS, STAIR_LANDING_SIZE),
		Vector3(0.0, landing_y - STAIR_SLAB_THICKNESS * 0.5, landing_z),
		CONCRETE_MATERIAL
	)

	for step_index in range(STAIR_SECOND_RUN_STEPS):
		var total_step := STAIR_FIRST_RUN_STEPS + step_index + 1
		var step_top_y := -float(total_step) * STAIR_STEP_HEIGHT
		var center := Vector3(
			second_start_x + (float(step_index) + 0.5) * STAIR_STEP_DEPTH,
			step_top_y - STAIR_SLAB_THICKNESS * 0.5,
			landing_z
		)
		_add_mesh_box("StairSecondRunVisual_%02d" % step_index, Vector3(STAIR_STEP_DEPTH + 0.02, STAIR_SLAB_THICKNESS, STAIR_WIDTH), center, CONCRETE_MATERIAL)

	var bottom_center := _bottom_landing_center()
	_add_static_box(
		"StairBottomLanding",
		Vector3(STAIR_LANDING_SIZE, STAIR_SLAB_THICKNESS, STAIR_LANDING_SIZE),
		bottom_center + Vector3(0.0, -STAIR_SLAB_THICKNESS * 0.5, 0.0),
		CONCRETE_MATERIAL
	)
	_build_stair_guard_walls(first_start_z, landing_z, bottom_center.x)


func _build_stair_guard_walls(first_start_z: float, landing_z: float, bottom_x: float) -> void:
	var guard_height := STAIR_VERTICAL_DROP + 1.35
	var guard_center_y := -STAIR_VERTICAL_DROP * 0.5 + 0.65
	var side_offset := STAIR_WIDTH * 0.5 + WALL_THICKNESS * 0.5

	var first_end_z := first_start_z - float(STAIR_FIRST_RUN_STEPS) * STAIR_STEP_DEPTH
	var first_length := first_start_z - first_end_z
	var first_center_z := (first_start_z + first_end_z) * 0.5
	_add_static_box("StairFirstRunWestWall", Vector3(WALL_THICKNESS, guard_height, first_length), Vector3(-side_offset, guard_center_y, first_center_z), CONCRETE_MATERIAL)
	_add_static_box("StairFirstRunEastWall", Vector3(WALL_THICKNESS, guard_height, first_length), Vector3(side_offset, guard_center_y, first_center_z), CONCRETE_MATERIAL)

	var second_wall_start_x := STAIR_LANDING_SIZE * 0.5
	var second_wall_end_x := bottom_x + STAIR_LANDING_SIZE * 0.5
	var second_length := second_wall_end_x - second_wall_start_x
	var second_center_x := second_wall_start_x + second_length * 0.5
	_add_static_box("StairSecondRunNorthWall", Vector3(second_length, guard_height, WALL_THICKNESS), Vector3(second_center_x, guard_center_y, landing_z - side_offset), CONCRETE_MATERIAL)
	_add_static_box("StairSecondRunSouthWall", Vector3(second_length, guard_height, WALL_THICKNESS), Vector3(second_center_x, guard_center_y, landing_z + side_offset), CONCRETE_MATERIAL)


func _bottom_landing_center() -> Vector3:
	var first_start_z := TOP_PLATFORM_CENTER.z - TOP_PLATFORM_SIZE.z * 0.5
	var landing_z := first_start_z - float(STAIR_FIRST_RUN_STEPS) * STAIR_STEP_DEPTH - STAIR_LANDING_SIZE * 0.5
	var second_start_x := STAIR_LANDING_SIZE * 0.5
	var bottom_x := second_start_x + float(STAIR_SECOND_RUN_STEPS) * STAIR_STEP_DEPTH + STAIR_LANDING_SIZE * 0.5
	return Vector3(bottom_x, MAZE_FLOOR_Y, landing_z)


func _configure_maze_origin() -> void:
	var maze_start_world := _bottom_landing_center() + MAZE_ENTRY_OFFSET
	_maze_origin = maze_start_world - _maze_col_axis * float(_maze_start_cell.x) - _maze_row_axis * float(_maze_start_cell.y)


func _build_stair_to_maze_connector() -> void:
	var bottom_center := _bottom_landing_center()
	var maze_start := _maze_cell_to_world(_maze_start_cell)
	var corridor_center := (bottom_center + maze_start) * 0.5
	var corridor_length := absf(maze_start.x - bottom_center.x)
	var side_offset := STAIR_WIDTH * 0.5 + WALL_THICKNESS * 0.5 + 0.08

	_add_static_box(
		"StairMazeConnectorFloor",
		Vector3(corridor_length + STAIR_LANDING_SIZE, 0.16, STAIR_WIDTH),
		corridor_center + Vector3(0.0, -0.08, 0.0),
		WET_GRASS_MATERIAL
	)
	_add_static_box(
		"StairMazeConnectorNorthWall",
		Vector3(corridor_length, WALL_HEIGHT_BASE, WALL_THICKNESS),
		corridor_center + Vector3(0.0, WALL_HEIGHT_BASE * 0.5, -side_offset),
		CONCRETE_MATERIAL
	)
	_add_static_box(
		"StairMazeConnectorSouthWall",
		Vector3(corridor_length, WALL_HEIGHT_BASE, WALL_THICKNESS),
		corridor_center + Vector3(0.0, WALL_HEIGHT_BASE * 0.5, side_offset),
		CONCRETE_MATERIAL
	)


func _build_maze() -> void:
	_passable_cells.clear()
	for y in range(MAZE.size()):
		var row: String = MAZE[y]
		for x in range(row.length()):
			var cell := row.substr(x, 1)
			var grid_position := Vector2i(x, y)
			var center := _maze_cell_to_world(grid_position)

			if cell == "#":
				if _is_entry_opening_cell(grid_position):
					_add_static_box(
						"MazeEntryThresholdFloor",
						Vector3(TILE_SIZE, 0.16, TILE_SIZE),
						center + Vector3(0.0, -0.08, 0.0),
						WET_GRASS_MATERIAL
					)
					continue
				_add_static_box(
					"MazeWall_%02d_%02d" % [x, y],
					Vector3(TILE_SIZE, WALL_HEIGHT_BASE, TILE_SIZE),
					center + Vector3(0.0, WALL_HEIGHT_BASE * 0.5, 0.0),
					CONCRETE_MATERIAL
				)
				continue

			_passable_cells.append(grid_position)
			_add_static_box(
				"MazeFloor_%02d_%02d" % [x, y],
				Vector3(TILE_SIZE, 0.16, TILE_SIZE),
				center + Vector3(0.0, -0.08, 0.0),
				WET_GRASS_MATERIAL
			)

			if cell == "o":
				_build_fake_sky_hole(center)
			else:
				_add_ceiling_panel("MazeCeiling_%02d_%02d" % [x, y], center, _ceiling_height_for_cell(cell), cell == "l")


func _add_ceiling_panel(node_name: String, center: Vector3, height: float, is_low: bool) -> void:
	var size := Vector3(TILE_SIZE + 0.08, CEILING_THICKNESS, TILE_SIZE + 0.08)
	if is_low:
		size = Vector3(TILE_SIZE + 0.1, CEILING_THICKNESS * 1.25, TILE_SIZE + 0.1)
	_add_static_box(node_name, size, center + Vector3(0.0, height + size.y * 0.5, 0.0), CONCRETE_MATERIAL)


func _ceiling_height_for_cell(cell: String) -> float:
	if cell == "l":
		return LOW_CEILING_HEIGHT
	if cell == "h":
		return HIGH_CEILING_HEIGHT
	return NORMAL_CEILING_HEIGHT


func _build_water() -> void:
	for cell in _passable_cells:
		var marker := _maze_cell(cell.x, cell.y)
		if marker == "S" or marker == "E" or marker == "l" or marker == "o":
			continue
		if int(cell.x * 17 + cell.y * 11) % 10 != 0:
			continue

		var center := _maze_cell_to_world(cell)
		var offset := _detail_offset(cell.x, cell.y, 0.42)
		var scale_value := Vector3(0.55 + float((cell.x + cell.y) % 4) * 0.16, 1.0, 0.36 + float((cell.x * 3 + cell.y) % 4) * 0.12)
		_add_puddle("MazePuddle_%02d_%02d" % [cell.x, cell.y], center + offset + Vector3(0.0, 0.018, 0.0), scale_value)


func _build_vegetation() -> void:
	var grass_scene := load(GRASS_SCENE_PATH) as PackedScene
	var flower_scene := load(FLOWER_WHITE_SCENE_PATH) as PackedScene
	var density: int = max(1, int(round(2.0 * flower_density_multiplier)))

	for cell in _passable_cells:
		var marker := _maze_cell(cell.x, cell.y)
		if marker == "S" or marker == "E" or marker == "l" or marker == "o":
			continue
		if int(cell.x * 23 + cell.y * 19) % 7 != 0:
			continue

		for item_index in range(density):
			var center := _maze_cell_to_world(cell)
			var position := center + _detail_offset(cell.x + item_index, cell.y, 0.72)
			var use_flower := item_index % 2 == 0
			var scene := flower_scene if use_flower else grass_scene
			if scene != null:
				var plant := scene.instantiate() as Node3D
				if plant == null:
					continue
				plant.name = "MazePlant_%02d_%02d_%02d" % [cell.x, cell.y, item_index]
				plant.position = position
				plant.rotation.y = deg_to_rad(float((cell.x * 31 + cell.y * 47 + item_index * 63) % 360))
				plant.scale = Vector3.ONE * (0.45 + float((cell.x + cell.y + item_index) % 4) * 0.08)
				_generated_root.add_child(plant)
			else:
				_add_placeholder_flower("MazePlaceholder_%02d_%02d_%02d" % [cell.x, cell.y, item_index], position)


func _build_exit_marker() -> void:
	var center := _maze_cell_to_world(_maze_exit_cell)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.015, 0.025, 0.02, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.0, 0.08, 0.045, 1.0)
	material.emission_energy_multiplier = 0.85
	_add_mesh_box("MazeExitGlow", Vector3(0.12, 2.1, 2.2), center + Vector3(0.0, 1.05, 0.0), material)

	var light := OmniLight3D.new()
	light.name = "MazeExitColdLight"
	light.position = center + Vector3(0.0, 1.45, 0.0)
	light.light_color = Color(0.55, 0.9, 0.72, 1.0)
	light.light_energy = 1.2
	light.omni_range = 7.0
	_generated_root.add_child(light)


func _build_fake_sky_hole(center: Vector3) -> void:
	var shaft_height := 5.8
	var shaft_center_y := NORMAL_CEILING_HEIGHT + shaft_height * 0.5
	var shaft_width := TILE_SIZE * 0.86
	var shaft_wall := 0.18
	_add_mesh_box("FakeSkyShaftNorthWall", Vector3(shaft_width, shaft_height, shaft_wall), center + Vector3(0.0, shaft_center_y, -shaft_width * 0.5), CONCRETE_MATERIAL)
	_add_mesh_box("FakeSkyShaftSouthWall", Vector3(shaft_width, shaft_height, shaft_wall), center + Vector3(0.0, shaft_center_y, shaft_width * 0.5), CONCRETE_MATERIAL)
	_add_mesh_box("FakeSkyShaftWestWall", Vector3(shaft_wall, shaft_height, shaft_width), center + Vector3(-shaft_width * 0.5, shaft_center_y, 0.0), CONCRETE_MATERIAL)
	_add_mesh_box("FakeSkyShaftEastWall", Vector3(shaft_wall, shaft_height, shaft_width), center + Vector3(shaft_width * 0.5, shaft_center_y, 0.0), CONCRETE_MATERIAL)

	var sky_root := Node3D.new()
	sky_root.name = "FakeSkyHoleClouds"
	sky_root.position = center + Vector3(0.0, NORMAL_CEILING_HEIGHT + 0.1, 0.0)
	sky_root.set_script(FAKE_SKY_SCRIPT)
	_generated_root.add_child(sky_root)

	var sky_plane := MeshInstance3D.new()
	sky_plane.name = "FakeSkyPanel"
	var sky_mesh := PlaneMesh.new()
	sky_mesh.size = Vector2(TILE_SIZE * 1.5, TILE_SIZE * 1.5)
	sky_plane.mesh = sky_mesh
	sky_plane.position = Vector3(0.0, shaft_height - 0.25, 0.0)
	sky_plane.set_surface_override_material(0, _make_unshaded_material(Color(0.07, 0.075, 0.08, 1.0), null))
	sky_root.add_child(sky_plane)

	var cloud_paths := _discover_cloud_pngs()
	var cloud_count: int = mini(13, cloud_paths.size())
	for index in range(cloud_count):
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud_%02d" % index
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(2.2 + float(index % 4) * 0.34, 1.15 + float((index + 2) % 5) * 0.18)
		cloud.mesh = mesh
		var angle := float(index) * TAU / float(cloud_count)
		var radius := 0.25 + float((index * 7) % 9) * 0.08
		cloud.position = Vector3(cos(angle) * radius, shaft_height - 0.1 + float(index % 3) * 0.08, sin(angle) * radius)
		cloud.rotation_degrees = Vector3(0.0, float((index * 37) % 360), 0.0)
		var texture := load(cloud_paths[index]) as Texture2D
		cloud.set_surface_override_material(0, _make_unshaded_material(Color(0.52, 0.52, 0.5, 0.72), texture))
		sky_root.add_child(cloud)

	var light := OmniLight3D.new()
	light.name = "FakeSkyHoleLight"
	light.position = center + Vector3(0.0, NORMAL_CEILING_HEIGHT + 0.4, 0.0)
	light.light_color = Color(0.52, 0.62, 0.68, 1.0)
	light.light_energy = 1.4
	light.omni_range = 8.5
	_generated_root.add_child(light)


func _make_unshaded_material(color: Color, texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if texture != null:
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


func _discover_cloud_pngs() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(CLOUD_TEXTURE_DIR)
	if dir == null:
		return paths

	for file_name in dir.get_files():
		var lower := file_name.to_lower()
		if file_name.get_extension().to_lower() != "png":
			continue
		if lower.contains("checkerboard") or lower.contains("source") or lower.contains("tonemap") or lower.contains("preview"):
			continue
		paths.append("%s/%s" % [CLOUD_TEXTURE_DIR, file_name])

	paths.sort()
	return paths


func _validate_maze_path() -> bool:
	_passable_cells.clear()
	var found_start := false
	var found_exit := false

	for y in range(MAZE.size()):
		var row: String = MAZE[y]
		for x in range(row.length()):
			var cell := row.substr(x, 1)
			if cell == "S":
				_maze_start_cell = Vector2i(x, y)
				found_start = true
			elif cell == "E":
				_maze_exit_cell = Vector2i(x, y)
				found_exit = true

	if not found_start or not found_exit:
		push_error("Underground maze must contain S and E.")
		return false

	var queue: Array[Vector2i] = [_maze_start_cell]
	var visited := {}
	visited[_cell_key(_maze_start_cell)] = true
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == _maze_exit_cell:
			return true

		for direction in directions:
			var next: Vector2i = current + direction
			if not _is_in_maze(next.x, next.y):
				continue
			if _maze_cell(next.x, next.y) == "#":
				continue

			var key := _cell_key(next)
			if visited.has(key):
				continue
			visited[key] = true
			queue.append(next)

	push_error("Underground maze exit E is unreachable from S.")
	return false


func _maze_cell_to_world(cell: Vector2i) -> Vector3:
	return _maze_origin + _maze_col_axis * float(cell.x) + _maze_row_axis * float(cell.y)


func _is_in_maze(x: int, y: int) -> bool:
	if y < 0 or y >= MAZE.size():
		return false
	return x >= 0 and x < MAZE[y].length()


func _maze_cell(x: int, y: int) -> String:
	if not _is_in_maze(x, y):
		return "#"
	return MAZE[y].substr(x, 1)


func _is_entry_opening_cell(cell: Vector2i) -> bool:
	return cell == _maze_start_cell + Vector2i(0, -1)


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _detail_offset(x: int, y: int, radius: float) -> Vector3:
	var angle := deg_to_rad(float((x * 71 + y * 137) % 360))
	var local_radius := 0.18 + float((x * 19 + y * 29) % 100) / 100.0 * radius
	return Vector3(cos(angle) * local_radius, 0.0, sin(angle) * local_radius)


func _add_walkable_ramp(node_name: String, start: Vector3, end: Vector3, width: float, material: Material) -> StaticBody3D:
	var horizontal := end - start
	horizontal.y = 0.0
	if horizontal.length() < 0.001:
		return _add_static_box(node_name, Vector3(width, STAIR_SLAB_THICKNESS, width), start, material)

	var forward := horizontal.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var half_width := width * 0.5
	var thickness := STAIR_SLAB_THICKNESS

	var top_left_start := start + side * half_width
	var top_right_start := start - side * half_width
	var top_left_end := end + side * half_width
	var top_right_end := end - side * half_width
	var bottom_left_start := top_left_start - Vector3.UP * thickness
	var bottom_right_start := top_right_start - Vector3.UP * thickness
	var bottom_left_end := top_left_end - Vector3.UP * thickness
	var bottom_right_end := top_right_end - Vector3.UP * thickness

	var vertices := PackedVector3Array([
		top_left_start,
		top_right_start,
		top_left_end,
		top_right_end,
		bottom_left_start,
		bottom_right_start,
		bottom_left_end,
		bottom_right_end
	])
	var indices := PackedInt32Array([
		0, 2, 1, 1, 2, 3,
		4, 5, 6, 5, 7, 6,
		0, 1, 4, 1, 5, 4,
		2, 6, 3, 3, 6, 7,
		0, 4, 2, 2, 4, 6,
		1, 3, 5, 3, 7, 5
	])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var body := StaticBody3D.new()
	body.name = node_name
	_generated_root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	var collision_indices := PackedInt32Array([0, 2, 1, 1, 2, 3])
	var faces := PackedVector3Array()
	for index in collision_indices:
		faces.append(vertices[index])

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_static_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	_generated_root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_mesh_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	_generated_root.add_child(mesh_instance)
	return mesh_instance


func _add_puddle(node_name: String, position: Vector3, scale_value: Vector3) -> void:
	var puddle := MeshInstance3D.new()
	puddle.name = node_name
	puddle.position = position
	puddle.scale = scale_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.025
	mesh.radial_segments = 48
	puddle.mesh = mesh
	puddle.set_surface_override_material(0, WATER_MATERIAL)
	_generated_root.add_child(puddle)


func _add_placeholder_flower(node_name: String, position: Vector3) -> void:
	var stem := _add_mesh_box(node_name + "_Stem", Vector3(0.035, 0.35, 0.035), position + Vector3(0.0, 0.18, 0.0), WET_GRASS_MATERIAL)
	stem.rotation.y = deg_to_rad(20.0)
	_add_mesh_box(node_name + "_Bloom", Vector3(0.18, 0.04, 0.18), position + Vector3(0.0, 0.38, 0.0), FLOWER_WHITE_MATERIAL)
