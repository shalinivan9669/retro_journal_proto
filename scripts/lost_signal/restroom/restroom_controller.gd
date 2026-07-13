extends Node3D

@onready var hud: LostSignalHUD = $LostSignalHUD
@onready var blink: LostSignalBlinkOverlay = $BlinkOverlay

const LOCK_OWNER: StringName = &"lost_signal_sink"
const SINK_POSITION := Vector3(0.75, 1.0, -2.18)

var _player: Node3D
var _yaw: Node3D
var _pitch: Node3D
var _camera: Camera3D
var _yaw_value := 0.0
var _pitch_value := 0.0
var _sink_available := false
var _busy := false
var _water_stream: MeshInstance3D
var _splash: GPUParticles3D
var _water_audio: AudioStreamPlayer3D
var _mirror_viewport: SubViewport
var _mirror_camera: Camera3D
var _mirror_surface: MeshInstance3D


func _ready() -> void:
	LostSignalFlow.set_state(LostSignalFlow.FlowState.RESTROOM_INSIDE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_room()
	_build_player()
	_build_sink_effects()
	_build_mirror()
	hud.show_chapter("LOST SIGNAL / 03", "Туалет закусочной", 2.8)
	hud.set_objective("Подойдите к раковине или нажмите F, чтобы вернуться")
	hud.set_status("Холодный свет   •   Вентиляция работает")
	if LostSignalFlow.qa_enabled:
		_run_qa_restroom()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if not _busy and not LostSignalInputLock.is_locked():
		var input := Vector2.ZERO
		if Input.is_key_pressed(KEY_A): input.x -= 1.0
		if Input.is_key_pressed(KEY_D): input.x += 1.0
		if Input.is_key_pressed(KEY_W): input.y -= 1.0
		if Input.is_key_pressed(KEY_S): input.y += 1.0
		input = input.normalized()
		var local_direction := Vector3(input.x, 0, input.y)
		var direction := _player.basis * local_direction
		_player.position += Vector3(direction.x, 0, direction.z) * 2.15 * delta
		_player.position.x = clampf(_player.position.x, -3.25, 3.25)
		_player.position.z = clampf(_player.position.z, -1.75, 2.35)
	_update_interaction_prompt()
	_update_mirror()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or LostSignalInputLock.is_locked():
		return
	if event.is_action_pressed("interact") and _sink_available and not LostSignalFlow.washed_face:
		_wash_face()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restroom"):
		_return_to_diner()
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_yaw_value = wrapf(_yaw_value - motion.relative.x * 0.0021, -PI, PI)
		_pitch_value = clampf(_pitch_value - motion.relative.y * 0.0021, deg_to_rad(-65), deg_to_rad(65))
		_yaw.rotation.y = _yaw_value
		_pitch.rotation.x = _pitch_value


func _build_room() -> void:
	var tile_material := load("res://assets/lost_signal/materials/tiles032/Tiles032_2K-JPG.tres") as StandardMaterial3D
	if tile_material:
		tile_material = tile_material.duplicate() as StandardMaterial3D
		tile_material.uv1_scale = Vector3(2.6, 2.6, 2.6)
		tile_material.heightmap_enabled = false
	else:
		tile_material = LostSignalVisualFactory.material(Color(0.10, 0.18, 0.15), 0.34)
	var floor_mat := LostSignalVisualFactory.material(Color(0.14, 0.16, 0.145), 0.24, 0.05)
	var ceiling_mat := LostSignalVisualFactory.material(Color(0.32, 0.34, 0.32), 0.88)
	var stall_mat := LostSignalVisualFactory.material(Color(0.085, 0.12, 0.115), 0.62, 0.18)
	var metal := LostSignalVisualFactory.material(Color(0.32, 0.36, 0.36), 0.22, 0.72)
	var plastic := LostSignalVisualFactory.material(Color(0.48, 0.5, 0.46), 0.54)
	var warning := LostSignalVisualFactory.material(Color(0.88, 0.58, 0.04), 0.62)
	var wet := LostSignalVisualFactory.material(Color(0.06, 0.11, 0.10, 0.38), 0.05)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	LostSignalVisualFactory.box(self, "WetTileFloor", Vector3(8.0, 0.14, 6.0), Vector3(0, -0.08, 0), floor_mat)
	LostSignalVisualFactory.box(self, "BackTileWall", Vector3(8.0, 3.4, 0.18), Vector3(0, 1.7, -3.0), tile_material)
	LostSignalVisualFactory.box(self, "FrontTileWall", Vector3(8.0, 3.4, 0.18), Vector3(0, 1.7, 3.0), tile_material)
	LostSignalVisualFactory.box(self, "LeftTileWall", Vector3(0.18, 3.4, 6.0), Vector3(-4.0, 1.7, 0), tile_material)
	LostSignalVisualFactory.box(self, "RightTileWall", Vector3(0.18, 3.4, 6.0), Vector3(4.0, 1.7, 0), tile_material)
	LostSignalVisualFactory.box(self, "PanelCeiling", Vector3(8.0, 0.16, 6.0), Vector3(0, 3.38, 0), ceiling_mat)
	_add_box_occluder("RestroomBackOccluder", Vector3(8.0, 3.4, 0.15), Vector3(0, 1.7, -3.0))
	_add_box_occluder("RestroomLeftOccluder", Vector3(0.15, 3.4, 6.0), Vector3(-4.0, 1.7, 0))
	_add_box_occluder("RestroomRightOccluder", Vector3(0.15, 3.4, 6.0), Vector3(4.0, 1.7, 0))
	for x in [-2.5, 0.0, 2.5]:
		LostSignalVisualFactory.box(self, "CeilingLightPanel", Vector3(1.4, 0.04, 0.55), Vector3(x, 3.28, 0), LostSignalVisualFactory.material(Color(0.75, 0.88, 0.9), 0.5, 0, Color(0.78, 0.94, 1), 3.2), Vector3.ZERO, false)
		var light := OmniLight3D.new()
		light.name = "ColdPanelLight"
		light.position = Vector3(x, 2.95, 0)
		light.light_color = Color(0.69, 0.84, 0.9)
		light.light_energy = 1.15
		light.omni_range = 5.0
		light.shadow_enabled = x == 0.0
		add_child(light)

	_build_stalls(stall_mat, metal)
	_build_imported_fixtures(metal, plastic)
	_build_technical_zone(stall_mat, metal, plastic, warning)
	for puddle in [Vector3(-0.9, -0.002, -1.95), Vector3(1.4, -0.001, -1.9), Vector3(2.7, -0.001, 0.8)]:
		var mesh := LostSignalVisualFactory.cylinder(self, "LocalizedWetPatch", 0.55, 0.008, puddle, wet, Vector3.ZERO, 24)
		mesh.scale = Vector3(1.7, 1.0, 0.55)
	LostSignalVisualFactory.cylinder(self, "FloorDrain", 0.16, 0.012, Vector3(0.0, 0.002, 0.35), metal, Vector3.ZERO, 20)


func _build_stalls(stall_mat: Material, metal: Material) -> void:
	for x in [-3.25, -1.25, 0.75]:
		LostSignalVisualFactory.box(self, "StallPartition", Vector3(0.09, 2.25, 2.0), Vector3(x, 1.35, 1.85), stall_mat)
	for x in [-2.25, -0.25]:
		LostSignalVisualFactory.box(self, "StallDoor", Vector3(1.78, 2.02, 0.08), Vector3(x, 1.3, 2.8), stall_mat)
		LostSignalVisualFactory.cylinder(self, "StallHandle", 0.035, 0.16, Vector3(x + 0.65, 1.38, 2.73), metal, Vector3(90, 0, 0), 10)


func _add_box_occluder(occluder_name: String, size: Vector3, position: Vector3) -> void:
	var instance := OccluderInstance3D.new()
	instance.name = occluder_name
	var shape := BoxOccluder3D.new()
	shape.size = size
	instance.occluder = shape
	instance.position = position
	add_child(instance)


func _build_imported_fixtures(metal: Material, plastic: Material) -> void:
	for x in [-1.15, 0.75]:
		var sink := _instantiate_fbx("Bathroom_Sink.fbx", "QuaterniusSink", Vector3(x, 0.18, -2.35), Vector3.ONE * 100.0, Vector3(0, 180, 0))
		if sink == null:
			LostSignalVisualFactory.box(self, "FallbackSink", Vector3(1.25, 0.22, 0.62), Vector3(x, 0.88, -2.45), plastic)
			LostSignalVisualFactory.cylinder(self, "FallbackBasin", 0.32, 0.12, Vector3(x, 0.94, -2.35), plastic, Vector3.ZERO, 24)
	for x in [-2.25, -0.25]:
		var toilet := _instantiate_fbx("Bathroom_Toilet.fbx", "QuaterniusToilet", Vector3(x, 0.18, 1.75), Vector3.ONE * 92.0, Vector3(0, 0, 0))
		if toilet == null:
			LostSignalVisualFactory.cylinder(self, "FallbackToilet", 0.32, 0.42, Vector3(x, 0.36, 1.72), plastic, Vector3.ZERO, 24)
	for x in [2.15, 3.15]:
		LostSignalVisualFactory.cylinder(self, "WallUrinal", 0.31, 0.52, Vector3(x, 0.72, -2.69), plastic, Vector3(90, 0, 0), 20)
		LostSignalVisualFactory.cylinder(self, "FlushPipe", 0.035, 0.62, Vector3(x, 1.24, -2.73), metal, Vector3.ZERO, 10)
	LostSignalVisualFactory.box(self, "SoapDispenser", Vector3(0.24, 0.36, 0.18), Vector3(-0.18, 1.55, -2.82), plastic)
	LostSignalVisualFactory.box(self, "HandDryer", Vector3(0.48, 0.42, 0.24), Vector3(2.75, 1.55, -2.78), metal)
	LostSignalVisualFactory.cylinder(self, "TrashBin", 0.24, 0.62, Vector3(2.95, 0.31, -2.35), metal, Vector3.ZERO, 16)


func _build_technical_zone(stall: Material, metal: Material, plastic: Material, warning: Material) -> void:
	LostSignalVisualFactory.box(self, "TechnicalCabinet", Vector3(1.25, 2.25, 0.5), Vector3(3.25, 1.18, 2.56), stall)
	LostSignalVisualFactory.box(self, "ElectricalPanel", Vector3(0.72, 0.88, 0.18), Vector3(3.58, 1.83, 1.78), metal)
	for pipe_x in [2.25, 2.55, 2.85]:
		LostSignalVisualFactory.cylinder(self, "ExposedPipe", 0.045, 2.5, Vector3(pipe_x, 1.32, 2.72), metal, Vector3.ZERO, 10)
	LostSignalVisualFactory.box(self, "Vent", Vector3(0.75, 0.48, 0.11), Vector3(2.85, 2.75, 2.86), metal)
	for slit in 6:
		LostSignalVisualFactory.box(self, "VentSlit", Vector3(0.58, 0.025, 0.02), Vector3(2.85, 2.57 + slit * 0.065, 2.79), stall, Vector3.ZERO, false)
	LostSignalVisualFactory.cylinder(self, "MopHandle", 0.025, 1.75, Vector3(3.25, 0.95, 1.62), metal, Vector3(0, 0, 11), 8)
	LostSignalVisualFactory.box(self, "MopHead", Vector3(0.48, 0.10, 0.18), Vector3(3.08, 0.09, 1.62), plastic)
	LostSignalVisualFactory.cylinder(self, "BlueBucket", 0.30, 0.38, Vector3(2.45, 0.2, 2.18), LostSignalVisualFactory.material(Color(0.04, 0.17, 0.26), 0.48), Vector3.ZERO, 18)
	for item in 3:
		LostSignalVisualFactory.cylinder(self, "CleanerBottle", 0.09, 0.42, Vector3(2.15 + item * 0.24, 0.25, 2.63), LostSignalVisualFactory.material(Color(0.18 + item * 0.13, 0.34, 0.31), 0.46), Vector3.ZERO, 12)
	var sign_root := Node3D.new()
	sign_root.name = "WetFloorWarningSign"
	sign_root.position = Vector3(1.55, 0, 0.65)
	add_child(sign_root)
	LostSignalVisualFactory.box(sign_root, "SignA", Vector3(0.48, 0.72, 0.06), Vector3(0, 0.38, -0.12), warning, Vector3(-15, 0, 0))
	LostSignalVisualFactory.box(sign_root, "SignB", Vector3(0.48, 0.72, 0.06), Vector3(0, 0.38, 0.12), warning, Vector3(15, 0, 0))
	var label := LostSignalVisualFactory.label_3d(sign_root, "Caution", "!\nМОКРЫЙ ПОЛ", Vector3(0, 0.43, -0.17), 30, Color(0.05, 0.05, 0.03))
	label.outline_size = 0


func _instantiate_fbx(file_name: String, instance_name: String, position: Vector3, scale_value: Vector3, rotation: Vector3) -> Node3D:
	var path := "res://assets/lost_signal/restroom/quaternius_house_interior/%s" % file_name
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.name = instance_name
	node.position = position
	node.scale = scale_value
	node.rotation_degrees = rotation
	add_child(node)
	return node


func _build_player() -> void:
	_player = Node3D.new()
	_player.name = "PlayerLimited"
	_player.position = Vector3(0, 1.62, 2.15)
	add_child(_player)
	_yaw = Node3D.new()
	_yaw.name = "YawPivot"
	_player.add_child(_yaw)
	_pitch = Node3D.new()
	_pitch.name = "PitchPivot"
	_yaw.add_child(_pitch)
	_camera = Camera3D.new()
	_camera.name = "RestroomCamera"
	_camera.current = true
	_camera.fov = 72.0
	_camera.near = 0.05
	_pitch.add_child(_camera)


func _build_sink_effects() -> void:
	var water_shader := load("res://shaders/lost_signal/water_stream.gdshader") as Shader
	var water_mat := ShaderMaterial.new()
	water_mat.shader = water_shader
	_water_stream = LostSignalVisualFactory.cylinder(self, "WaterStream", 0.028, 0.58, Vector3(SINK_POSITION.x, 1.0, -2.13), water_mat, Vector3.ZERO, 12)
	_water_stream.visible = false
	_splash = GPUParticles3D.new()
	_splash.name = "SinkSplashParticles"
	_splash.position = Vector3(SINK_POSITION.x, 0.70, -2.13)
	_splash.amount = 34
	_splash.lifetime = 0.42
	_splash.one_shot = false
	var particle_process := ParticleProcessMaterial.new()
	particle_process.direction = Vector3(0, 1, 0)
	particle_process.spread = 68.0
	particle_process.initial_velocity_min = 0.35
	particle_process.initial_velocity_max = 0.85
	particle_process.gravity = Vector3(0, -3.5, 0)
	particle_process.scale_min = 0.015
	particle_process.scale_max = 0.035
	_splash.process_material = particle_process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.018
	particle_mesh.height = 0.036
	particle_mesh.material = LostSignalVisualFactory.material(Color(0.55, 0.82, 0.95, 0.45), 0.08)
	_splash.draw_pass_1 = particle_mesh
	_splash.emitting = false
	add_child(_splash)
	_water_audio = AudioStreamPlayer3D.new()
	_water_audio.name = "SynthesizedTapWater"
	_water_audio.position = SINK_POSITION
	var imported_water: AudioStreamWAV = null
	if (
		DisplayServer.get_name() != "headless"
		and AudioServer.get_driver_name() != "Dummy"
		and "--write-movie" not in OS.get_cmdline_args()
	):
		imported_water = load("res://assets/lost_signal/audio/generated/lost_signal_water_loop.wav") as AudioStreamWAV
	if imported_water:
		var loop := imported_water.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		_water_audio.stream = loop
	_water_audio.max_distance = 9.0
	add_child(_water_audio)


func _build_mirror() -> void:
	_mirror_viewport = SubViewport.new()
	_mirror_viewport.name = "MirrorViewport512"
	_mirror_viewport.size = Vector2i(512, 512)
	_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_mirror_viewport)
	_mirror_viewport.world_3d = get_viewport().world_3d
	_mirror_camera = Camera3D.new()
	_mirror_camera.name = "MirrorCameraNoPlayerCull"
	_mirror_camera.position = Vector3(-0.2, 1.75, -2.62)
	_mirror_camera.rotation_degrees.y = 180.0
	_mirror_camera.fov = 72.0
	_mirror_camera.cull_mask = 1
	_mirror_viewport.add_child(_mirror_camera)
	_mirror_camera.current = true
	var frame_mat := LostSignalVisualFactory.material(Color(0.18, 0.22, 0.21), 0.22, 0.78)
	LostSignalVisualFactory.box(self, "MirrorMetalFrame", Vector3(3.7, 1.45, 0.10), Vector3(-0.2, 1.82, -2.88), frame_mat)
	var quad := QuadMesh.new()
	quad.size = Vector2(3.48, 1.23)
	var mirror_mat := StandardMaterial3D.new()
	mirror_mat.albedo_texture = _mirror_viewport.get_texture()
	mirror_mat.roughness = 0.18
	mirror_mat.metallic = 0.35
	quad.material = mirror_mat
	_mirror_surface = MeshInstance3D.new()
	_mirror_surface.name = "OptimizedDirtyMirrorSurface"
	_mirror_surface.mesh = quad
	_mirror_surface.position = Vector3(-0.2, 1.82, -2.81)
	_mirror_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mirror_surface)


func _update_interaction_prompt() -> void:
	if _busy:
		return
	var distance := _player.global_position.distance_to(SINK_POSITION)
	_sink_available = distance < 2.15 and not LostSignalFlow.washed_face
	if _sink_available:
		hud.show_prompt("E — умыться          F — вернуться")
	elif LostSignalFlow.washed_face and distance < 2.15:
		hud.show_prompt("Лицо уже умыто          F — вернуться")
	else:
		hud.show_prompt("F — вернуться в зал")


func _update_mirror() -> void:
	if _mirror_viewport == null or _camera == null:
		return
	var to_mirror := (_mirror_surface.global_position - _camera.global_position)
	var forward := -_camera.global_transform.basis.z
	var visible_enough := to_mirror.length() < 5.2 and forward.dot(to_mirror.normalized()) > 0.42
	_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible_enough else SubViewport.UPDATE_DISABLED


func _wash_face() -> void:
	if _busy or not _sink_available or LostSignalFlow.washed_face:
		return
	_busy = true
	LostSignalInputLock.acquire(LOCK_OWNER)
	hud.hide_prompt()
	hud.set_objective("Вода холодная")
	var return_position := _player.position
	var return_yaw := _yaw.rotation
	var return_pitch := _pitch.rotation
	var focus_tween := create_tween().set_parallel(true)
	focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	focus_tween.tween_property(_player, "position", Vector3(SINK_POSITION.x, 1.62, -1.28), 0.48)
	focus_tween.tween_property(_yaw, "rotation", Vector3.ZERO, 0.48)
	focus_tween.tween_property(_pitch, "rotation:x", deg_to_rad(-13.0), 0.48)
	await focus_tween.finished
	_set_water(true)
	await get_tree().create_timer(0.62).timeout
	var mark_washed := func() -> void:
		LostSignalFlow.washed_face = true
	blink.full_dark.connect(mark_washed, CONNECT_ONE_SHOT)
	await blink.blink(0.16)
	_set_water(false)
	var return_tween := create_tween().set_parallel(true)
	return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(_player, "position", return_position, 0.48)
	return_tween.tween_property(_yaw, "rotation", return_yaw, 0.48)
	return_tween.tween_property(_pitch, "rotation", return_pitch, 0.48)
	await return_tween.finished
	_yaw_value = _yaw.rotation.y
	_pitch_value = _pitch.rotation.x
	_busy = false
	LostSignalInputLock.release_all(LOCK_OWNER)
	hud.set_objective("Нажмите F, чтобы вернуться в зал")
	hud.set_status("Лицо умыто   •   Вода перекрыта")


func _set_water(value: bool) -> void:
	if _water_stream: _water_stream.visible = value
	if _splash: _splash.emitting = value
	if _water_audio:
		if value: _water_audio.play()
		else: _water_audio.stop()


func _return_to_diner() -> void:
	if _busy or LostSignalFlow.transition_in_progress:
		return
	_busy = true
	hud.hide_prompt()
	var transition := func() -> void:
		_set_water(false)
		if _mirror_viewport:
			_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		LostSignalFlow.transition_to(LostSignalFlow.DINER_SCENE, LostSignalFlow.FlowState.DINER_AFTER_MEAL)
	blink.full_dark.connect(transition, CONNECT_ONE_SHOT)
	blink.blink(0.22)


func _exit_tree() -> void:
	_set_water(false)
	if _water_audio:
		_water_audio.stream = null
	if _mirror_viewport:
		_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	LostSignalInputLock.release_all(LOCK_OWNER)


func _run_qa_restroom() -> void:
	await get_tree().create_timer(0.5).timeout
	_player.position = Vector3(SINK_POSITION.x, 1.62, -1.2)
	_sink_available = true
	await _wash_face()
	await get_tree().create_timer(0.25).timeout
	_return_to_diner()
