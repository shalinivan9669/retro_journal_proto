extends Node3D

@export var player_path: NodePath = NodePath("Player")
@export var road_mesh_path: NodePath = NodePath("Road/RoadMesh")
@export var far_object_path: NodePath = NodePath("FarObject")
@export var camera_path: NodePath = NodePath("Player/Head/Camera3D")
@export var distortion_overlay_path: NodePath = NodePath("DistortionUI/DistortionOverlay")
@export var vhs_ui_path: NodePath = NodePath("VHSReturnUI")
@export var vhs_static_texture_path: NodePath = NodePath("VHSReturnUI/VHSStaticTexture")
@export var road_scroll_speed: float = 0.9
@export var far_distance: float = 28.0
@export var far_object_height: float = 8.0
@export var idle_time_before_distortion: float = 2.0
@export var distortion_duration_before_vhs: float = 3.0
@export var vhs_duration: float = 4.0
@export var max_position_shake: float = 0.18
@export var max_rotation_shake_degrees: float = 4.0
@export var max_fov_jitter: float = 8.0
@export var return_scene_path: String = "res://scenes/Main.tscn"

@onready var player: Node3D = get_node(player_path)
@onready var road_mesh: MeshInstance3D = get_node(road_mesh_path)
@onready var far_object: Node3D = get_node(far_object_path)
@onready var player_camera: Camera3D = get_node(camera_path)
@onready var distortion_overlay: ColorRect = get_node(distortion_overlay_path)
@onready var vhs_ui: CanvasLayer = get_node(vhs_ui_path)
@onready var vhs_static_texture: TextureRect = get_node(vhs_static_texture_path)

var road_uv_offset := 0.0
var state := "normal"
var idle_timer := 0.0
var distortion_timer := 0.0
var vhs_timer := 0.0
var last_player_position := Vector3.ZERO
var camera_start_position := Vector3.ZERO
var camera_start_rotation := Vector3.ZERO
var camera_start_fov := 75.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	last_player_position = player.global_position
	camera_start_position = player_camera.position
	camera_start_rotation = player_camera.rotation
	camera_start_fov = player_camera.fov
	_set_distortion_alpha(0.0)
	vhs_ui.visible = false
	vhs_static_texture.visible = false
	_update_far_object()
	_apply_road_offset()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().change_scene_to_file(return_scene_path)


func _process(delta: float) -> void:
	var moving: bool = _is_player_moving()
	var forward_input: float = 0.0
	if Input.is_key_pressed(KEY_W):
		forward_input += 1.0
	if Input.is_key_pressed(KEY_S):
		forward_input -= 1.0

	if forward_input != 0.0:
		road_uv_offset += forward_input * road_scroll_speed * delta
		_apply_road_offset()

	_update_far_object()
	_update_idle_return_state(delta, moving)
	last_player_position = player.global_position


func _apply_road_offset() -> void:
	var material: Material = road_mesh.get_active_material(0)
	if material is ShaderMaterial:
		material.set_shader_parameter("uv_offset", Vector2(0.0, road_uv_offset))


func _update_far_object() -> void:
	far_object.global_position = Vector3(player.global_position.x, far_object_height, player.global_position.z - far_distance)


func _update_idle_return_state(delta: float, moving: bool) -> void:
	match state:
		"normal":
			if moving:
				idle_timer = 0.0
			else:
				idle_timer += delta
				if idle_timer >= idle_time_before_distortion:
					state = "distorting"
					distortion_timer = 0.0

		"distorting":
			if moving:
				_reset_distortion()
				return

			distortion_timer += delta
			var progress: float = clamp(distortion_timer / distortion_duration_before_vhs, 0.0, 1.0)
			_apply_distortion(progress)

			if distortion_timer >= distortion_duration_before_vhs:
				_start_vhs_return()

		"vhs_returning":
			vhs_timer += delta
			_update_vhs_static()
			if vhs_timer >= vhs_duration:
				get_tree().change_scene_to_file(return_scene_path)


func _is_player_moving() -> bool:
	var has_move_input: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)
	var moved_distance: float = player.global_position.distance_to(last_player_position)
	var speed: float = 0.0
	if player is CharacterBody3D:
		speed = (player as CharacterBody3D).velocity.length()

	return has_move_input or moved_distance > 0.01 or speed > 0.05


func _apply_distortion(progress: float) -> void:
	var position_amount: float = lerp(0.03, max_position_shake, progress)
	var rotation_amount: float = deg_to_rad(lerp(0.5, max_rotation_shake_degrees, progress))

	player_camera.position = camera_start_position + Vector3(
		randf_range(-position_amount, position_amount),
		randf_range(-position_amount, position_amount),
		0.0
	)
	player_camera.rotation = camera_start_rotation + Vector3(
		randf_range(-rotation_amount, rotation_amount),
		randf_range(-rotation_amount, rotation_amount),
		randf_range(-rotation_amount, rotation_amount) * 0.35
	)
	player_camera.fov = camera_start_fov + randf_range(-max_fov_jitter, max_fov_jitter) * progress
	_set_distortion_alpha(lerp(0.08, 0.58, progress))


func _reset_distortion() -> void:
	state = "normal"
	idle_timer = 0.0
	distortion_timer = 0.0
	_restore_camera()
	_set_distortion_alpha(0.0)


func _start_vhs_return() -> void:
	state = "vhs_returning"
	vhs_timer = 0.0
	_restore_camera()
	_set_distortion_alpha(0.0)
	vhs_ui.visible = true
	vhs_static_texture.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_vhs_static() -> void:
	var jitter: float = 5.0
	vhs_static_texture.offset_left = randf_range(-jitter, jitter)
	vhs_static_texture.offset_top = randf_range(-jitter, jitter)
	vhs_static_texture.offset_right = randf_range(-jitter, jitter)
	vhs_static_texture.offset_bottom = randf_range(-jitter, jitter)
	vhs_static_texture.modulate.a = randf_range(0.88, 1.0)


func _restore_camera() -> void:
	player_camera.position = camera_start_position
	player_camera.rotation = camera_start_rotation
	player_camera.fov = camera_start_fov


func _set_distortion_alpha(alpha: float) -> void:
	var color: Color = distortion_overlay.color
	color.a = alpha
	distortion_overlay.color = color
	distortion_overlay.visible = alpha > 0.0
