extends Node
class_name TVVideoScreen

@export var video_player_path: NodePath = NodePath("../VideoPlayer")
@export var screen_mesh_path: NodePath = NodePath("../VisibleTVModel/Screen")
@export var static_flash_seconds: float = 0.28
@export var volume_db: float = -8.0
@export var screen_emission_energy: float = 1.65
@export var fallback_video_path: String = "res://assets/videos/tv/tv_static_fallback.ogv"

var channel_paths: Array[String] = [
	"res://assets/videos/tv/tv_ch01.ogv",
	"res://assets/videos/tv/tv_ch02.ogv",
	"res://assets/videos/tv/tv_ch03.ogv",
	"res://assets/videos/tv/tv_ch04.ogv",
	"res://assets/videos/tv/tv_ch05.ogv",
	"res://assets/videos/tv/tv_static_fallback.ogv"
]

@onready var video_player: VideoStreamPlayer = get_node_or_null(video_player_path)
@onready var screen_mesh: MeshInstance3D = get_node_or_null(screen_mesh_path)

var _screen_material: StandardMaterial3D
var _pending_channel: int = 1


func _ready() -> void:
	_prepare_screen_material()
	if video_player != null:
		video_player.visible = false
		video_player.volume_db = volume_db
		video_player.autoplay = false
		video_player.loop = true
	if _is_headless():
		_apply_fallback_screen_color()
		return
	set_channel(1, false)


func _exit_tree() -> void:
	if video_player != null:
		video_player.stop()
		video_player.stream = null


func set_channel(channel: int, flash_static: bool = true) -> void:
	_pending_channel = clampi(channel, 1, channel_paths.size())
	if _is_headless():
		_apply_fallback_screen_color()
		return
	if flash_static and ResourceLoader.exists(fallback_video_path):
		_play_video_path(fallback_video_path)
		await get_tree().create_timer(static_flash_seconds).timeout
	_play_pending_channel()


func _play_pending_channel() -> void:
	var index := clampi(_pending_channel - 1, 0, channel_paths.size() - 1)
	var path := channel_paths[index]
	if not ResourceLoader.exists(path):
		path = fallback_video_path
	_play_video_path(path)


func _play_video_path(path: String) -> void:
	if video_player == null:
		push_warning("TVVideoScreen: VideoPlayer node missing.")
		_apply_fallback_screen_color()
		return
	if not ResourceLoader.exists(path):
		push_warning("TV video missing: " + path)
		_apply_fallback_screen_color()
		return

	var stream := load(path)
	if stream == null:
		push_warning("TV video failed to load: " + path)
		_apply_fallback_screen_color()
		return

	video_player.stream = stream
	video_player.play()
	call_deferred("_apply_video_texture")


func _prepare_screen_material() -> void:
	if screen_mesh == null:
		push_warning("TVVideoScreen: Screen MeshInstance3D missing.")
		return

	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = Color(0.035, 0.1, 0.075, 1.0)
	_screen_material.roughness = 0.28
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_screen_material.emission_enabled = true
	_screen_material.emission = Color(0.08, 0.22, 0.16, 1.0)
	_screen_material.emission_energy_multiplier = screen_emission_energy
	screen_mesh.set_surface_override_material(0, _screen_material)


func _apply_video_texture() -> void:
	if video_player == null or _screen_material == null:
		return

	var texture := video_player.get_video_texture()
	if texture == null:
		return

	_screen_material.albedo_texture = texture
	_screen_material.emission_texture = texture
	_screen_material.emission_energy_multiplier = screen_emission_energy


func _apply_fallback_screen_color() -> void:
	if _screen_material == null:
		return

	_screen_material.albedo_texture = null
	_screen_material.emission_texture = null
	_screen_material.albedo_color = Color(0.03, 0.08, 0.06, 1.0)
	_screen_material.emission = Color(0.06, 0.18, 0.13, 1.0)
	_screen_material.emission_energy_multiplier = 0.7


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
