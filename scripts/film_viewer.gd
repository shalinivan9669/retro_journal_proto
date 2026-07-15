extends Node3D

@export var reveal_speed := 3.4
@export var full_reveal_hold_seconds := 1.2
@export var display_position := Vector3(0.16, -0.04, -0.55)

@onready var film_pivot: Node3D = $FilmPivot
@onready var film_mesh: MeshInstance3D = $FilmPivot/FilmMesh

var _film_material: ShaderMaterial
var _reveal_amount := 0.0
var _full_reveal_time := 0.0
var _base_position := Vector3.ZERO
var _fully_revealed_hint_shown := false
var _hint_layer: CanvasLayer
var _hint_label: Label
var _visibility_tween: Tween
var _animation_serial := 0


func _ready() -> void:
	add_to_group("film_viewer")
	_base_position = display_position
	position = display_position
	visible = false
	if film_mesh.material_override is ShaderMaterial:
		_film_material = (film_mesh.material_override as ShaderMaterial).duplicate(true) as ShaderMaterial
		film_mesh.material_override = _film_material
		_film_material.set_shader_parameter("reveal_amount", 0.0)


func handle_key(keycode: Key) -> bool:
	if keycode == KEY_F and GameState.film_01_collected:
		toggle_film()
		return true
	if keycode == KEY_ESCAPE and visible:
		hide_film()
		return true
	return false


func toggle_film() -> void:
	if visible:
		hide_film()
	else:
		show_film()


func show_film() -> bool:
	if not GameState.film_01_collected:
		return false

	var reveal_controller := get_tree().get_first_node_in_group("film_reveal_controller")
	if reveal_controller != null and reveal_controller.has_method("request_stow"):
		var stow_result: Variant = reveal_controller.call("request_stow", true)
		if stow_result is bool and not bool(stow_result):
			return false

	_animation_serial += 1
	_kill_visibility_tween()
	GameState.film_01_viewed = true
	visible = true
	position = _base_position + Vector3(0.0, -0.08, 0.04)
	scale = Vector3.ONE * 0.82
	_visibility_tween = create_tween().set_parallel(true)
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visibility_tween.tween_property(self, "position", _base_position, 0.28)
	_visibility_tween.tween_property(self, "scale", Vector3.ONE, 0.28)
	return true


func hide_film(immediate: bool = false) -> void:
	_animation_serial += 1
	var hide_serial := _animation_serial
	_kill_visibility_tween()

	if immediate:
		_finish_hidden_state()
		return
	if not visible:
		return
	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_visibility_tween.tween_property(self, "scale", Vector3.ONE * 0.84, 0.18)
	await _visibility_tween.finished
	if hide_serial != _animation_serial:
		return
	_visibility_tween = null
	_finish_hidden_state()


func _kill_visibility_tween() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null


func _finish_hidden_state() -> void:
	visible = false
	position = _base_position
	scale = Vector3.ONE
	film_pivot.rotation.z = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	var camera := get_parent() as Camera3D
	if camera == null:
		return

	var forward := -camera.global_transform.basis.z.normalized()
	var upward_factor := smoothstep(0.05, 0.75, forward.dot(Vector3.UP))
	var sky_visibility := _get_sky_visibility(camera, forward)
	var sun_alignment := _get_sun_alignment(forward)
	var target_reveal := upward_factor * sky_visibility * lerpf(0.65, 1.0, sun_alignment)
	var weight := 1.0 - exp(-reveal_speed * delta)
	_reveal_amount = lerpf(_reveal_amount, target_reveal, weight)
	if _film_material != null:
		_film_material.set_shader_parameter("reveal_amount", _reveal_amount)
		_film_material.set_shader_parameter("overexposure", smoothstep(0.82, 1.0, target_reveal) * sun_alignment)

	var bob := Vector3(sin(Time.get_ticks_msec() * 0.002) * 0.004, cos(Time.get_ticks_msec() * 0.0017) * 0.003, 0.0)
	position = position.lerp(_base_position + bob, minf(delta * 7.0, 1.0))
	film_pivot.rotation.z = sin(Time.get_ticks_msec() * 0.0013) * 0.012

	if _reveal_amount >= 0.85:
		_full_reveal_time += delta
		if _full_reveal_time >= full_reveal_hold_seconds:
			GameState.film_01_fully_revealed = true
			if not _fully_revealed_hint_shown:
				_fully_revealed_hint_shown = true
				show_hint("На плёнке что-то есть.")
	else:
		_full_reveal_time = 0.0


func show_hint(text: String) -> void:
	if _hint_layer == null:
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 90
		_hint_label = Label.new()
		_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_hint_label.position = Vector2(-230.0, -150.0)
		_hint_label.size = Vector2(460.0, 42.0)
		_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_label.add_theme_font_size_override("font_size", 24)
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68, 1.0))
		_hint_layer.add_child(_hint_label)
		get_tree().current_scene.add_child(_hint_layer)
	_hint_label.text = text
	_hint_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_hint_label, "modulate:a", 0.0, 0.35)


func _get_sky_visibility(camera: Camera3D, forward: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return 1.0
	var exclude: Array[RID] = []
	var player := camera.get_parent().get_parent() as CollisionObject3D
	if player != null:
		exclude.append(player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * 1500.0, 0xffffffff, exclude)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return 1.0 if world.direct_space_state.intersect_ray(query).is_empty() else 0.0


func _get_sun_alignment(forward: Vector3) -> float:
	var scene := get_tree().current_scene
	if scene == null:
		return 0.0
	var lights := scene.find_children("*", "DirectionalLight3D", true, false)
	if lights.is_empty():
		return 0.0
	var sun := lights[0] as DirectionalLight3D
	if sun == null:
		return 0.0
	# DirectionalLight3D emits along local -Z; the apparent sun lies toward +Z.
	var direction_to_sun := sun.global_transform.basis.z.normalized()
	return smoothstep(0.38, 0.96, forward.dot(direction_to_sun))
