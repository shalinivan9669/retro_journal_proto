extends Node3D

@onready var vehicle: LostSignalVehicleInterior = $VehicleInterior
@onready var road: LostSignalLoopingRoad = $LoopingRoad
@onready var hud: LostSignalHUD = $LostSignalHUD

var _dashcam: LostSignalDashcamSystem
var _rabbit_path: Path3D
var _rabbit_follow: PathFollow3D
var _rabbit: Node3D
var _rabbit_animation: AnimationPlayer
var _rustle_grass: Array[Node3D] = []
var _event_started := false
var _event_finished := false
var _yaw_target := 0.0
var _pitch_target := 0.0
var _base_camera_position := Vector3.ZERO
var _demo_panel: PanelContainer
var _returning_to_main := false


func _ready() -> void:
	LostSignalFlow.set_state(LostSignalFlow.FlowState.FOREST_DRIVE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	LostSignalProceduralAmbience.add_player(self, "ForestNightAmbience", LostSignalProceduralAmbience.Kind.FOREST, &"Ambience", -15.5)
	LostSignalProceduralAmbience.add_player(self, "ForestEngineLoop", LostSignalProceduralAmbience.Kind.ENGINE, &"Vehicle", -17.0)
	_build_rabbit_event()
	_dashcam = LostSignalDashcamSystem.new()
	_dashcam.name = "ReusedDashcamSystem"
	add_child(_dashcam)
	_dashcam.setup(vehicle.camera, vehicle.dashcam_focus_anchor, vehicle.front_feed_anchor, vehicle.rear_feed_anchor, vehicle.dashcam_screen_mesh)
	_base_camera_position = vehicle.camera.position
	road.distance_advanced.connect(_on_distance_advanced)
	hud.show_chapter("LOST SIGNAL / 04", "Лесная дорога", 3.0)
	hud.set_objective("Дорога уходит глубже в лес")
	hud.set_status("Скорость 74 км/ч   •   Фары: ближний свет   •   02:51")
	_build_demo_complete_ui()


func _process(delta: float) -> void:
	if vehicle and not _dashcam.focused:
		var weight := 1.0 - exp(-10.0 * delta)
		vehicle.yaw_pivot.rotation.y = lerp_angle(vehicle.yaw_pivot.rotation.y, _yaw_target, weight)
		vehicle.pitch_pivot.rotation.x = lerp_angle(vehicle.pitch_pivot.rotation.x, _pitch_target, weight)
		var phase := road.total_distance * 0.21
		vehicle.camera.position = _base_camera_position + Vector3(sin(phase * 0.61) * 0.0018, sin(phase) * 0.0028, 0)
	if _event_started and not _event_finished and _rabbit_follow:
		var path_speed := 9.2
		_rabbit_follow.progress += path_speed * delta
		var ratio := _rabbit_follow.progress_ratio
		_rabbit.position.y = 0.60 + abs(sin(ratio * PI * 5.0)) * 0.055
		if ratio >= 0.999:
			_finish_rabbit_event()


func _unhandled_input(event: InputEvent) -> void:
	if _event_finished:
		if event.is_action_pressed("interact"):
			_return_to_main()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			LostSignalFlow.start_new_run()
			LostSignalFlow.transition_to(LostSignalFlow.NIGHT_DRIVE_SCENE, LostSignalFlow.FlowState.NIGHT_DRIVE)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("cancel"):
			LostSignalInputLock.clear()
			get_tree().change_scene_to_file("res://scenes/Main.tscn")
			get_viewport().set_input_as_handled()
			return
	if LostSignalInputLock.is_locked():
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_yaw_target = clampf(_yaw_target - motion.relative.x * 0.0018, deg_to_rad(-48), deg_to_rad(48))
		_pitch_target = clampf(_pitch_target - motion.relative.y * 0.0018, deg_to_rad(-17), deg_to_rad(23))


func _build_environment() -> void:
	add_child(LostSignalVisualFactory.make_night_environment(0.015, 0.22))
	LostSignalVisualFactory.make_star_field(self, 210, 175.0, 4409)
	var moon := DirectionalLight3D.new()
	moon.name = "ObscuredMoonFill"
	moon.rotation_degrees = Vector3(-52, 24, 0)
	moon.light_color = Color(0.24, 0.34, 0.5)
	moon.light_energy = 0.15
	moon.shadow_enabled = false
	add_child(moon)
	var horizon_mat := LostSignalVisualFactory.material(Color(0.004, 0.011, 0.008), 1.0)
	for index in 18:
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := side * (22.0 + (index % 5) * 8.0)
		var height := 14.0 + (index % 4) * 5.0
		LostSignalVisualFactory.cylinder(self, "FarForestSilhouette%02d" % index, 4.0, height, Vector3(x, height * 0.5, -75.0 - index * 3.0), horizon_mat, Vector3.ZERO, 7)


func _build_rabbit_event() -> void:
	_rabbit_path = Path3D.new()
	_rabbit_path.name = "RabbitCrossingPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.06
	curve.add_point(Vector3(-8.5, 0.25, -20.0), Vector3.ZERO, Vector3(2.5, 0, -0.2))
	curve.add_point(Vector3(-3.7, 0.20, -20.4), Vector3(-2.1, 0, 0), Vector3(2.2, 0, 0))
	curve.add_point(Vector3(0.0, 0.18, -20.1), Vector3(-2.0, 0, 0.2), Vector3(2.0, 0, -0.2))
	curve.add_point(Vector3(3.7, 0.22, -20.3), Vector3(-2.2, 0, 0), Vector3(2.1, 0, 0))
	curve.add_point(Vector3(8.5, 0.28, -20.0), Vector3(-2.5, 0, 0.2), Vector3.ZERO)
	_rabbit_path.curve = curve
	add_child(_rabbit_path)
	_rabbit_follow = PathFollow3D.new()
	_rabbit_follow.name = "RabbitPathFollow"
	_rabbit_follow.loop = false
	_rabbit_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	_rabbit_path.add_child(_rabbit_follow)
	var packed := load("res://assets/lost_signal/rabbit/cdmir_rabbit/rabbit.fbx") as PackedScene
	if packed:
		_rabbit = packed.instantiate() as Node3D
	if _rabbit == null:
		_rabbit = _build_fallback_rabbit()
	else:
		_rabbit.name = "CDmirAnimatedRabbit_CC0"
		_rabbit.scale = Vector3.ONE * 4.0
		_rabbit.rotation_degrees.y = -90.0
		var players := _rabbit.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_rabbit_animation = players[0] as AnimationPlayer
	_rabbit.visible = false
	_rabbit_follow.add_child(_rabbit)
	_build_rustle_grass(Vector3(-7.7, 0, -20.0), "LeftStartGrass")
	_build_rustle_grass(Vector3(7.7, 0, -20.0), "RightExitGrass")


func _build_fallback_rabbit() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackRabbit"
	var fur := LostSignalVisualFactory.material(Color(0.27, 0.24, 0.21), 0.93)
	LostSignalVisualFactory.sphere(root, "Body", 0.30, Vector3(0, 0.28, 0), fur, Vector3(1.25, 0.82, 0.75))
	LostSignalVisualFactory.sphere(root, "Head", 0.20, Vector3(0.32, 0.46, 0), fur, Vector3(0.9, 1.0, 0.85))
	for z in [-0.09, 0.09]:
		var ear := LostSignalVisualFactory.sphere(root, "Ear", 0.10, Vector3(0.30, 0.72, z), fur, Vector3(0.42, 1.7, 0.45))
		ear.rotation_degrees.z = -12.0
	LostSignalVisualFactory.sphere(root, "Tail", 0.12, Vector3(-0.38, 0.35, 0), LostSignalVisualFactory.material(Color(0.55, 0.52, 0.47), 0.95))
	return root


func _build_rustle_grass(position: Vector3, grass_name: String) -> void:
	var packed := load("res://assets/lost_signal/forest/kenney_nature/grass_large.glb") as PackedScene
	var root := Node3D.new()
	root.name = grass_name
	root.position = position
	add_child(root)
	for index in 7:
		var instance: Node3D
		if packed:
			instance = packed.instantiate() as Node3D
		else:
			instance = Node3D.new()
			LostSignalVisualFactory.box(instance, "Blade", Vector3(0.08, 0.55, 0.05), Vector3.ZERO, LostSignalVisualFactory.material(Color(0.06, 0.09, 0.045), 0.95))
		instance.position = Vector3((index % 3) * 0.26 - 0.25, 0, (index / 3) * 0.23 - 0.2)
		instance.scale = Vector3.ONE * (1.2 + index * 0.08)
		root.add_child(instance)
	_rustle_grass.append(root)


func _on_distance_advanced(distance: float) -> void:
	if distance >= 245.0 and not _event_started and not LostSignalFlow.rabbit_event_seen:
		_start_rabbit_event()


func _start_rabbit_event() -> void:
	if _event_started or LostSignalFlow.rabbit_event_seen:
		return
	_event_started = true
	LostSignalFlow.set_state(LostSignalFlow.FlowState.RABBIT_EVENT)
	hud.set_objective("В траве слева что-то шевельнулось")
	road.set_speed(17.8, 6.0)
	var grass := _rustle_grass[0]
	var rustle := create_tween()
	russtle_grass(grass, rustle)
	LostSignalProceduralAmbience.play_one_shot(
		self,
		"res://assets/lost_signal/audio/generated/lost_signal_rustle_oneshot.wav",
		&"SFX", -7.0
	)
	await get_tree().create_timer(0.48).timeout
	_rabbit_follow.progress_ratio = 0.0
	_rabbit.visible = true
	if _rabbit_animation and _rabbit_animation.has_animation(&"Armature|Running"):
		_rabbit_animation.speed_scale = 1.22
		_rabbit_animation.play(&"Armature|Running")
	hud.set_objective("")


func russtle_grass(grass: Node3D, tween: Tween) -> void:
	tween.set_loops(3)
	tween.tween_property(grass, "rotation:z", deg_to_rad(8.0), 0.08)
	tween.tween_property(grass, "rotation:z", deg_to_rad(-7.0), 0.08)
	tween.tween_property(grass, "rotation:z", 0.0, 0.08)


func _finish_rabbit_event() -> void:
	if _event_finished:
		return
	_event_finished = true
	LostSignalFlow.rabbit_event_seen = true
	if _rabbit_animation:
		_rabbit_animation.stop()
	road.set_speed(21.0, 1.8)
	await get_tree().create_timer(1.05).timeout
	_rabbit.visible = false
	LostSignalFlow.set_state(LostSignalFlow.FlowState.DEMO_COMPLETE)
	_dashcam.set_process_unhandled_input(false)
	hud.hide_prompt()
	hud.set_objective("")
	hud.set_status("Сигнал потерян   •   Событие записано")
	_show_demo_complete()
	if LostSignalFlow.qa_enabled:
		# This second call must be rejected by the one-shot guard.
		_start_rabbit_event()
		await get_tree().create_timer(0.35).timeout
		print(
			"LOST_SIGNAL_QA_COMPLETE run=", LostSignalFlow.qa_run,
			" order=", LostSignalFlow.selected_order,
			" meal=", LostSignalFlow.meal_finished,
			" restroom=", LostSignalFlow.restroom_visited,
			" washed=", LostSignalFlow.washed_face,
			" dashcam=", LostSignalFlow.dashcam_viewed,
			" rabbit=", LostSignalFlow.rabbit_event_seen
		)
		get_tree().quit()
	else:
		get_tree().create_timer(6.0).timeout.connect(_return_to_main)


func _build_demo_complete_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DemoCompleteLayer"
	layer.layer = 155
	add_child(layer)
	_demo_panel = PanelContainer.new()
	_demo_panel.set_anchors_preset(Control.PRESET_CENTER)
	_demo_panel.position = Vector2(-380, -180)
	_demo_panel.size = Vector2(760, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.005, 0.009, 0.013, 0.94)
	style.border_color = Color(0.20, 0.35, 0.39, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 42
	style.content_margin_bottom = 42
	_demo_panel.add_theme_stylebox_override("panel", style)
	_demo_panel.visible = false
	layer.add_child(_demo_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	_demo_panel.add_child(layout)
	var title := Label.new()
	title.text = "LOST SIGNAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.72, 0.88, 0.91))
	layout.add_child(title)
	var line := Label.new()
	line.text = "КОНЕЦ VERTICAL SLICE\n\nЗаказ: %s\nТуалет: %s   •   Умывание: %s\nВидеорегистратор: %s   •   Заяц: записан" % [
		LostSignalFlow.order_display_name(),
		"посещён" if LostSignalFlow.restroom_visited else "пропущен",
		"да" if LostSignalFlow.washed_face else "нет",
		"просмотрен" if LostSignalFlow.dashcam_viewed else "не открыт",
	]
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 19)
	line.add_theme_color_override("font_color", Color(0.72, 0.76, 0.74))
	layout.add_child(line)
	var hint := Label.new()
	hint.text = "E — продолжить в основную игру     R — новое прохождение     ESC — назад"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.46, 0.62, 0.65))
	layout.add_child(hint)


func _show_demo_complete() -> void:
	_demo_panel.visible = true
	_demo_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_property(_demo_panel, "modulate:a", 1.0, 0.8)


func _return_to_main() -> void:
	if _returning_to_main or LostSignalSceneLoader.is_loading():
		return
	_returning_to_main = true
	LostSignalSceneLoader.transition_to("res://scenes/Main.tscn")


func _exit_tree() -> void:
	for node in find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		player.stop()
		player.stream = null
