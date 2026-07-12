extends Node3D

const CONCRETE_MATERIAL: Material = preload("res://materials/mat_underground_concrete.tres")
const BASEMENT_WALL_MATERIAL: Material = preload("res://materials/polyhaven/mat_basement_broken_brick_wall.tres")
const BASEMENT_FLOOR_MATERIAL: Material = preload("res://materials/polyhaven/mat_basement_floor_gravel_concrete_03.tres")
const CAVE_PLASTER_MATERIAL: Material = preload("res://materials/polyhaven/mat_cave_painted_plaster_wall.tres")
const CAVE_CRACKED_CONCRETE_MATERIAL: Material = preload("res://materials/polyhaven/mat_cave_cracked_concrete_wall.tres")
const CAVE_SAND_ROCK_MATERIAL: Material = preload("res://materials/polyhaven/mat_cave_coast_sand_rocks.tres")
const CLIFF_MARBLE_MATERIAL: Material = preload("res://materials/polyhaven/mat_cliff_marble_cliff_04.tres")
const WET_GRASS_MATERIAL: Material = preload("res://materials/mat_underground_wet_grass.tres")
const WATER_MATERIAL: Material = preload("res://materials/mat_underground_water.tres")
const FLOWER_WHITE_MATERIAL: Material = preload("res://materials/mat_underground_flower_white.tres")
const FAKE_SKY_SCRIPT: Script = preload("res://scripts/fake_sky_hole_clouds.gd")
const SMALL_FIRE_SCENE: PackedScene = preload("res://scenes/effects/SmallFire.tscn")
const SOLDIER_SCENE: PackedScene = preload("res://scenes/actors/SovietSoldierEnemy.tscn")
const FOLKLORE_LADY_SCENE: PackedScene = preload("res://scenes/npcs/FolkloreLady.tscn")
const FINAL_SOLDIER_ROOM_EVENT_SCRIPT: Script = preload("res://scripts/final_soldier_room_event.gd")
const BASEMENT_PROP_SET_BUILDER: Script = preload("res://scripts/props/basement_prop_set_builder.gd")

const GRASS_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_grass_patch.glb"
const FLOWER_WHITE_SCENE_PATH := "res://assets/models/vegetation_fallback/fallback_flower_white.glb"
const CLOUD_TEXTURE_DIR := "res://assets/textures/sky/clouds_runtime_clean"

const MAZE := [
	"######################################################",
	"#S#.#.........########################################",
	"#.#.#.#.#####.########################################",
	"#.#...#....o#.########################################",
	"#.#.#######.#.########################################",
	"#.#.#.f.#...#l########################################",
	"#.#.###.#.###.########################################",
	"#.#.....#.#.f.#####################sssssss############",
	"#.#.#####.#.###RRRRRR#########sssccccccsss############",
	"#l#.#..h#.#...#RRRRRR#######ssccccrrrrrccccss#########",
	"#.n##.#.#.###.#RRRRRR#####ssccrrrcccccccrrrccss#######",
	"#.....#...#.F.RRRRRRRRRrrrccrrrsssssrrrrrrrrrrrrrrrEss",
	"######################################################"
]

const TILE_SIZE := 3.0
const WALL_HEIGHT_BASE := 2.4
const BASEMENT_WALL_HEIGHT := 4.85
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
const FOLKLORE_ALCOVE_CELL := Vector2i(2, 10)

@export_range(0.0, 3.0, 0.1) var flower_density_multiplier: float = 1.0
@export_file("*.tscn") var return_scene_path: String = "res://scenes/Main.tscn"

var _generated_root: Node3D
var _maze_start_cell := Vector2i.ZERO
var _maze_exit_cell := Vector2i.ZERO
var _maze_origin := Vector3.ZERO
var _maze_col_axis := Vector3(0.0, 0.0, -TILE_SIZE)
var _maze_row_axis := Vector3(TILE_SIZE, 0.0, 0.0)
var _passable_cells: Array[Vector2i] = []
var _soldier_spawn_cells: Array[Vector2i] = []
var _final_room_cells: Array[Vector2i] = []


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
	_build_cave_details()
	_build_folklore_lady_alcove()
	_build_basement_prop_set()
	_build_water()
	_build_vegetation()
	_build_exit_marker()
	_build_cliff_exit()
	_build_final_soldier_room()


func _position_player_at_entry() -> void:
	var player := get_node_or_null("Player") as Node3D
	if player == null:
		return

	player.global_position = TOP_PLATFORM_CENTER + Vector3(0.0, 0.04, 0.0)
	player.rotation = Vector3.ZERO


func _build_entry_stairs() -> void:
	_add_static_box("EntryConcretePlatform", TOP_PLATFORM_SIZE, TOP_PLATFORM_CENTER + Vector3(0.0, -TOP_PLATFORM_SIZE.y * 0.5, 0.0), BASEMENT_FLOOR_MATERIAL)

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
		BASEMENT_FLOOR_MATERIAL
	)
	_add_walkable_ramp(
		"StairSecondRunWalkableRamp",
		Vector3(second_start_x, landing_y, landing_z),
		Vector3(second_end_x, MAZE_FLOOR_Y, landing_z),
		STAIR_WALKABLE_WIDTH,
		BASEMENT_FLOOR_MATERIAL
	)

	for step_index in range(STAIR_FIRST_RUN_STEPS):
		var step_top_y := -float(step_index + 1) * STAIR_STEP_HEIGHT
		var center := Vector3(
			0.0,
			step_top_y - STAIR_SLAB_THICKNESS * 0.5,
			first_start_z - (float(step_index) + 0.5) * STAIR_STEP_DEPTH
		)
		_add_mesh_box("StairFirstRunVisual_%02d" % step_index, Vector3(STAIR_WIDTH, STAIR_SLAB_THICKNESS, STAIR_STEP_DEPTH + 0.02), center, BASEMENT_FLOOR_MATERIAL)

	_add_static_box(
		"StairTurnLanding",
		Vector3(STAIR_LANDING_SIZE, STAIR_SLAB_THICKNESS, STAIR_LANDING_SIZE),
		Vector3(0.0, landing_y - STAIR_SLAB_THICKNESS * 0.5, landing_z),
		BASEMENT_FLOOR_MATERIAL
	)

	for step_index in range(STAIR_SECOND_RUN_STEPS):
		var total_step := STAIR_FIRST_RUN_STEPS + step_index + 1
		var step_top_y := -float(total_step) * STAIR_STEP_HEIGHT
		var center := Vector3(
			second_start_x + (float(step_index) + 0.5) * STAIR_STEP_DEPTH,
			step_top_y - STAIR_SLAB_THICKNESS * 0.5,
			landing_z
		)
		_add_mesh_box("StairSecondRunVisual_%02d" % step_index, Vector3(STAIR_STEP_DEPTH + 0.02, STAIR_SLAB_THICKNESS, STAIR_WIDTH), center, BASEMENT_FLOOR_MATERIAL)

	var bottom_center := _bottom_landing_center()
	_add_static_box(
		"StairBottomLanding",
		Vector3(STAIR_LANDING_SIZE, STAIR_SLAB_THICKNESS, STAIR_LANDING_SIZE),
		bottom_center + Vector3(0.0, -STAIR_SLAB_THICKNESS * 0.5, 0.0),
		BASEMENT_FLOOR_MATERIAL
	)
	_build_stair_guard_walls(first_start_z, landing_z, bottom_center.x)


func _build_stair_guard_walls(first_start_z: float, landing_z: float, bottom_x: float) -> void:
	var guard_height := maxf(STAIR_VERTICAL_DROP + 1.35, BASEMENT_WALL_HEIGHT)
	var guard_center_y := -STAIR_VERTICAL_DROP * 0.5 + 0.65
	var side_offset := STAIR_WIDTH * 0.5 + WALL_THICKNESS * 0.5

	var first_end_z := first_start_z - float(STAIR_FIRST_RUN_STEPS) * STAIR_STEP_DEPTH
	var first_length := first_start_z - first_end_z
	var first_center_z := (first_start_z + first_end_z) * 0.5
	_add_static_box("StairFirstRunWestWall", Vector3(WALL_THICKNESS, guard_height, first_length), Vector3(-side_offset, guard_center_y, first_center_z), BASEMENT_WALL_MATERIAL)
	_add_static_box("StairFirstRunEastWall", Vector3(WALL_THICKNESS, guard_height, first_length), Vector3(side_offset, guard_center_y, first_center_z), BASEMENT_WALL_MATERIAL)

	var second_wall_start_x := STAIR_LANDING_SIZE * 0.5
	var second_wall_end_x := bottom_x + STAIR_LANDING_SIZE * 0.5
	var second_length := second_wall_end_x - second_wall_start_x
	var second_center_x := second_wall_start_x + second_length * 0.5
	_add_static_box("StairSecondRunNorthWall", Vector3(second_length, guard_height, WALL_THICKNESS), Vector3(second_center_x, guard_center_y, landing_z - side_offset), BASEMENT_WALL_MATERIAL)
	_add_static_box("StairSecondRunSouthWall", Vector3(second_length, guard_height, WALL_THICKNESS), Vector3(second_center_x, guard_center_y, landing_z + side_offset), BASEMENT_WALL_MATERIAL)


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
		BASEMENT_FLOOR_MATERIAL
	)
	_add_static_box(
		"StairMazeConnectorNorthWall",
		Vector3(corridor_length, BASEMENT_WALL_HEIGHT, WALL_THICKNESS),
		corridor_center + Vector3(0.0, BASEMENT_WALL_HEIGHT * 0.5, -side_offset),
		BASEMENT_WALL_MATERIAL
	)
	_add_static_box(
		"StairMazeConnectorSouthWall",
		Vector3(corridor_length, BASEMENT_WALL_HEIGHT, WALL_THICKNESS),
		corridor_center + Vector3(0.0, BASEMENT_WALL_HEIGHT * 0.5, side_offset),
		BASEMENT_WALL_MATERIAL
	)


func _build_maze() -> void:
	_passable_cells.clear()
	_soldier_spawn_cells.clear()
	_final_room_cells.clear()
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
						BASEMENT_FLOOR_MATERIAL
					)
					continue
				_add_static_box(
					"MazeWall_%02d_%02d" % [x, y],
					Vector3(TILE_SIZE, BASEMENT_WALL_HEIGHT, TILE_SIZE),
					center + Vector3(0.0, BASEMENT_WALL_HEIGHT * 0.5, 0.0),
					_wall_material_for_cell(grid_position)
				)
				continue

			_passable_cells.append(grid_position)
			if cell == "P":
				_soldier_spawn_cells.append(grid_position)
			if cell == "R" or cell == "P" or cell == "E":
				_final_room_cells.append(grid_position)
			_add_static_box(
				"MazeFloor_%02d_%02d" % [x, y],
				Vector3(TILE_SIZE, 0.16, TILE_SIZE),
				center + Vector3(0.0, -0.08, 0.0),
				_floor_material_for_cell(cell)
			)

			if cell == "o":
				_build_fake_sky_hole(center)
			elif grid_position != FOLKLORE_ALCOVE_CELL:
				_add_ceiling_panel("MazeCeiling_%02d_%02d" % [x, y], center, _ceiling_height_for_cell(cell), cell == "l", _ceiling_material_for_cell(cell))

			if cell == "f" or cell == "F":
				_build_fire_marker(center, cell == "F")


func _build_folklore_lady_alcove() -> void:
	var center := _maze_cell_to_world(FOLKLORE_ALCOVE_CELL)
	_spawn_folklore_lady(center)


func _build_basement_prop_set() -> void:
	# The lady is at (2, 10). The route continues south to (2, 11), then
	# turns east; keep the dressing beyond that corner and leave the aisle clear.
	BASEMENT_PROP_SET_BUILDER.build(
		_generated_root,
		_maze_cell_to_world(Vector2i(2, 11)),
		_maze_cell_to_world(Vector2i(4, 11)),
		_maze_cell_to_world(Vector2i(5, 11))
	)


func _add_alcove_entry_frame(center: Vector3, clay_material: Material, dark_clay_material: Material) -> void:
	_add_mesh_box(
		"FolkloreAlcoveEntryLeftPost",
		Vector3(0.16, WALL_HEIGHT_BASE * 0.84, 0.16),
		center + Vector3(-TILE_SIZE * 0.63, WALL_HEIGHT_BASE * 0.42, TILE_SIZE * 0.5),
		dark_clay_material
	)
	_add_mesh_box(
		"FolkloreAlcoveEntryRightPost",
		Vector3(0.16, WALL_HEIGHT_BASE * 0.84, 0.16),
		center + Vector3(TILE_SIZE * 0.63, WALL_HEIGHT_BASE * 0.42, TILE_SIZE * 0.5),
		dark_clay_material
	)


func _add_alcove_cracks(center: Vector3, crack_material: Material) -> void:
	for index in range(7):
		var x_offset := -1.06 + float(index % 4) * 0.68
		var y_offset := 0.72 + float(index / 4) * 0.42
		var crack := _add_mesh_box(
			"FolkloreAlcoveIrregularCrack_%02d" % index,
			Vector3(0.035, 0.34 + float(index % 3) * 0.08, 0.03),
			center + Vector3(x_offset, y_offset, -TILE_SIZE * 0.505),
			crack_material
		)
		crack.rotation_degrees.z = -18.0 + float(index * 13)


func _spawn_folklore_lady(center: Vector3) -> void:
	var lady := FOLKLORE_LADY_SCENE.instantiate() as Node3D
	if lady == null:
		return

	lady.name = "FolkloreLady"
	lady.position = center + Vector3(-0.18, 0.04, -0.08)
	_generated_root.add_child(lady)

	var lamp_shadow := OmniLight3D.new()
	lamp_shadow.name = "FolkloreAlcoveAmberSpill"
	lamp_shadow.position = center + Vector3(-0.9, 0.78, 0.02)
	lamp_shadow.light_color = Color(1.0, 0.52, 0.22, 1.0)
	lamp_shadow.light_energy = 0.34
	lamp_shadow.omni_range = 3.2
	_generated_root.add_child(lamp_shadow)


func _add_ceiling_panel(node_name: String, center: Vector3, height: float, is_low: bool, material: Material) -> void:
	var split := node_name.split("_")
	if split.size() >= 3:
		var x := int(split[1])
		var y := int(split[2])
		if int(abs(x * 5 + y * 3)) % 2 == 0:
			return
	var size := Vector3(TILE_SIZE + 0.08, CEILING_THICKNESS, TILE_SIZE + 0.08)
	if is_low:
		size = Vector3(TILE_SIZE + 0.1, CEILING_THICKNESS * 1.25, TILE_SIZE + 0.1)
	_add_static_box(node_name, size, center + Vector3(0.0, height + size.y * 0.5, 0.0), material)


func _ceiling_height_for_cell(cell: String) -> float:
	if cell == "R" or cell == "P" or cell == "E":
		return HIGH_CEILING_HEIGHT
	if cell == "r" or cell == "c" or cell == "s":
		return NORMAL_CEILING_HEIGHT + float((cell.unicode_at(0) + 3) % 4) * 0.36
	if cell == "l":
		return LOW_CEILING_HEIGHT
	if cell == "h":
		return HIGH_CEILING_HEIGHT
	return NORMAL_CEILING_HEIGHT


func _floor_material_for_cell(cell: String) -> Material:
	match cell:
		"r":
			return CAVE_PLASTER_MATERIAL
		"c":
			return CAVE_CRACKED_CONCRETE_MATERIAL
		"s":
			return CAVE_SAND_ROCK_MATERIAL
		"E":
			return CLIFF_MARBLE_MATERIAL
		_:
			return BASEMENT_FLOOR_MATERIAL


func _ceiling_material_for_cell(cell: String) -> Material:
	match cell:
		"r":
			return CAVE_PLASTER_MATERIAL
		"c":
			return CAVE_CRACKED_CONCRETE_MATERIAL
		"s", "E":
			return CAVE_SAND_ROCK_MATERIAL
		_:
			return CONCRETE_MATERIAL


func _wall_material_for_cell(cell: Vector2i) -> Material:
	var strongest_material := BASEMENT_WALL_MATERIAL
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for direction in directions:
		var neighbor_marker := _maze_cell(cell.x + direction.x, cell.y + direction.y)
		if neighbor_marker == "E":
			return CLIFF_MARBLE_MATERIAL
		if neighbor_marker == "s":
			strongest_material = CAVE_SAND_ROCK_MATERIAL
		elif neighbor_marker == "c" and strongest_material != CAVE_SAND_ROCK_MATERIAL:
			strongest_material = CAVE_CRACKED_CONCRETE_MATERIAL
		elif neighbor_marker == "r" and strongest_material == BASEMENT_WALL_MATERIAL:
			strongest_material = CAVE_PLASTER_MATERIAL
	return strongest_material


func _is_cave_cell_marker(marker: String) -> bool:
	return marker == "r" or marker == "c" or marker == "s" or marker == "E"


func _build_cave_details() -> void:
	for cell in _passable_cells:
		var marker := _maze_cell(cell.x, cell.y)
		if not _is_cave_cell_marker(marker):
			continue

		var center := _maze_cell_to_world(cell)
		if marker != "E":
			_build_cave_floor_lumps(cell, center, _floor_material_for_cell(marker))
			_build_cave_wall_shoulders(cell, center, _ceiling_material_for_cell(marker))

		if int(cell.x * 13 + cell.y * 17) % 9 == 0:
			_add_cave_low_light("CaveWarmSeamLight_%02d_%02d" % [cell.x, cell.y], center + Vector3(0.0, 1.1, 0.0), Color(0.95, 0.72, 0.48, 1.0), 0.18, 4.2)


func _build_cave_floor_lumps(cell: Vector2i, center: Vector3, material: Material) -> void:
	var lump_count := 1 + int(abs(cell.x * 5 + cell.y * 3) % 3)
	for index in range(lump_count):
		var offset := _detail_offset(cell.x + index * 2, cell.y + index, 0.88)
		var size := Vector3(
			0.34 + float((cell.x + index) % 4) * 0.11,
			0.08 + float((cell.y + index) % 3) * 0.045,
			0.28 + float((cell.x + cell.y + index) % 5) * 0.08
		)
		var lump := _add_mesh_box(
			"CaveFloorLump_%02d_%02d_%02d" % [cell.x, cell.y, index],
			size,
			center + offset + Vector3(0.0, size.y * 0.5 + 0.005, 0.0),
			material
		)
		lump.rotation_degrees.y = float((cell.x * 29 + cell.y * 31 + index * 53) % 360)


func _build_cave_wall_shoulders(cell: Vector2i, center: Vector3, material: Material) -> void:
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for direction in directions:
		if _maze_cell(cell.x + direction.x, cell.y + direction.y) != "#":
			continue
		if int(abs((cell.x + direction.x * 7) * 19 + (cell.y + direction.y * 5) * 23)) % 3 == 0:
			continue

		var outward := (_maze_col_axis.normalized() * float(direction.x) + _maze_row_axis.normalized() * float(direction.y)).normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var size := Vector3(0.42, 1.1 + float((cell.x + cell.y) % 4) * 0.22, 0.32)
		var shoulder := _add_mesh_box(
			"CaveWallShoulder_%02d_%02d_%d_%d" % [cell.x, cell.y, direction.x, direction.y],
			size,
			center + outward * (TILE_SIZE * 0.43) + Vector3(0.0, 0.62, 0.0),
			material
		)
		shoulder.look_at(shoulder.global_position + tangent, Vector3.UP)
		shoulder.rotation_degrees.y += float((cell.x * 11 + cell.y * 7) % 18) - 9.0


func _build_cliff_exit() -> void:
	if _maze_exit_cell == Vector2i.ZERO:
		return

	var exit_center := _maze_cell_to_world(_maze_exit_cell)
	var forward := _maze_col_axis.normalized()
	var side := _maze_row_axis.normalized()
	var mouth_center := exit_center + forward * (TILE_SIZE * 1.35)
	var ledge_center := exit_center + forward * (TILE_SIZE * 3.45)

	_add_static_box(
		"CliffExitMarbleLedge",
		Vector3(7.8, 0.34, 8.8),
		ledge_center + Vector3(0.0, -0.18, 0.0),
		CLIFF_MARBLE_MATERIAL
	)
	_add_mesh_box(
		"CliffExitLeftCaveCorner",
		Vector3(1.2, 4.8, 7.2),
		mouth_center + side * 3.9 + Vector3(0.0, 1.8, 0.0),
		CLIFF_MARBLE_MATERIAL
	).rotation_degrees.y = -7.0
	_add_mesh_box(
		"CliffExitRightCaveCorner",
		Vector3(1.35, 4.5, 6.8),
		mouth_center - side * 3.8 + Vector3(0.0, 1.65, 0.0),
		CLIFF_MARBLE_MATERIAL
	).rotation_degrees.y = 9.0
	_add_mesh_box(
		"CliffExitLowOverhang",
		Vector3(8.2, 0.85, 4.4),
		mouth_center + Vector3(0.0, 3.55, 0.0) + forward * 0.8,
		CLIFF_MARBLE_MATERIAL
	)

	for index in range(7):
		var offset_side := -3.1 + float(index) * 1.02
		var offset_forward := 1.7 + float((index * 5) % 7) * 0.38
		var size := Vector3(0.55 + float(index % 3) * 0.22, 0.24 + float(index % 4) * 0.11, 0.72 + float((index + 1) % 3) * 0.24)
		var rock := _add_mesh_box(
			"CliffExitBrokenLip_%02d" % index,
			size,
			ledge_center + side * offset_side + forward * offset_forward + Vector3(0.0, size.y * 0.5 + 0.02, 0.0),
			CLIFF_MARBLE_MATERIAL
		)
		rock.rotation_degrees.y = float((index * 37) % 360)

	_build_cliff_horizon(exit_center, forward)
	_add_cave_low_light("CliffExitSunBounce", mouth_center + Vector3(0.0, 1.45, 0.0), Color(1.0, 0.76, 0.42, 1.0), 1.15, 12.0)


func _build_cliff_horizon(exit_center: Vector3, forward: Vector3) -> void:
	var horizon := MeshInstance3D.new()
	horizon.name = "CliffExitWarmHorizon"
	var horizon_mesh := QuadMesh.new()
	horizon_mesh.size = Vector2(96.0, 28.0)
	horizon.mesh = horizon_mesh
	horizon.position = exit_center + forward * 34.0 + Vector3(0.0, 7.8, 0.0)
	horizon.set_surface_override_material(0, _make_sun_horizon_material())
	_generated_root.add_child(horizon)

	var sun := MeshInstance3D.new()
	sun.name = "CliffExitLowSun"
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 2.8
	sun_mesh.height = 5.6
	sun.mesh = sun_mesh
	sun.position = exit_center + forward * 31.5 + Vector3(0.0, 6.2, 0.0)
	sun.set_surface_override_material(0, _make_unshaded_material(Color(1.0, 0.78, 0.34, 1.0), null))
	_generated_root.add_child(sun)

	var glare := MeshInstance3D.new()
	glare.name = "CliffExitSquintGlare"
	var glare_mesh := QuadMesh.new()
	glare_mesh.size = Vector2(28.0, 3.2)
	glare.mesh = glare_mesh
	glare.position = exit_center + forward * 30.6 + Vector3(0.0, 6.2, 0.0)
	glare.set_surface_override_material(0, _make_unshaded_material(Color(1.0, 0.86, 0.48, 0.32), null))
	_generated_root.add_child(glare)

	var sun_light := DirectionalLight3D.new()
	sun_light.name = "CliffExitSunDirectionalLight"
	sun_light.light_color = Color(1.0, 0.78, 0.48, 1.0)
	sun_light.light_energy = 2.1
	sun_light.rotation_degrees = Vector3(-8.0, 180.0, 0.0)
	_generated_root.add_child(sun_light)


func _make_sun_horizon_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

void fragment() {
	float horizon = smoothstep(0.0, 0.52, UV.y);
	vec3 low = vec3(1.0, 0.62, 0.24);
	vec3 high = vec3(0.42, 0.56, 0.72);
	float sun_band = 1.0 - smoothstep(0.36, 0.64, abs(UV.y - 0.48));
	ALBEDO = mix(low, high, horizon) + vec3(0.42, 0.28, 0.08) * sun_band;
	ALPHA = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _add_cave_low_light(node_name: String, position: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	_generated_root.add_child(light)


func _build_water() -> void:
	for cell in _passable_cells:
		var marker := _maze_cell(cell.x, cell.y)
		if marker == "S" or marker == "E" or marker == "R" or marker == "P" or marker == "l" or marker == "n" or marker == "o" or marker == "f" or marker == "F" or _is_cave_cell_marker(marker):
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
		if marker == "S" or marker == "E" or marker == "R" or marker == "P" or marker == "l" or marker == "n" or marker == "o" or marker == "f" or marker == "F" or _is_cave_cell_marker(marker):
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


func _build_final_soldier_room() -> void:
	if _final_room_cells.is_empty() or _soldier_spawn_cells.is_empty():
		return

	var soldiers: Array[Node3D] = []
	for index in range(_soldier_spawn_cells.size()):
		var soldier := SOLDIER_SCENE.instantiate() as Node3D
		if soldier == null:
			continue

		var center := _maze_cell_to_world(_soldier_spawn_cells[index])
		soldier.name = "FinalSoldier_%02d" % index
		soldier.scale = Vector3.ONE * 1.02
		_generated_root.add_child(soldier)
		soldier.global_position = center + Vector3(0.0, 0.02, 0.0)
		soldiers.append(soldier)

	var room_bounds := _final_room_bounds()
	var room_center: Vector3 = room_bounds["center"]
	var room_size: Vector3 = room_bounds["size"]

	var event := Node3D.new()
	event.name = "FinalSoldierRoomEvent"
	event.set_script(FINAL_SOLDIER_ROOM_EVENT_SCRIPT)
	_generated_root.add_child(event)
	event.global_position = room_center
	if event.has_method("setup"):
		event.call("setup", soldiers, room_size, return_scene_path)

	_add_final_room_light("FinalRoomColdLightA", room_center + Vector3(-3.0, 2.25, 2.2), 0.72, 8.0)
	_add_final_room_light("FinalRoomColdLightB", room_center + Vector3(3.4, 2.4, -2.6), 0.44, 7.2)


func _final_room_bounds() -> Dictionary:
	var first := _maze_cell_to_world(_final_room_cells[0])
	var min_x := first.x
	var max_x := first.x
	var min_z := first.z
	var max_z := first.z

	for cell in _final_room_cells:
		var position := _maze_cell_to_world(cell)
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
		min_z = minf(min_z, position.z)
		max_z = maxf(max_z, position.z)

	var center := Vector3((min_x + max_x) * 0.5, MAZE_FLOOR_Y + 1.2, (min_z + max_z) * 0.5)
	var size := Vector3(
		(max_x - min_x) + TILE_SIZE * 1.08,
		2.8,
		(max_z - min_z) + TILE_SIZE * 1.08
	)
	return {"center": center, "size": size}


func _add_final_room_light(node_name: String, position: Vector3, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = Color(0.48, 0.58, 0.62, 1.0)
	light.light_energy = energy
	light.omni_range = radius
	_generated_root.add_child(light)


func _build_fake_sky_hole(center: Vector3) -> void:
	var shaft_height := 5.8
	var shaft_center_y := NORMAL_CEILING_HEIGHT + shaft_height * 0.5
	var shaft_width := TILE_SIZE * 0.86
	var shaft_wall := 0.18
	_add_mesh_box("FakeSkyShaftNorthWall", Vector3(shaft_width, shaft_height, shaft_wall), center + Vector3(0.0, shaft_center_y, -shaft_width * 0.5), BASEMENT_WALL_MATERIAL)
	_add_mesh_box("FakeSkyShaftSouthWall", Vector3(shaft_width, shaft_height, shaft_wall), center + Vector3(0.0, shaft_center_y, shaft_width * 0.5), BASEMENT_WALL_MATERIAL)
	_add_mesh_box("FakeSkyShaftWestWall", Vector3(shaft_wall, shaft_height, shaft_width), center + Vector3(-shaft_width * 0.5, shaft_center_y, 0.0), BASEMENT_WALL_MATERIAL)
	_add_mesh_box("FakeSkyShaftEastWall", Vector3(shaft_wall, shaft_height, shaft_width), center + Vector3(shaft_width * 0.5, shaft_center_y, 0.0), BASEMENT_WALL_MATERIAL)

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
	sky_plane.set_surface_override_material(0, _make_fake_sky_material())
	sky_root.add_child(sky_plane)

	var cloud_paths := _discover_cloud_pngs()
	var cloud_count: int = mini(9, cloud_paths.size())
	var built_cloud_count := 0
	for index in range(cloud_count):
		var texture := load(cloud_paths[index]) as Texture2D
		if texture == null:
			continue

		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud_%02d" % index
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(1.65 + float(index % 4) * 0.28, 0.82 + float((index + 2) % 5) * 0.13)
		cloud.mesh = mesh
		var angle := float(index) * TAU / float(cloud_count)
		var radius := 0.25 + float((index * 7) % 9) * 0.08
		cloud.position = Vector3(cos(angle) * radius, shaft_height - 0.9 + float(index % 3) * 0.22, sin(angle) * radius)
		cloud.rotation_degrees = Vector3(0.0, float((index * 37) % 360), 0.0)
		cloud.set_surface_override_material(0, _make_fake_cloud_material(texture, Color(0.58, 0.61, 0.58, 0.66)))
		sky_root.add_child(cloud)
		built_cloud_count += 1

	if built_cloud_count == 0:
		_build_fallback_clouds(sky_root, shaft_height)

	var light := SpotLight3D.new()
	light.name = "FakeSkyHoleColdSpot"
	light.position = center + Vector3(0.0, NORMAL_CEILING_HEIGHT + 3.2, 0.0)
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.light_color = Color(0.48, 0.64, 0.7, 1.0)
	light.light_energy = 1.05
	light.spot_range = 5.8
	light.spot_angle = 32.0
	light.spot_attenuation = 1.7
	_generated_root.add_child(light)


func _make_fake_sky_material() -> StandardMaterial3D:
	return _make_unshaded_material(Color(0.22, 0.31, 0.34, 1.0), null)


func _make_fake_cloud_material(texture: Texture2D, color: Color) -> Material:
	if texture != null:
		return _make_unshaded_material(color, texture)

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 cloud_color : source_color = vec4(0.55, 0.59, 0.58, 0.52);
uniform float patch_scale = 4.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

void fragment() {
	vec2 centered = UV * 2.0 - vec2(1.0);
	float soft_edge = 1.0 - smoothstep(0.34, 1.0, length(centered * vec2(0.78, 1.35)));
	float patches = value_noise(UV * patch_scale + vec2(TIME * 0.035, -TIME * 0.018));
	patches = smoothstep(0.28, 0.86, patches);
	ALBEDO = cloud_color.rgb;
	ALPHA = cloud_color.a * soft_edge * (0.38 + patches * 0.62);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cloud_color", color)
	return material


func _build_fallback_clouds(sky_root: Node3D, shaft_height: float) -> void:
	var cloud_colors: Array[Color] = [
		Color(0.56, 0.6, 0.58, 0.48),
		Color(0.48, 0.56, 0.58, 0.42),
		Color(0.62, 0.62, 0.57, 0.36)
	]

	for index in range(6):
		var cloud := MeshInstance3D.new()
		cloud.name = "FallbackCloud_%02d" % index
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(1.55 + float(index % 3) * 0.32, 0.74 + float((index + 1) % 3) * 0.16)
		cloud.mesh = mesh
		var angle := float(index) * TAU / 6.0
		var radius := 0.22 + float((index * 5) % 6) * 0.09
		cloud.position = Vector3(cos(angle) * radius, shaft_height - 1.0 + float(index % 3) * 0.24, sin(angle) * radius)
		cloud.rotation_degrees = Vector3(0.0, float((index * 41) % 360), 0.0)
		cloud.set_surface_override_material(0, _make_fake_cloud_material(null, cloud_colors[index % cloud_colors.size()]))
		sky_root.add_child(cloud)


func _build_fire_marker(center: Vector3, final: bool) -> void:
	var fire := SMALL_FIRE_SCENE.instantiate() as Node3D
	if fire == null:
		return

	fire.name = "MazeFinalFire" if final else "MazeSmallFire"
	fire.position = center + (Vector3(0.9, 0.04, 0.0) if final else Vector3(-0.72, 0.04, 0.58))
	fire.rotation_degrees.y = -22.0 if final else 31.0
	if fire.has_method("configure"):
		fire.call("configure", final)
	_generated_root.add_child(fire)


func _make_unshaded_material(color: Color, texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if texture != null:
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


func _make_alcove_material(name: String, color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = 0.94
	material.metallic = 0.0
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
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
