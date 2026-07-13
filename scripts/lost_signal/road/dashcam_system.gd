class_name LostSignalDashcamSystem
extends Node

signal focus_changed(focused: bool)

enum FeedMode { FRONT, REAR, SPLIT }

const LOCK_OWNER: StringName = &"lost_signal_dashcam"

var view_camera: Camera3D
var focus_anchor: Marker3D
var front_anchor: Marker3D
var rear_anchor: Marker3D
var focused := false
var _busy := false
var _mode := FeedMode.FRONT
var _return_transform := Transform3D.IDENTITY
var _return_fov := 72.0
var _front_viewport: SubViewport
var _rear_viewport: SubViewport
var _front_camera: Camera3D
var _rear_camera: Camera3D
var _screen: PanelContainer
var _front_rect: TextureRect
var _rear_rect: TextureRect
var _mode_label: Label
var _timestamp: Label
var _physical_screen: MeshInstance3D
var _physical_material: StandardMaterial3D


func setup(camera: Camera3D, focus: Marker3D, front: Marker3D, rear: Marker3D, physical_screen: MeshInstance3D = null) -> void:
	view_camera = camera
	focus_anchor = focus
	front_anchor = front
	rear_anchor = rear
	_physical_screen = physical_screen
	_build_viewports()
	_build_screen()
	_build_physical_screen_feed()
	_set_viewports_active(false, false)


func _process(_delta: float) -> void:
	if front_anchor and _front_camera:
		_front_camera.global_transform = front_anchor.global_transform
	if rear_anchor and _rear_camera:
		_rear_camera.global_transform = rear_anchor.global_transform
	if focused and _timestamp:
		var total := int(LostSignalFlow.elapsed_seconds())
		_timestamp.text = "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("interact"):
		if focused:
			exit_focus()
		else:
			enter_focus()
		get_viewport().set_input_as_handled()
		return
	if not focused:
		return
	if event.is_action_pressed("menu_option_1"):
		set_mode(FeedMode.FRONT)
	elif event.is_action_pressed("menu_option_2"):
		set_mode(FeedMode.REAR)
	elif event.is_action_pressed("menu_option_3"):
		set_mode(FeedMode.SPLIT)
	elif event.is_action_pressed("cancel"):
		exit_focus()
	else:
		return
	get_viewport().set_input_as_handled()


func enter_focus() -> void:
	if focused or _busy or view_camera == null or focus_anchor == null:
		return
	_busy = true
	focused = true
	_return_transform = view_camera.global_transform
	_return_fov = view_camera.fov
	LostSignalInputLock.acquire(LOCK_OWNER)
	_screen.visible = true
	_screen.modulate.a = 0.0
	set_mode(FeedMode.FRONT)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(view_camera, "global_transform", focus_anchor.global_transform, 0.42)
	tween.tween_property(view_camera, "fov", 51.0, 0.42)
	tween.tween_property(_screen, "modulate:a", 1.0, 0.32).set_delay(0.16)
	await tween.finished
	_busy = false
	LostSignalFlow.dashcam_viewed = true
	focus_changed.emit(true)


func exit_focus() -> void:
	if not focused or _busy or view_camera == null:
		return
	_busy = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(view_camera, "global_transform", _return_transform, 0.42)
	tween.tween_property(view_camera, "fov", _return_fov, 0.42)
	tween.tween_property(_screen, "modulate:a", 0.0, 0.24)
	await tween.finished
	_set_viewports_active(false, false)
	_screen.visible = false
	focused = false
	_busy = false
	LostSignalInputLock.release_all(LOCK_OWNER)
	focus_changed.emit(false)


func set_mode(mode: FeedMode) -> void:
	_mode = mode
	var front_active := mode == FeedMode.FRONT or mode == FeedMode.SPLIT
	var rear_active := mode == FeedMode.REAR or mode == FeedMode.SPLIT
	_set_viewports_active(front_active, rear_active)
	_front_rect.visible = front_active
	_rear_rect.visible = rear_active
	if mode == FeedMode.SPLIT:
		_front_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_front_rect.anchor_bottom = 0.5
		_front_rect.offset_bottom = -2.0
		_rear_rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_rear_rect.anchor_top = 0.5
		_rear_rect.offset_top = 2.0
	else:
		_front_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rear_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_label.text = ["CAM F / FRONT", "CAM R / REAR", "SPLIT / DUAL"][_mode]
	if _physical_material:
		var physical_texture: Texture2D = _rear_viewport.get_texture() if mode == FeedMode.REAR else _front_viewport.get_texture()
		_physical_material.albedo_texture = physical_texture
		_physical_material.emission_texture = physical_texture


func _build_viewports() -> void:
	_front_viewport = SubViewport.new()
	_front_viewport.name = "FrontViewport640x360"
	_front_viewport.size = Vector2i(640, 360)
	_front_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_front_viewport.transparent_bg = false
	add_child(_front_viewport)
	_front_viewport.world_3d = get_viewport().world_3d
	_front_camera = Camera3D.new()
	_front_camera.name = "FrontDashcamCamera"
	_front_camera.fov = 72.0
	_front_camera.far = 220.0
	_front_camera.set_cull_mask_value(4, false)
	_front_viewport.add_child(_front_camera)
	_front_camera.current = true

	_rear_viewport = SubViewport.new()
	_rear_viewport.name = "RearViewport640x360"
	_rear_viewport.size = Vector2i(640, 360)
	_rear_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rear_viewport.transparent_bg = false
	add_child(_rear_viewport)
	_rear_viewport.world_3d = get_viewport().world_3d
	_rear_camera = Camera3D.new()
	_rear_camera.name = "RearDashcamCamera"
	_rear_camera.fov = 76.0
	_rear_camera.far = 180.0
	_rear_camera.set_cull_mask_value(4, false)
	_rear_viewport.add_child(_rear_camera)
	_rear_camera.current = true


func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DashcamUILayer"
	layer.layer = 132
	add_child(layer)
	_screen = PanelContainer.new()
	_screen.name = "DashcamFocusScreen"
	_screen.set_anchors_preset(Control.PRESET_CENTER)
	_screen.position = Vector2(-480, -292)
	_screen.size = Vector2(960, 540)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.006, 0.009, 0.012, 0.98)
	frame_style.border_color = Color(0.12, 0.15, 0.16)
	frame_style.set_border_width_all(18)
	frame_style.set_corner_radius_all(22)
	frame_style.shadow_color = Color(0, 0, 0, 0.8)
	frame_style.shadow_size = 28
	_screen.add_theme_stylebox_override("panel", frame_style)
	_screen.visible = false
	layer.add_child(_screen)
	var viewport_frame := Control.new()
	viewport_frame.clip_contents = true
	_screen.add_child(viewport_frame)
	_front_rect = _make_feed_rect(_front_viewport.get_texture())
	viewport_frame.add_child(_front_rect)
	_rear_rect = _make_feed_rect(_rear_viewport.get_texture())
	viewport_frame.add_child(_rear_rect)
	var rec := Label.new()
	rec.position = Vector2(26, 20)
	rec.text = "● REC"
	rec.add_theme_font_size_override("font_size", 22)
	rec.add_theme_color_override("font_color", Color(1.0, 0.18, 0.12))
	viewport_frame.add_child(rec)
	_mode_label = Label.new()
	_mode_label.position = Vector2(26, 60)
	_mode_label.add_theme_font_size_override("font_size", 18)
	_mode_label.add_theme_color_override("font_color", Color(0.78, 0.91, 0.94))
	viewport_frame.add_child(_mode_label)
	_timestamp = Label.new()
	_timestamp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timestamp.position = Vector2(-190, 22)
	_timestamp.size = Vector2(160, 32)
	_timestamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timestamp.add_theme_font_size_override("font_size", 20)
	_timestamp.add_theme_color_override("font_color", Color(0.8, 0.9, 0.92))
	viewport_frame.add_child(_timestamp)
	var controls := Label.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 20.0
	controls.offset_top = -44.0
	controls.offset_right = -20.0
	controls.offset_bottom = -16.0
	controls.text = "1 FRONT    2 REAR    3 SPLIT                         E / ESC НАЗАД"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color(0.64, 0.74, 0.76))
	viewport_frame.add_child(controls)


func _make_feed_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := load("res://shaders/lost_signal/dashcam_screen.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat
	return rect


func _build_physical_screen_feed() -> void:
	if _physical_screen == null:
		return
	_physical_material = StandardMaterial3D.new()
	_physical_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_physical_material.albedo_texture = _front_viewport.get_texture()
	_physical_material.albedo_color = Color(0.66, 0.82, 0.88)
	_physical_material.emission_enabled = true
	_physical_material.emission_texture = _front_viewport.get_texture()
	_physical_material.emission = Color(0.65, 0.82, 0.9)
	_physical_material.emission_energy_multiplier = 0.72
	_physical_screen.set_surface_override_material(0, _physical_material)


func _set_viewports_active(front: bool, rear: bool) -> void:
	if _front_viewport:
		_front_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if front else SubViewport.UPDATE_DISABLED
	if _rear_viewport:
		_rear_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if rear else SubViewport.UPDATE_DISABLED


func _exit_tree() -> void:
	_set_viewports_active(false, false)
	LostSignalInputLock.release_all(LOCK_OWNER)
