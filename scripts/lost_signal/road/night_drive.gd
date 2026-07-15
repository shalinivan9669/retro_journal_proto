extends Node3D

@export_range(0.0, 0.02, 0.0001) var camera_vibration_strength := 0.0025
@export_range(40.0, 500.0, 1.0) var fog_distance := 210.0
@export_range(1.0, 10.0, 0.5) var route_length_multiplier := 6.0

const BASE_ARRIVAL_DISTANCE := 270.0
const BASE_END_DISTANCE := 342.0
const BASE_DINER_DISTANCE := 390.0

@onready var vehicle: LostSignalVehicleInterior = $VehicleInterior
@onready var road: LostSignalLoopingRoad = $LoopingRoad
@onready var hud: LostSignalHUD = $LostSignalHUD

var _dashcam: LostSignalDashcamSystem
var _diner_proxy: Node3D
var _arrival_started := false
var _base_camera_position := Vector3.ZERO
var _yaw_target := 0.0
var _pitch_target := 0.0


func _ready() -> void:
	LostSignalFlow.start_new_run()
	LostSignalFlow.set_state(LostSignalFlow.FlowState.NIGHT_DRIVE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	build_environment()
	LostSignalProceduralAmbience.add_player(self, "EngineLoop", LostSignalProceduralAmbience.Kind.ENGINE, &"Vehicle", -15.0)
	LostSignalProceduralAmbience.add_player(self, "TireRoadLoop", LostSignalProceduralAmbience.Kind.ROAD, &"Vehicle", -21.0)
	_dashcam = LostSignalDashcamSystem.new()
	_dashcam.name = "DashcamSystem"
	add_child(_dashcam)
	_dashcam.setup(vehicle.camera, vehicle.dashcam_focus_anchor, vehicle.front_feed_anchor, vehicle.rear_feed_anchor, vehicle.dashcam_screen_mesh)
	if LostSignalFlow.qa_enabled:
		_run_qa_dashcam_check()
	_base_camera_position = vehicle.camera.position
	road.distance_advanced.connect(_on_distance_advanced)
	hud.show_chapter("LOST SIGNAL / 01", "Ночная трасса", 3.0)
	hud.set_objective("E — посмотреть видеорегистратор")
	hud.set_status("Скорость 76 км/ч   •   Северная трасса   •   02:17")


func build_environment() -> void:
	var balkhash_environment := BalkhashRoadEnvironment.new()
	balkhash_environment.name = "DistantBackdrop"
	balkhash_environment.fog_distance = fog_distance
	add_child(balkhash_environment)
	var moon := DirectionalLight3D.new()
	moon.name = "MoonFill"
	moon.rotation_degrees = Vector3(-36, -28, 0)
	moon.light_color = Color(0.34, 0.46, 0.7)
	moon.light_energy = 0.055
	moon.light_volumetric_fog_energy = 0.02
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 95.0
	moon.directional_shadow_fade_start = 0.72
	add_child(moon)
	_build_diner_proxy()


func _build_distant_horizon() -> void:
	var silhouette := LostSignalVisualFactory.material(Color(0.008, 0.014, 0.022), 1.0)
	var random := RandomNumberGenerator.new()
	random.seed = 7151
	for index in 18:
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := side * random.randf_range(34.0, 88.0)
		var z := random.randf_range(-205.0, -105.0)
		var height := random.randf_range(2.5, 7.5)
		LostSignalVisualFactory.box(self, "DistantMass%02d" % index, Vector3(random.randf_range(15, 34), height, random.randf_range(12, 28)), Vector3(x, height * 0.45 - 0.2, z), silhouette, Vector3(0, random.randf_range(-20, 20), random.randf_range(-3, 3)), false)


func _build_diner_proxy() -> void:
	_diner_proxy = Node3D.new()
	_diner_proxy.name = "ArrivalDinerProxy"
	_diner_proxy.position = Vector3(10.5, 0, -_diner_start_distance())
	add_child(_diner_proxy)
	var wall := LostSignalVisualFactory.material(Color(0.12, 0.13, 0.14), 0.72, 0.08)
	var glass := LostSignalVisualFactory.material(Color(0.42, 0.58, 0.62), 0.18, 0.0, Color(0.86, 0.95, 1.0), 3.4)
	var neon := LostSignalVisualFactory.material(Color(0.5, 0.7, 0.73), 0.35, 0.0, Color(0.74, 0.94, 1.0), 5.0)
	LostSignalVisualFactory.box(_diner_proxy, "Building", Vector3(19, 5.2, 7.5), Vector3(0, 2.5, 0), wall)
	for window_index in 5:
		LostSignalVisualFactory.box(_diner_proxy, "Window%02d" % window_index, Vector3(2.5, 2.3, 0.08), Vector3(-6.0 + window_index * 3.0, 2.5, -3.8), glass, Vector3.ZERO, false)
	LostSignalVisualFactory.box(_diner_proxy, "RoofNeon", Vector3(19.4, 0.12, 0.12), Vector3(0, 5.2, -3.84), neon, Vector3.ZERO, false)
	var sign := LostSignalVisualFactory.label_3d(_diner_proxy, "DinerSign", "TÚN  •  24 САҒАТ", Vector3(0, 6.4, -3.9), 96, Color(0.78, 0.95, 1.0))
	sign.outline_modulate = Color(0.02, 0.05, 0.07)
	var light := OmniLight3D.new()
	light.name = "DinerWhiteGlow"
	light.position = Vector3(0, 4.5, -4.2)
	light.light_color = Color(0.7, 0.9, 1.0)
	light.light_energy = 6.0
	light.omni_range = 35.0
	light.shadow_enabled = false
	_diner_proxy.add_child(light)


func _unhandled_input(event: InputEvent) -> void:
	if LostSignalInputLock.is_locked():
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_yaw_target = clampf(_yaw_target - motion.relative.x * 0.0018, deg_to_rad(-52), deg_to_rad(52))
		_pitch_target = clampf(_pitch_target - motion.relative.y * 0.0018, deg_to_rad(-18), deg_to_rad(25))


func _process(delta: float) -> void:
	if vehicle == null or road == null:
		return
	vehicle.update_headlight_motion(road.total_distance)
	if not _dashcam.focused:
		var weight := 1.0 - exp(-11.0 * delta)
		vehicle.yaw_pivot.rotation.y = lerp_angle(vehicle.yaw_pivot.rotation.y, _yaw_target, weight)
		vehicle.pitch_pivot.rotation.x = lerp_angle(vehicle.pitch_pivot.rotation.x, _pitch_target, weight)
		var phase := road.total_distance * 0.19
		vehicle.camera.position = _base_camera_position + Vector3(sin(phase * 0.73) * camera_vibration_strength * 0.64, sin(phase) * camera_vibration_strength, 0)


func _on_distance_advanced(distance: float) -> void:
	if _diner_proxy:
		_diner_proxy.position.z = -_diner_start_distance() + distance
	if distance > _arrival_distance() and not _arrival_started:
		_arrival_started = true
		LostSignalFlow.set_state(LostSignalFlow.FlowState.DINER_ARRIVAL)
		hud.set_objective("Впереди придорожная закусочная")
		hud.set_status("Скорость снижается   •   Поворот через 300 м")
		road.set_speed(8.5, 1.15)
		var engine := get_node_or_null("EngineLoop") as AudioStreamPlayer
		if engine:
			create_tween().tween_property(engine, "pitch_scale", 0.72, 4.0)
	if distance > _end_distance() and not LostSignalFlow.transition_in_progress:
		hud.set_objective("")
		hud.set_status("Парковка   •   Двигатель: холостой ход")
		road.set_speed(0.0, 4.0)
		LostSignalFlow.transition_to(LostSignalFlow.DINER_SCENE, LostSignalFlow.FlowState.DINER_ENTERING)


func _route_extension() -> float:
	return BASE_END_DISTANCE * (route_length_multiplier - 1.0)


func _arrival_distance() -> float:
	return BASE_ARRIVAL_DISTANCE + _route_extension()


func _end_distance() -> float:
	return BASE_END_DISTANCE * route_length_multiplier


func _diner_start_distance() -> float:
	return BASE_DINER_DISTANCE + _route_extension()


func _exit_tree() -> void:
	_stop_generated_audio()


func _stop_generated_audio() -> void:
	for node in find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		player.stop()
		player.stream = null


func _run_qa_dashcam_check() -> void:
	await get_tree().create_timer(0.8).timeout
	_dashcam.enter_focus()
	await get_tree().create_timer(0.65).timeout
	_dashcam.set_mode(LostSignalDashcamSystem.FeedMode.REAR)
	await get_tree().create_timer(0.28).timeout
	_dashcam.set_mode(LostSignalDashcamSystem.FeedMode.SPLIT)
	await get_tree().create_timer(0.28).timeout
	_dashcam.exit_focus()
