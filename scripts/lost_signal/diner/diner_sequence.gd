extends Node3D

const POLYHAVEN_TABLE_SET: PackedScene = preload("res://assets/polyhaven/diner/outdoor_table_chair_set_01/outdoor_table_chair_set_01_2k.gltf")
const POLYHAVEN_DRAWER_CABINET: PackedScene = preload("res://assets/polyhaven/diner/drawer_cabinet/drawer_cabinet_2k.gltf")
const POLYHAVEN_DISPLAY_SHELVES: PackedScene = preload("res://assets/polyhaven/diner/wooden_display_shelves_01/wooden_display_shelves_01_2k.gltf")
const POLYHAVEN_ARM_CHAIR: PackedScene = preload("res://assets/polyhaven/diner/modern_arm_chair_01/modern_arm_chair_01_2k.gltf")
const DINER_FLOOR_MATERIAL: Material = preload("res://materials/lost_signal/diner/mat_diner_floor_wood.tres")
const WOMAN_WAITRESS_SCENE: PackedScene = preload(
	"res://assets/lost_signal/characters/woman_catwalk/woman_catwalk_pbr.tscn"
)
const WAITRESS_MODEL_SCALE := 1.3
const WAITRESS_CASHIER_POSITION := Vector3(-1.4, 0.0, -9.85)
const WAITRESS_SERVICE_HOME := Vector3(3.2, 0.0, -10.0)
const WAITRESS_OPPOSITE_TABLE_POSITION := Vector3(0.5, 0.0, -5.2)
const DINER_ZOOM_MULTIPLIER := 3.0
const DINER_ZOOM_SPEED := 11.0
const FREE_CAMERA_WALK_SPEED := 3.8
const FREE_CAMERA_SPRINT_SPEED := 6.2
const FREE_CAMERA_CROUCH_OFFSET := 0.58

const WAITRESS_DELIVERY_ROUTE: Array[Vector3] = [
	Vector3(5.2, 0.0, -10.0),
	Vector3(6.5, 0.0, -9.8),
	Vector3(7.7, 0.0, -8.7),
	Vector3(7.8, 0.0, -5.3),
	Vector3(4.5, 0.0, -4.9),
	Vector3(2.2, 0.0, -4.7),
	Vector3(2.2, 0.0, -3.5),
]
const WAITRESS_RETURN_ROUTE: Array[Vector3] = [
	Vector3(2.2, 0.0, -3.5),
	Vector3(2.2, 0.0, -4.7),
	Vector3(4.5, 0.0, -4.9),
	Vector3(7.8, 0.0, -5.3),
	Vector3(7.7, 0.0, -8.7),
	Vector3(6.5, 0.0, -9.8),
	Vector3(5.2, 0.0, -10.0),
	Vector3(3.2, 0.0, -10.0),
]
const WAITRESS_FOREGROUND_ROUTE: Array[Vector3] = [
	Vector3(5.2, 0.0, -10.0),
	Vector3(6.5, 0.0, -9.8),
	Vector3(7.7, 0.0, -8.7),
	Vector3(7.8, 0.0, -5.3),
	Vector3(5.2, 0.0, -4.9),
	Vector3(3.2, 0.0, -4.9),
]
const WAITRESS_FINAL_TABLE_ROUTE: Array[Vector3] = [
	Vector3(2.2, 0.0, -5.2),
	WAITRESS_OPPOSITE_TABLE_POSITION,
]

enum DinerState {
	ENTERING,
	AT_COUNTER,
	MENU,
	ORDER_CONFIRMED,
	GOING_TO_TABLE,
	SEATED,
	SERVING,
	EATING,
	AFTER_MEAL,
	TRANSITIONING,
}

@onready var hud: LostSignalHUD = $LostSignalHUD
@onready var blink: LostSignalBlinkOverlay = $BlinkOverlay

var state := DinerState.ENTERING
var _camera_rig: Node3D
var _look_yaw: Node3D
var _look_pitch: Node3D
var _camera: Camera3D
var _entry_path: Path3D
var _table_path: Path3D
var _door: Node3D
var _characters: Array[Node3D] = []
var _cashier: Node3D
var _server: Node3D
var _server_home := Vector3.ZERO
var _waitress_cycle_running := false
var _meal_root: Node3D
var _meal_states: Dictionary = {}
var _menu_layer: CanvasLayer
var _menu_panel: PanelContainer
var _menu_buttons: Array[Button] = []
var _order_locked := false
var _yaw_target := 0.0
var _pitch_target := 0.0
var _walking := false
var _walk_phase := 0.0
var _base_camera_offset := Vector3.ZERO
var _base_camera_fov := 70.0
var _zoom_held := false
var _cashier_press := 0.0
var _diner_tables_root: Node3D
var _diner_decor_root: Node3D
var _entrance_props_root: Node3D
var _diner_floor_root: Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	LostSignalProceduralAmbience.add_player(self, "DinerRoomTone", LostSignalProceduralAmbience.Kind.DINER, &"InteriorRoom", -22.0)
	_build_environment()
	_build_architecture()
	_build_characters()
	_build_camera_and_paths()
	_build_meals()
	_build_menu()
	if LostSignalFlow.meal_finished:
		_restore_after_restroom()
	else:
		_run_entry_sequence()


func _process(delta: float) -> void:
	_animate_characters(delta)
	_update_camera_zoom(delta)
	if _is_free_camera_active():
		_update_free_camera_movement(delta)
	elif _walking:
		_walk_phase += delta * 11.4
		_camera.position = _base_camera_offset + Vector3(sin(_walk_phase * 0.5) * 0.004, abs(sin(_walk_phase)) * 0.016, 0)
	else:
		_camera.position = _camera.position.lerp(_base_camera_offset, clampf(delta * 8.0, 0.0, 1.0))
	if state not in [DinerState.AT_COUNTER, DinerState.ORDER_CONFIRMED] and not LostSignalInputLock.is_locked():
		var weight := 1.0 - exp(-10.0 * delta)
		_look_yaw.rotation.y = lerp_angle(_look_yaw.rotation.y, _yaw_target, weight)
		_look_pitch.rotation.x = lerp_angle(_look_pitch.rotation.x, _pitch_target, weight)
	if _cashier and _cashier_press > 0.0:
		_cashier_press = maxf(0.0, _cashier_press - delta)
		var arm := _cashier.get_node_or_null("ArmR") as Node3D
		if arm:
			arm.rotation_degrees.x = lerpf(-34.0, 0.0, 1.0 - _cashier_press / 0.55)


func _update_camera_zoom(delta: float) -> void:
	if _camera == null:
		return
	var target_fov := _base_camera_fov
	if _zoom_held:
		var half_angle := deg_to_rad(_base_camera_fov) * 0.5
		target_fov = rad_to_deg(atan(tan(half_angle) / DINER_ZOOM_MULTIPLIER) * 2.0)
	var weight := 1.0 - exp(-DINER_ZOOM_SPEED * delta)
	_camera.fov = lerpf(_camera.fov, target_fov, weight)


func _is_free_camera_active() -> bool:
	return state == DinerState.AFTER_MEAL and not LostSignalFlow.transition_in_progress


func _update_free_camera_movement(delta: float) -> void:
	var direction := Vector3.ZERO
	var forward := -_look_yaw.global_transform.basis.z
	var right := _look_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	if Input.is_key_pressed(KEY_W):
		direction += forward
	if Input.is_key_pressed(KEY_S):
		direction -= forward
	if Input.is_key_pressed(KEY_D):
		direction += right
	if Input.is_key_pressed(KEY_A):
		direction -= right
	if direction.length_squared() > 0.0:
		var speed := FREE_CAMERA_SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else FREE_CAMERA_WALK_SPEED
		_camera_rig.global_position += direction.normalized() * speed * delta

	var crouching := Input.is_key_pressed(KEY_CTRL)
	var target_offset := Vector3(0.0, -FREE_CAMERA_CROUCH_OFFSET if crouching else 0.0, 0.0)
	_camera.position = _camera.position.lerp(target_offset, clampf(delta * 12.0, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		_zoom_held = mouse_button.pressed
		get_viewport().set_input_as_handled()
		return
	if state == DinerState.MENU and not _order_locked:
		if event.is_action_pressed("menu_option_1"):
			_choose_order(&"lagman", 0)
		elif event.is_action_pressed("menu_option_2"):
			_choose_order(&"cutlet", 1)
		elif event.is_action_pressed("menu_option_3"):
			_choose_order(&"eggs", 2)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if state == DinerState.AFTER_MEAL and not LostSignalFlow.transition_in_progress:
		if event.is_action_pressed("restroom"):
			_go_to_restroom()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("interact"):
			_return_to_car()
			get_viewport().set_input_as_handled()
			return
	if LostSignalInputLock.is_locked():
		return
	var motion := event as InputEventMouseMotion
	if motion:
		if _is_free_camera_active():
			_yaw_target -= motion.relative.x * 0.00165
			_pitch_target = clampf(_pitch_target - motion.relative.y * 0.00165, deg_to_rad(-80), deg_to_rad(80))
		else:
			var yaw_limit := 18.0 if _walking else 28.0
			_yaw_target = clampf(_yaw_target - motion.relative.x * 0.00165, deg_to_rad(-yaw_limit), deg_to_rad(yaw_limit))
			_pitch_target = clampf(_pitch_target - motion.relative.y * 0.00165, deg_to_rad(-13), deg_to_rad(18))


func _build_environment() -> void:
	add_child(LostSignalVisualFactory.make_night_environment(0.004, 0.3))
	LostSignalVisualFactory.make_star_field(self, 240, 150.0, 8813)
	var moon := DirectionalLight3D.new()
	moon.name = "ColdMoonFill"
	moon.rotation_degrees = Vector3(-46, -34, 0)
	moon.light_color = Color(0.31, 0.43, 0.64)
	moon.light_energy = 0.34
	moon.shadow_enabled = false
	add_child(moon)


func _build_architecture() -> void:
	_diner_tables_root = _make_scene_group("DinerTables")
	_diner_decor_root = _make_scene_group("DinerDecor")
	_entrance_props_root = _make_scene_group("EntranceProps")
	_diner_floor_root = _make_scene_group("Floor")
	var asphalt := LostSignalVisualFactory.material(Color(0.022, 0.027, 0.032), 0.82)
	var wall := LostSignalVisualFactory.material(Color(0.26, 0.28, 0.27), 0.72)
	var wall_dark := LostSignalVisualFactory.material(Color(0.08, 0.095, 0.1), 0.78, 0.05)
	var ceiling := LostSignalVisualFactory.material(Color(0.31, 0.32, 0.3), 0.9)
	var counter_mat := LostSignalVisualFactory.material(Color(0.17, 0.12, 0.085), 0.62)
	var steel := LostSignalVisualFactory.material(Color(0.25, 0.28, 0.29), 0.24, 0.72)
	var red := LostSignalVisualFactory.material(Color(0.25, 0.035, 0.025), 0.7)
	var neon := LostSignalVisualFactory.material(Color(0.68, 0.82, 0.84), 0.3, 0.0, Color(0.78, 0.96, 1.0), 4.2)
	var warm := LostSignalVisualFactory.material(Color(0.34, 0.18, 0.07), 0.48, 0.0, Color(1.0, 0.52, 0.22), 1.8)
	var glass := LostSignalVisualFactory.material(Color(0.08, 0.14, 0.16, 0.28), 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var window_glow := LostSignalVisualFactory.material(Color(0.20, 0.27, 0.27), 0.42, 0.0, Color(0.38, 0.56, 0.58), 1.45)

	LostSignalVisualFactory.box(self, "ParkingAsphalt", Vector3(38, 0.18, 34), Vector3(0, -0.15, 9), asphalt, Vector3.ZERO, false)
	for line in 6:
		LostSignalVisualFactory.box(self, "ParkingLine%02d" % line, Vector3(0.10, 0.02, 7.0), Vector3(-13.5 + line * 5.2, -0.04, 14.0), neon, Vector3.ZERO, false)
	_build_hero_car(Vector3(-7.5, 0.45, 11.0), wall_dark, steel, glass, red)

	var building := Node3D.new()
	building.name = "DinerArchitecture"
	add_child(building)
	LostSignalVisualFactory.box(_diner_floor_root, "WoodCabinetWornLongFloor", Vector3(22, 0.18, 18), Vector3(0, -0.08, -4), DINER_FLOOR_MATERIAL, Vector3.ZERO, false)
	LostSignalVisualFactory.box(building, "Ceiling", Vector3(22, 0.22, 18), Vector3(0, 4.25, -4), ceiling)
	LostSignalVisualFactory.box(building, "BackWall", Vector3(22, 4.4, 0.25), Vector3(0, 2.1, -13), wall)
	LostSignalVisualFactory.box(building, "LeftWall", Vector3(0.25, 4.4, 18), Vector3(-11, 2.1, -4), wall)
	LostSignalVisualFactory.box(building, "RightWall", Vector3(0.25, 4.4, 18), Vector3(11, 2.1, -4), wall)
	_add_box_occluder(building, "BackWallOccluder", Vector3(22, 4.4, 0.2), Vector3(0, 2.1, -13))
	_add_box_occluder(building, "LeftWallOccluder", Vector3(0.2, 4.4, 18), Vector3(-11, 2.1, -4))
	_add_box_occluder(building, "RightWallOccluder", Vector3(0.2, 4.4, 18), Vector3(11, 2.1, -4))
	for section in [-8.5, -5.5, -2.5, 2.5, 5.5, 8.5]:
		LostSignalVisualFactory.box(building, "FacadeSection", Vector3(2.3, 4.4, 0.25), Vector3(section, 2.1, 5), wall_dark)
	for window_x in [-7.0, -4.0, 4.0, 7.0]:
		LostSignalVisualFactory.box(building, "FrontWindow", Vector3(2.65, 2.7, 0.04), Vector3(window_x, 2.25, 4.86), glass, Vector3.ZERO, false)
		LostSignalVisualFactory.box(building, "WindowGlow", Vector3(2.55, 2.58, 0.025), Vector3(window_x, 2.25, 4.82), window_glow, Vector3.ZERO, false)
	_door = Node3D.new()
	_door.name = "AutomaticGlassDoor"
	_door.position = Vector3(-0.95, 0, 4.87)
	building.add_child(_door)
	LostSignalVisualFactory.box(_door, "Frame", Vector3(1.85, 3.65, 0.12), Vector3(0.95, 1.82, 0), steel)
	LostSignalVisualFactory.box(_door, "Glass", Vector3(1.58, 3.28, 0.04), Vector3(0.95, 1.77, -0.03), glass, Vector3.ZERO, false)
	LostSignalVisualFactory.box(building, "NeonRoofLine", Vector3(22.3, 0.13, 0.13), Vector3(0, 4.35, 4.8), neon, Vector3.ZERO, false)
	var sign := LostSignalVisualFactory.label_3d(building, "NeonSign", "TÚN  •  ТҮНГІ АС", Vector3(0, 5.52, 4.7), 112, Color(0.78, 0.95, 1.0))
	sign.outline_size = 12

	var counter := Node3D.new()
	counter.name = "DinerCounter"
	building.add_child(counter)
	LostSignalVisualFactory.box(counter, "CounterBase", Vector3(9.2, 1.12, 1.15), Vector3(1.0, 0.56, -9.0), counter_mat)
	LostSignalVisualFactory.box(counter, "CounterTop", Vector3(9.5, 0.13, 1.42), Vector3(1.0, 1.17, -8.95), steel)
	for panel in 5:
		LostSignalVisualFactory.box(counter, "FrontPanel%02d" % panel, Vector3(1.55, 0.78, 0.05), Vector3(-2.4 + panel * 1.7, 0.58, -8.39), red)
	_build_register(counter, Vector3(-1.4, 1.38, -8.73), wall_dark, warm)
	_build_kitchen(counter, wall_dark, steel, neon)
	_build_tables(_diner_tables_root, counter_mat, red, steel)
	_build_polyhaven_decor()
	_build_diner_dressing(building, steel, warm, red)
	_build_lights(building)


func _build_hero_car(position: Vector3, body: Material, metal: Material, glass: Material, red: Material) -> void:
	var packed_car := load("res://assets/lost_signal/vehicle/quaternius_cars/NormalCar1.fbx") as PackedScene
	if packed_car:
		var imported_car := packed_car.instantiate() as Node3D
		if imported_car:
			imported_car.name = "QuaterniusParkedCar_CC0"
			imported_car.position = Vector3(position.x, 1.18, position.z)
			imported_car.rotation_degrees = Vector3(90.0, -18.0, 0.0)
			add_child(imported_car)
			return
	var root := Node3D.new()
	root.name = "ParkedHeroSedan"
	root.position = position
	root.rotation_degrees.y = -18.0
	add_child(root)
	LostSignalVisualFactory.box(root, "Body", Vector3(2.0, 0.62, 4.35), Vector3(0, 0.42, 0), body, Vector3(-2, 0, 0))
	LostSignalVisualFactory.box(root, "Cabin", Vector3(1.72, 0.72, 2.25), Vector3(0, 1.0, 0.1), metal)
	LostSignalVisualFactory.box(root, "Windshield", Vector3(1.52, 0.58, 0.04), Vector3(0, 1.04, -1.06), glass, Vector3(-24, 0, 0), false)
	for x in [-0.91, 0.91]:
		for z in [-1.38, 1.38]:
			LostSignalVisualFactory.cylinder(root, "Wheel", 0.34, 0.20, Vector3(x, 0.25, z), metal, Vector3(0, 0, 90), 18)
	for x in [-0.68, 0.68]:
		LostSignalVisualFactory.box(root, "TailLight", Vector3(0.42, 0.18, 0.04), Vector3(x, 0.62, 2.18), red, Vector3.ZERO, false)


func _add_box_occluder(parent: Node, occluder_name: String, size: Vector3, position: Vector3) -> void:
	var instance := OccluderInstance3D.new()
	instance.name = occluder_name
	var shape := BoxOccluder3D.new()
	shape.size = size
	instance.occluder = shape
	instance.position = position
	parent.add_child(instance)


func _build_register(parent: Node3D, position: Vector3, dark: Material, warm: Material) -> void:
	var root := Node3D.new()
	root.name = "CashRegister"
	root.position = position
	parent.add_child(root)
	LostSignalVisualFactory.box(root, "RegisterBody", Vector3(0.62, 0.32, 0.46), Vector3.ZERO, dark, Vector3(-12, 0, 0))
	LostSignalVisualFactory.box(root, "Display", Vector3(0.45, 0.16, 0.025), Vector3(0, 0.08, -0.24), warm, Vector3(-12, 0, 0), false)
	for row in 3:
		for col in 5:
			LostSignalVisualFactory.box(root, "Key", Vector3(0.07, 0.025, 0.055), Vector3(-0.19 + col * 0.095, -0.10, -0.26 + row * 0.07), warm)


func _build_kitchen(parent: Node3D, dark: Material, steel: Material, neon: Material) -> void:
	LostSignalVisualFactory.box(parent, "KitchenDivider", Vector3(10.5, 2.9, 0.20), Vector3(1.0, 2.7, -10.4), dark)
	LostSignalVisualFactory.box(parent, "ServiceWindow", Vector3(6.0, 1.6, 0.08), Vector3(1.0, 2.75, -10.28), neon, Vector3.ZERO, false)
	for shelf in 3:
		LostSignalVisualFactory.box(parent, "KitchenShelf", Vector3(3.0, 0.08, 0.55), Vector3(4.5, 1.45 + shelf * 0.72, -11.55), steel)
	for pot in 4:
		LostSignalVisualFactory.cylinder(parent, "KitchenPot", 0.22 + pot * 0.02, 0.22, Vector3(3.4 + pot * 0.72, 1.68, -11.55), steel, Vector3.ZERO, 16)
	var fridge := _instantiate_asset(
		"res://assets/lost_signal/diner/quaternius_sushi_restaurant/environment/Environment_Fridge.gltf",
		parent, "QuaterniusFridge", Vector3(-3.7, 0, -11.55), Vector3.ONE * 0.56
	)
	if fridge:
		fridge.rotation_degrees.y = 180.0
	var oven := _instantiate_asset(
		"res://assets/lost_signal/diner/quaternius_sushi_restaurant/environment/Environment_Oven.gltf",
		parent, "QuaterniusOven", Vector3(-1.9, 0, -11.55), Vector3.ONE * 0.58
	)
	if oven:
		oven.rotation_degrees.y = 180.0


func _build_tables(parent: Node3D, wood: Material, seat: Material, steel: Material) -> void:
	var table_specs := [
		[Vector3(-6.6, 0, -2.8), -4.0],
		[Vector3(6.5, 0, -3.2), 7.0],
		[Vector3(-6.2, 0, -7.0), 2.0],
		[Vector3(6.1, 0, -7.0), -6.0],
		[Vector3(0.5, 0, -3.8), 1.5],
	]
	for spec in table_specs:
		var table := Node3D.new()
		table.name = "PolyHavenOutdoorTableChairSet"
		table.position = spec[0]
		table.rotation_degrees.y = float(spec[1])
		parent.add_child(table)
		table.scale = Vector3.ONE * 1.15
		var imported_table := POLYHAVEN_TABLE_SET.instantiate() as Node3D
		if imported_table:
			imported_table.name = "OutdoorTableChairSet01"
			table.add_child(imported_table)
			_set_shadow_recursive(imported_table)
		_add_box_collision(table, "TableChairSetCollision", Vector3(2.15, 1.05, 1.05), Vector3(0, 0.52, 0))


func _build_polyhaven_decor() -> void:
	var cabinet := POLYHAVEN_DRAWER_CABINET.instantiate() as Node3D
	if cabinet:
		cabinet.name = "PolyHavenDrawerCabinet"
		cabinet.position = Vector3(-8.85, 0.0, -12.55)
		cabinet.rotation_degrees.y = 180.0
		_diner_decor_root.add_child(cabinet)
		_set_shadow_recursive(cabinet)
		_add_box_collision(_diner_decor_root, "DrawerCabinetCollision", Vector3(1.25, 1.9, 0.58), cabinet.position)
	var shelves := POLYHAVEN_DISPLAY_SHELVES.instantiate() as Node3D
	if shelves:
		shelves.name = "PolyHavenWoodenDisplayShelves01"
		shelves.position = Vector3(7.95, 0.0, -12.48)
		shelves.rotation_degrees.y = 90.0
		_diner_decor_root.add_child(shelves)
		_set_shadow_recursive(shelves)
		_add_box_collision(_diner_decor_root, "DisplayShelvesCollision", Vector3(1.22, 1.65, 0.46), shelves.position)
	var chair := POLYHAVEN_ARM_CHAIR.instantiate() as Node3D
	if chair:
		chair.name = "PolyHavenModernArmChair01"
		chair.position = Vector3(2.15, 0.0, 5.85)
		chair.rotation_degrees.y = -24.0
		_entrance_props_root.add_child(chair)
		_set_shadow_recursive(chair)
		_add_box_collision(_entrance_props_root, "EntranceArmChairCollision", Vector3(1.05, 1.05, 1.15), chair.position)


func _make_scene_group(group_name: String) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	return group


func _add_box_collision(parent: Node3D, node_name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


func _set_shadow_recursive(root: Node) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in root.get_children():
		_set_shadow_recursive(child)


func _build_lights(parent: Node3D) -> void:
	for x in [-7.5, -2.5, 2.5, 7.5]:
		for z in [1.5, -4.0, -9.0]:
			var panel := OmniLight3D.new()
			panel.name = "ColdCeilingPanel"
			panel.position = Vector3(x, 3.9, z)
			panel.light_color = Color(0.73, 0.88, 0.94)
			panel.light_energy = 1.05
			panel.omni_range = 7.5
			panel.shadow_enabled = false
			parent.add_child(panel)
	var counter_light := OmniLight3D.new()
	counter_light.name = "WarmCounterKey"
	counter_light.position = Vector3(-1.2, 3.2, -7.4)
	counter_light.light_color = Color(1.0, 0.55, 0.29)
	counter_light.light_energy = 2.1
	counter_light.omni_range = 7.0
	counter_light.shadow_enabled = true
	parent.add_child(counter_light)
	var lounge_fill := OmniLight3D.new()
	lounge_fill.name = "WarmLoungeFill"
	lounge_fill.position = Vector3(0, 2.5, -2.0)
	lounge_fill.light_color = Color(0.83, 0.48, 0.28)
	lounge_fill.light_energy = 0.62
	lounge_fill.omni_range = 8.5
	lounge_fill.shadow_enabled = false
	parent.add_child(lounge_fill)


func _build_diner_dressing(parent: Node3D, steel: Material, warm: Material, red: Material) -> void:
	var stripe := LostSignalVisualFactory.material(Color(0.20, 0.032, 0.025), 0.68)
	LostSignalVisualFactory.box(parent, "BackWallColorBand", Vector3(20.8, 0.42, 0.05), Vector3(0, 1.32, -12.83), stripe)
	LostSignalVisualFactory.box(parent, "RightWallColorBand", Vector3(0.05, 0.42, 16.8), Vector3(10.83, 1.32, -4), stripe)
	for data in [
		["decoration/Decoration_Painting.gltf", "NightPaintingA", Vector3(-6.8, 2.35, -12.68), Vector3(0, 0, 0), 0.62],
		["decoration/Decoration_Painting_Small.gltf", "NightPaintingB", Vector3(0.2, 2.25, -12.70), Vector3(0, 0, 0), 0.64],
		["decoration/Decoration_Fish.gltf", "WallFish", Vector3(6.3, 2.40, -12.65), Vector3(0, 0, 0), 0.55],
		["decoration/Decoration_Plant1.gltf", "PlantLeft", Vector3(-9.3, 0.0, -10.4), Vector3(0, 35, 0), 0.76],
		["decoration/Decoration_Plant2.gltf", "PlantRight", Vector3(9.2, 0.0, -9.9), Vector3(0, -30, 0), 0.72],
		["decoration/Decoration_Bamboo.gltf", "BambooDivider", Vector3(9.4, 0.0, 2.6), Vector3(0, -22, 0), 0.72],
	]:
		var model := _instantiate_asset(
			"res://assets/lost_signal/diner/quaternius_sushi_restaurant/%s" % data[0],
			parent, String(data[1]), data[2], Vector3.ONE * float(data[4])
		)
		if model:
			model.rotation_degrees = data[3]
	for x in [-7.2, -3.6, 3.6, 7.2]:
		var pendant := _instantiate_asset(
			"res://assets/lost_signal/diner/quaternius_sushi_restaurant/decoration/Decoration_Light.gltf",
			parent, "QuaterniusPendant", Vector3(x, 3.25, -3.2), Vector3.ONE * 0.58
		)
		if pendant:
			pendant.rotation_degrees.y = 15.0
	for item in 4:
		var bottle := _instantiate_asset(
			"res://assets/lost_signal/diner/quaternius_sushi_restaurant/environment/Environment_Bottles.gltf",
			parent, "CounterBottleSet", Vector3(3.2 + item * 1.1, 1.26, -8.88), Vector3.ONE * 0.34
		)
		if bottle:
			bottle.rotation_degrees.y = item * 37.0
	LostSignalVisualFactory.box(parent, "MenuBoard", Vector3(3.8, 1.15, 0.08), Vector3(4.0, 2.63, -12.70), steel)
	var menu_text := LostSignalVisualFactory.label_3d(parent, "MenuBoardText", "ЛАГМАН  •  КОТЛЕТА  •  ЯИЧНИЦА\nШӘЙ  •  КОФЕ", Vector3(4.0, 2.63, -12.63), 38, Color(0.87, 0.62, 0.32))
	menu_text.outline_size = 2
	for x in [-4.4, 0.0, 4.4]:
		LostSignalVisualFactory.cylinder(parent, "CounterPendant", 0.16, 0.08, Vector3(x, 3.65, -8.2), warm, Vector3.ZERO, 18)


func _build_characters() -> void:
	var character_root := Node3D.new()
	character_root.name = "Characters"
	add_child(character_root)
	var waitress_model := WOMAN_WAITRESS_SCENE.instantiate() as Node3D
	if waitress_model != null:
		var waitress_route := WomanWaitressRoute.new()
		waitress_route.name = "WomanCashierAndWaitress"
		waitress_route.position = WAITRESS_CASHIER_POSITION
		character_root.add_child(waitress_route)
		waitress_model.name = "WomanWaitressPBR"
		waitress_model.scale = Vector3.ONE * WAITRESS_MODEL_SCALE
		waitress_route.add_child(waitress_model)
		waitress_route.configure(waitress_model)
		_cashier = waitress_route
		_server = waitress_route
		_server_home = WAITRESS_SERVICE_HOME
	else:
		_cashier = _spawn_animated_character(
			character_root,
			"res://assets/lost_signal/diner/quaternius_sushi_restaurant/characters/Rabbit_Grey.gltf",
			"CashierRabbit",
			WAITRESS_CASHIER_POSITION,
			0.43,
			180.0,
			&"Idle",
			0.8
		)
		if _cashier == null:
			_cashier = LostSignalVisualFactory.build_anthro_character(
				character_root,
				"CashierFox",
				WAITRESS_CASHIER_POSITION,
				Color(0.34, 0.12, 0.055),
				Color(0.055, 0.09, 0.1),
				true,
				true
			)
			_cashier.rotation_degrees.y = 180.0
		_characters.append(_cashier)
	var cat := LostSignalVisualFactory.build_anthro_character(character_root, "CatVisitor", Vector3(-6.6, 0, -3.15), Color(0.18, 0.16, 0.15), Color(0.11, 0.13, 0.14), true, true)
	cat.scale = Vector3.ONE * 0.92
	cat.rotation_degrees.y = 12.0
	_characters.append(cat)
	var rabbit := _spawn_animated_character(
		character_root,
		"res://assets/lost_signal/diner/quaternius_sushi_restaurant/characters/Panda.gltf",
		"PandaVisitor", Vector3(6.5, 0, -3.5), 0.48, -20.0, &"Sitting_Idle", 2.4
	)
	if rabbit == null:
		rabbit = LostSignalVisualFactory.build_anthro_character(character_root, "RabbitVisitor", Vector3(6.5, 0, -3.5), Color(0.42, 0.4, 0.36), Color(0.16, 0.12, 0.1), true, false)
		rabbit.scale = Vector3.ONE * 0.95
		rabbit.rotation_degrees.y = -20.0
	_characters.append(rabbit)
	if _server == null:
		_server = LostSignalVisualFactory.build_anthro_character(
			character_root,
			"FallbackServer",
			WAITRESS_SERVICE_HOME,
			Color(0.78, 0.78, 0.72),
			Color(0.09, 0.11, 0.12),
			true,
			false
		)
		_server.rotation_degrees.y = 180.0
		_characters.append(_server)
		_server_home = _server.position
	_build_npc_props(cat, rabbit)


func _build_npc_props(cat: Node3D, rabbit: Node3D) -> void:
	var ceramic := LostSignalVisualFactory.material(Color(0.58, 0.66, 0.65), 0.3)
	LostSignalVisualFactory.cylinder(cat, "TeaMug", 0.09, 0.18, Vector3(0.31, 0.96, -0.30), ceramic, Vector3.ZERO, 16)
	LostSignalVisualFactory.cylinder(rabbit, "CoffeeCup", 0.10, 0.20, Vector3(-0.28, 0.96, -0.28), ceramic, Vector3.ZERO, 16)


func _spawn_animated_character(
	parent: Node,
	path: String,
	character_name: String,
	position: Vector3,
	scale_value: float,
	yaw: float,
	animation: StringName,
	offset: float
) -> Node3D:
	var node := _instantiate_asset(path, parent, character_name, position, Vector3.ONE * scale_value)
	if node == null:
		return null
	node.rotation_degrees.y = yaw
	node.set_meta("idle_phase", offset)
	_play_character_animation(node, animation, offset)
	return node


func _instantiate_asset(path: String, parent: Node, asset_name: String, position: Vector3, scale_value: Vector3) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = asset_name
	instance.position = position
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


func _play_character_animation(character: Node, animation: StringName, offset := 0.0) -> void:
	var players := character.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	if player.has_animation(animation):
		player.play(animation)
		var clip := player.get_animation(animation)
		if clip and clip.length > 0.0:
			player.seek(fmod(offset, clip.length), true)


func _build_camera_and_paths() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "FirstPersonCinematicRig"
	add_child(_camera_rig)
	_look_yaw = Node3D.new()
	_look_yaw.name = "LocalLookYaw"
	_camera_rig.add_child(_look_yaw)
	_look_pitch = Node3D.new()
	_look_pitch.name = "LocalLookPitch"
	_look_yaw.add_child(_look_pitch)
	_camera = Camera3D.new()
	_camera.name = "CinematicCamera"
	_camera.current = true
	_camera.fov = 70.0
	_base_camera_fov = _camera.fov
	_camera.near = 0.05
	_camera.far = 180.0
	_look_pitch.add_child(_camera)
	_base_camera_offset = Vector3.ZERO
	_entry_path = _make_path("EntryPath", [
		Vector3(-7.5, 1.62, 11.5), Vector3(-5.0, 1.62, 9.0),
		Vector3(-1.0, 1.62, 6.5), Vector3(0.0, 1.62, 4.0),
		Vector3(0.0, 1.62, 0.2), Vector3(-3.5, 1.62, -2.3),
		Vector3(-2.2, 1.62, -6.4), Vector3(-1.4, 1.62, -7.3),
	])
	_table_path = _make_path("TablePath", [
		Vector3(-1.4, 1.62, -7.3), Vector3(-0.2, 1.62, -6.0),
		Vector3(2.4, 1.62, -5.2), Vector3(3.5, 1.55, -3.8),
		Vector3(1.8, 1.42, -2.4), Vector3(0.5, 1.19, -2.65),
	])


func _make_path(path_name: String, points: Array[Vector3]) -> Path3D:
	var path := Path3D.new()
	path.name = path_name
	var curve := Curve3D.new()
	curve.bake_interval = 0.15
	for point_index in points.size():
		var point := points[point_index]
		var previous := points[maxi(0, point_index - 1)]
		var next := points[mini(points.size() - 1, point_index + 1)]
		var tangent := (next - previous).normalized() * minf(1.6, point.distance_to(next) * 0.28)
		curve.add_point(point, -tangent, tangent)
	path.curve = curve
	add_child(path)
	return path


func _build_meals() -> void:
	_meal_root = Node3D.new()
	_meal_root.name = "MealPresenter_ThreeOrders_ThreeStates"
	_meal_root.position = Vector3(0.5, 0.96, -3.1)
	add_child(_meal_root)
	var ceramic := LostSignalVisualFactory.material(Color(0.68, 0.72, 0.7), 0.26)
	for order in [&"lagman", &"cutlet", &"eggs"]:
		for stage in [&"full", &"partial", &"empty"]:
			var key := "%s_%s" % [order, stage]
			var root := Node3D.new()
			root.name = key.capitalize()
			root.visible = false
			_meal_root.add_child(root)
			_meal_states[key] = root
			LostSignalVisualFactory.cylinder(root, "Plate", 0.38, 0.035, Vector3.ZERO, ceramic, Vector3.ZERO, 28)
			_build_dish_contents(root, order, stage)


func _build_dish_contents(root: Node3D, order: StringName, stage: StringName) -> void:
	var broth := LostSignalVisualFactory.material(Color(0.30, 0.105, 0.035), 0.52)
	var noodle := LostSignalVisualFactory.material(Color(0.74, 0.51, 0.17), 0.72)
	var meat := LostSignalVisualFactory.material(Color(0.25, 0.095, 0.045), 0.78)
	var potato := LostSignalVisualFactory.material(Color(0.62, 0.48, 0.21), 0.82)
	var egg_white := LostSignalVisualFactory.material(Color(0.8, 0.78, 0.65), 0.55)
	var yolk := LostSignalVisualFactory.material(Color(0.9, 0.43, 0.05), 0.48)
	var sausage := LostSignalVisualFactory.material(Color(0.52, 0.11, 0.075), 0.68)
	if stage == &"empty":
		LostSignalVisualFactory.cylinder(root, "SauceTrace", 0.13, 0.007, Vector3(0.09, 0.024, -0.03), broth, Vector3.ZERO, 18)
		return
	var amount := 1.0 if stage == &"full" else 0.48
	match order:
		&"lagman":
			if stage == &"full":
				var udon := _instantiate_asset(
					"res://assets/lost_signal/diner/quaternius_sushi_restaurant/food/Food_Udon.gltf",
					root, "QuaterniusUdonBase", Vector3(0, 0.035, 0), Vector3.ONE * 0.38
				)
				if udon:
					udon.rotation_degrees.y = 23.0
			LostSignalVisualFactory.cylinder(root, "Bowl", 0.31, 0.11, Vector3(0, 0.07, 0), broth, Vector3.ZERO, 28)
			for item in int(11 * amount):
				var angle := float(item) * 1.71
				LostSignalVisualFactory.cylinder(root, "Noodle", 0.018, 0.25, Vector3(cos(angle) * 0.17, 0.15, sin(angle) * 0.17), noodle, Vector3(90, rad_to_deg(angle), 0), 7)
		&"cutlet":
			LostSignalVisualFactory.sphere(root, "Cutlet", 0.22, Vector3(-0.11, 0.075, 0.02), meat, Vector3(1.25 * amount, 0.38, 0.82))
			for item in int(8 * amount):
				LostSignalVisualFactory.sphere(root, "Potato", 0.085, Vector3(0.08 + (item % 3) * 0.095, 0.08, -0.17 + (item / 3) * 0.10), potato, Vector3(1.25, 0.65, 1.0))
		&"eggs":
			LostSignalVisualFactory.sphere(root, "EggWhite", 0.25, Vector3(-0.08, 0.045, 0), egg_white, Vector3(1.25 * amount, 0.18, 0.85))
			LostSignalVisualFactory.sphere(root, "Yolk", 0.09, Vector3(-0.08, 0.085, 0), yolk, Vector3(1, 0.55, 1))
			for item in int(4 * amount):
				LostSignalVisualFactory.cylinder(root, "Sausage", 0.05, 0.26, Vector3(0.16, 0.07, -0.18 + item * 0.11), sausage, Vector3(0, 0, 75), 12)


func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "DinerMenuUI"
	_menu_layer.layer = 140
	add_child(_menu_layer)
	_menu_panel = PanelContainer.new()
	_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	_menu_panel.position = Vector2(-375, -250)
	_menu_panel.size = Vector2(750, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.028, 0.97)
	style.border_color = Color(0.46, 0.34, 0.20, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 45
	style.content_margin_right = 45
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	_menu_panel.add_theme_stylebox_override("panel", style)
	_menu_panel.visible = false
	_menu_layer.add_child(_menu_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	_menu_panel.add_child(layout)
	var title := Label.new()
	title.text = "ТҮНГІ МӘЗІР  /  НОЧНОЕ МЕНЮ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(0.82, 0.72, 0.51))
	layout.add_child(title)
	var rule := HSeparator.new()
	layout.add_child(rule)
	var dishes := ["1  —  ЛАГМАН", "2  —  КОТЛЕТА С КАРТОФЕЛЕМ", "3  —  ЯИЧНИЦА С КОЛБАСОЙ"]
	for index in dishes.size():
		var button := Button.new()
		button.text = dishes[index]
		button.custom_minimum_size = Vector2(0, 78)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 23)
		button.pressed.connect(_on_menu_button_pressed.bind(index))
		layout.add_child(button)
		_menu_buttons.append(button)
	var hint := Label.new()
	hint.text = "Выберите клавишей 1 / 2 / 3 или мышью"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.52, 0.57, 0.54))
	layout.add_child(hint)


func _run_entry_sequence() -> void:
	state = DinerState.ENTERING
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_ENTERING)
	hud.show_chapter("LOST SIGNAL / 02", "Закусочная у трассы", 3.0)
	hud.set_objective("Автоматический путь к стойке")
	hud.set_status("02:24   •   Открыто 24 часа")
	get_tree().create_timer(6.2).timeout.connect(_open_door)
	await _travel_path(_entry_path, 15.8)
	if not is_inside_tree():
		return
	_face_horizontal_target(_cashier.global_position)
	state = DinerState.AT_COUNTER
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_AT_COUNTER)
	_yaw_target = 0.0
	_pitch_target = 0.0
	hud.set_objective("")
	await get_tree().create_timer(0.35).timeout
	hud.show_subtitle("Кассир", "Доброй ночи. Что будете заказывать?", 2.7)
	await get_tree().create_timer(2.8).timeout
	_show_menu()


func _travel_path(path: Path3D, duration: float) -> void:
	_walking = true
	_walk_phase = 0.0
	var elapsed := 0.0
	var length := path.curve.get_baked_length()
	while elapsed < duration and is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree() or path == null or not is_instance_valid(path):
			return
		var delta := get_process_delta_time()
		elapsed += delta
		var ratio := clampf(elapsed / duration, 0.0, 1.0)
		var smooth_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
		var local_transform := path.curve.sample_baked_with_rotation(length * smooth_ratio, true, true)
		_camera_rig.global_transform = path.global_transform * local_transform
	_walking = false


func _face_horizontal_target(target: Vector3) -> void:
	var horizontal_target := target
	horizontal_target.y = _camera_rig.global_position.y
	if _camera_rig.global_position.distance_squared_to(horizontal_target) < 0.0001:
		return
	_camera_rig.look_at(horizontal_target, Vector3.UP)
	_yaw_target = 0.0
	_pitch_target = 0.0
	_look_yaw.rotation = Vector3.ZERO
	_look_pitch.rotation = Vector3.ZERO


func _open_door() -> void:
	if _door == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_door, "position:x", -2.7, 0.9)
	var chime_stream := load("res://assets/lost_signal/audio/diner/shop_doorbell_chime_3588.ogg") as AudioStream
	if chime_stream:
		var chime := AudioStreamPlayer3D.new()
		chime.name = "CC0ShopDoorChime"
		chime.stream = chime_stream
		chime.bus = &"SFX"
		chime.position = Vector3(0, 3.0, 4.7)
		add_child(chime)
		chime.play()
		chime.finished.connect(chime.queue_free)


func _show_menu() -> void:
	state = DinerState.MENU
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_MENU)
	_menu_panel.visible = true
	_menu_panel.modulate.a = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	create_tween().tween_property(_menu_panel, "modulate:a", 1.0, 0.24)
	_menu_buttons[0].grab_focus()
	if LostSignalFlow.qa_enabled:
		var ids: Array[StringName] = [&"lagman", &"cutlet", &"eggs"]
		var index := clampi(LostSignalFlow.qa_run - 1, 0, 2)
		get_tree().create_timer(0.35).timeout.connect(_choose_order.bind(ids[index], index))


func _on_menu_button_pressed(index: int) -> void:
	var ids: Array[StringName] = [&"lagman", &"cutlet", &"eggs"]
	_choose_order(ids[index], index)


func _choose_order(order_id: StringName, index: int) -> void:
	if _order_locked or state != DinerState.MENU or not LostSignalFlow.select_order(order_id):
		return
	_order_locked = true
	state = DinerState.ORDER_CONFIRMED
	_menu_buttons[index].text = "✓  " + _menu_buttons[index].text
	for button in _menu_buttons:
		button.disabled = true
	_cashier_press = 0.55
	var woman_cashier := _cashier is WomanWaitressRoute
	if woman_cashier:
		(_cashier as WomanWaitressRoute).play_gesture(&"Look_Back_Over_Shoulder")
	else:
		_play_character_animation(_cashier, &"Punch")
	LostSignalProceduralAmbience.play_one_shot(
		self,
		"res://assets/lost_signal/audio/generated/lost_signal_register_oneshot.wav",
		&"SFX", -6.0
	)
	await get_tree().create_timer(0.58).timeout
	if not woman_cashier:
		_play_character_animation(_cashier, &"Idle", 1.3)
	hud.show_subtitle("Кассир", "Спасибо за выбор. Ас болсын.", 2.8)
	await get_tree().create_timer(2.85).timeout
	if woman_cashier:
		(_cashier as WomanWaitressRoute).play_idle()
	var tween := create_tween()
	tween.tween_property(_menu_panel, "modulate:a", 0.0, 0.22)
	await tween.finished
	_menu_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_run_table_sequence()


func _run_table_sequence() -> void:
	state = DinerState.GOING_TO_TABLE
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_GOING_TO_TABLE)
	hud.set_objective("Проход к свободному столику")
	await _travel_path(_table_path, 8.4)
	if not is_inside_tree():
		return
	_face_horizontal_target(_meal_root.global_position)
	state = DinerState.SEATED
	_yaw_target = 0.0
	_pitch_target = deg_to_rad(-5.0)
	hud.set_objective("")
	await get_tree().create_timer(2.3).timeout
	_run_meal_sequence()


func _run_meal_sequence() -> void:
	state = DinerState.SERVING
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_WAITING_FOR_FOOD)
	var begin_server := func() -> void:
		_start_server_delivery()
	blink.full_dark.connect(begin_server, CONNECT_ONE_SHOT)
	await blink.blink()
	await _move_server_to_table()
	_set_meal_stage(&"full")
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_FOOD_DELIVERED)
	hud.show_subtitle("Сотрудник", "Ваш заказ.", 2.1)
	_run_waitress_return_and_foreground_pass()
	await get_tree().create_timer(2.25).timeout
	state = DinerState.EATING
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_EATING)
	_pitch_target = deg_to_rad(-18.0)
	await get_tree().create_timer(0.7).timeout
	await _blink_to_meal_stage(&"partial")
	LostSignalProceduralAmbience.play_one_shot(
		self,
		"res://assets/lost_signal/audio/generated/lost_signal_cutlery_oneshot.wav",
		&"SFX", -12.0
	)
	hud.set_status("Тихий звон приборов   •   %s" % LostSignalFlow.order_display_name())
	await get_tree().create_timer(1.45).timeout
	await _blink_to_meal_stage(&"empty")
	while _waitress_cycle_running and is_inside_tree():
		await get_tree().process_frame
	LostSignalFlow.meal_finished = true
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_AFTER_MEAL)
	_pitch_target = deg_to_rad(-5.0)
	await get_tree().create_timer(0.35).timeout
	_enable_after_meal_choice()


func _start_server_delivery() -> void:
	_server.position = _server_home
	_server.rotation.y = 0.0
	_server.visible = true
	if _server is WomanWaitressRoute:
		(_server as WomanWaitressRoute).play_idle()
	else:
		_play_character_animation(_server, &"Walk_Holding", 0.4)


func _move_server_to_table() -> void:
	if _server is WomanWaitressRoute:
		await (_server as WomanWaitressRoute).walk_points(WAITRESS_DELIVERY_ROUTE)
		return
	var path_points := [
		Vector3(3.2, 0, -9.8),
		Vector3(3.1, 0, -6.0),
		Vector3(2.4, 0, -4.2),
		Vector3(1.2, 0, -3.1),
	]
	for point in path_points:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_server, "position", point, 0.55)
		await tween.finished
	_play_character_animation(_server, &"Idle_Holding", 0.9)


func _run_waitress_return_and_foreground_pass() -> void:
	if _waitress_cycle_running or not (_server is WomanWaitressRoute):
		return
	_waitress_cycle_running = true
	var waitress := _server as WomanWaitressRoute
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree() or not is_instance_valid(waitress):
		return
	await waitress.walk_points(WAITRESS_RETURN_ROUTE, 2.05)
	if not is_inside_tree() or not is_instance_valid(waitress):
		return
	# She remains behind the bar for exactly three seconds before emerging again.
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or not is_instance_valid(waitress):
		return
	await waitress.walk_points(WAITRESS_FOREGROUND_ROUTE, 2.0)
	if not is_inside_tree() or not is_instance_valid(waitress):
		return
	# The supplied nine-second final clip performs its authored approach, turn,
	# look and exit as one motion directly in front of the seated player.
	await waitress.play_longest_sequence(deg_to_rad(-90.0))
	if not is_inside_tree() or not is_instance_valid(waitress):
		return
	# Continue farther across the player's view and finish on the far side of the
	# table. She remains there, facing the seated player, instead of teleporting.
	await waitress.walk_points(WAITRESS_FINAL_TABLE_ROUTE, 1.45)
	if not is_inside_tree() or not is_instance_valid(waitress):
		return
	waitress.rotation.y = 0.0
	waitress.play_idle()
	_waitress_cycle_running = false


func _blink_to_meal_stage(stage: StringName) -> void:
	var swap := func() -> void:
		_set_meal_stage(stage)
	blink.full_dark.connect(swap, CONNECT_ONE_SHOT)
	await blink.blink()


func _set_meal_stage(stage: StringName) -> void:
	for node: Node3D in _meal_states.values():
		node.visible = false
	var key := "%s_%s" % [LostSignalFlow.selected_order, stage]
	if _meal_states.has(key):
		(_meal_states[key] as Node3D).visible = true


func _enable_after_meal_choice() -> void:
	state = DinerState.AFTER_MEAL
	hud.show_prompt("WASD — ходить   Ctrl — пригнуться   ПКМ — приблизить   F — туалет   E — машина")
	hud.set_objective("Выберите, куда идти после еды")
	hud.set_status("Заказ завершён   •   %s" % LostSignalFlow.order_display_name())
	if LostSignalFlow.qa_enabled:
		if LostSignalFlow.qa_run == 1 and not LostSignalFlow.restroom_visited:
			get_tree().create_timer(0.8).timeout.connect(_go_to_restroom)
		else:
			get_tree().create_timer(0.8).timeout.connect(_return_to_car)
			if LostSignalFlow.qa_run == 3:
				get_tree().create_timer(0.82).timeout.connect(_return_to_car)


func _go_to_restroom() -> void:
	if state != DinerState.AFTER_MEAL or LostSignalFlow.transition_in_progress:
		return
	state = DinerState.TRANSITIONING
	hud.hide_prompt()
	var transition := func() -> void:
		if LostSignalFlow.transition_to(LostSignalFlow.RESTROOM_SCENE, LostSignalFlow.FlowState.RESTROOM_INSIDE):
			LostSignalFlow.restroom_visited = true
	blink.full_dark.connect(transition, CONNECT_ONE_SHOT)
	blink.blink(0.22)


func _return_to_car() -> void:
	if state != DinerState.AFTER_MEAL or LostSignalFlow.transition_in_progress:
		return
	state = DinerState.TRANSITIONING
	hud.hide_prompt()
	var transition := func() -> void:
		LostSignalFlow.transition_to(LostSignalFlow.FOREST_SCENE, LostSignalFlow.FlowState.BACK_IN_CAR)
	blink.full_dark.connect(transition, CONNECT_ONE_SHOT)
	blink.blink(0.22)


func _restore_after_restroom() -> void:
	state = DinerState.AFTER_MEAL
	var end_transform := _table_path.curve.sample_baked_with_rotation(_table_path.curve.get_baked_length(), true, true)
	_camera_rig.global_transform = _table_path.global_transform * end_transform
	_face_horizontal_target(_meal_root.global_position)
	_set_meal_stage(&"empty")
	if _server is WomanWaitressRoute:
		_server.position = WAITRESS_OPPOSITE_TABLE_POSITION
		_server.rotation.y = 0.0
		_server.visible = true
		(_server as WomanWaitressRoute).play_idle()
	hud.show_chapter("LOST SIGNAL / 02", "Возвращение в зал", 2.1)
	if LostSignalFlow.washed_face:
		hud.show_subtitle("", "Холодная вода немного прояснила голову.", 2.2)
	_enable_after_meal_choice()


func _animate_characters(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for index in _characters.size():
		var character := _characters[index]
		var phase := float(character.get_meta("idle_phase", 0.0)) + now
		character.position.y = sin(phase * (1.1 + index * 0.08)) * 0.006
		var head := character.get_node_or_null("Head") as Node3D
		if head:
			head.rotation_degrees.y = sin(phase * 0.55) * (2.3 + index)
			head.rotation_degrees.x = sin(phase * 0.83 + index) * 1.2
		var tail := character.get_node_or_null("Tail") as Node3D
		if tail:
			tail.rotation_degrees.z = -25.0 + sin(phase * 0.72) * 12.0
	if _server and state == DinerState.SERVING:
		var step := sin(now * 9.0)
		var left_leg := _server.get_node_or_null("LegL") as Node3D
		var right_leg := _server.get_node_or_null("LegR") as Node3D
		if left_leg: left_leg.rotation_degrees.x = step * 18.0
		if right_leg: right_leg.rotation_degrees.x = -step * 18.0


func _exit_tree() -> void:
	for node in find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		player.stop()
		player.stream = null
