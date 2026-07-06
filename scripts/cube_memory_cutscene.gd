extends CanvasLayer

const CUTSCENE_DURATION := 13.0
const BASE_SWITCH_TIME := 9.5

const TEX_BASE_01 := preload("res://assets/textures/cutscene/cs_base_01.png")
const TEX_BASE_04 := preload("res://assets/textures/cutscene/cs_base_04.png")
const TEX_FLASH_02 := preload("res://assets/textures/cutscene/cs_flash_02.png")
const TEX_FLASH_03 := preload("res://assets/textures/cutscene/cs_flash_03.png")
const TEX_FLASH_06 := preload("res://assets/textures/cutscene/cs_flash_06.png")
const TEX_FLASH_07 := preload("res://assets/textures/cutscene/cs_flash_07.png")

@onready var base_image: TextureRect = $BaseImage
@onready var flash_overlay: TextureRect = $FlashOverlay

var _elapsed := 0.0
var _playing := false
var _player: Node = null
var _aim_dot_ui: Node = null


func _ready() -> void:
	add_to_group("cube_memory_cutscene_ui")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_image.texture = TEX_BASE_01
	flash_overlay.visible = false


func _input(_event: InputEvent) -> void:
	if _playing:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _playing:
		return

	_elapsed += delta
	base_image.texture = TEX_BASE_04 if _elapsed >= BASE_SWITCH_TIME else TEX_BASE_01

	var flash_texture := _get_flash_texture(_elapsed)
	flash_overlay.visible = flash_texture != null
	flash_overlay.texture = flash_texture

	if _elapsed >= CUTSCENE_DURATION:
		_finish_cutscene()


func play_cutscene() -> void:
	if _playing:
		return

	_elapsed = 0.0
	_playing = true
	visible = true
	base_image.texture = TEX_BASE_01
	flash_overlay.visible = false
	_lock_player()


func _finish_cutscene() -> void:
	_playing = false
	visible = false
	flash_overlay.visible = false
	_unlock_player()
	_show_memory_painting()


func _lock_player() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	_player = scene.get_node_or_null("Player")
	if _player != null:
		_player.set("controls_locked", true)
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO

	_aim_dot_ui = scene.get_node_or_null("AimDotUI")
	if _aim_dot_ui != null:
		_aim_dot_ui.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unlock_player() -> void:
	if _player != null:
		_player.set("controls_locked", false)
	if _aim_dot_ui != null:
		_aim_dot_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _show_memory_painting() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var painting := scene.get_node_or_null("MemoryPainting")
	if painting != null:
		painting.visible = true


func _get_flash_texture(time: float) -> Texture2D:
	if time >= 3.0 and time < 3.12:
		return TEX_FLASH_02
	if time >= 5.0 and time < 5.12:
		return TEX_FLASH_03
	if time >= 5.24 and time < 5.36:
		return TEX_FLASH_02
	if time >= 5.52 and time < 5.64:
		return TEX_FLASH_03
	if time >= 5.76 and time < 5.88:
		return TEX_FLASH_03
	if time >= 10.6 and time < 10.82:
		return TEX_FLASH_06
	if time >= 12.0 and time < 12.22:
		return TEX_FLASH_07
	return null
