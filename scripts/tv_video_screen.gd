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
var _video_texture_apply_serial := 0
var _video_viewport: SubViewport
var _video_host_setup_queued := false
var _channel_play_queued := false
var _queued_flash_static := false


func _ready() -> void:
	_prepare_screen_material()
	_queue_video_player_host_setup()
	if _is_headless():
		_apply_fallback_screen_color()
		return
	_queue_channel_play(false)


func _exit_tree() -> void:
	if video_player != null:
		video_player.stop()
		video_player.stream = null


func set_channel(channel: int, flash_static: bool = true) -> void:
	_pending_channel = clampi(channel, 1, channel_paths.size())
	if _is_headless():
		_apply_fallback_screen_color()
		return
	_queue_channel_play(flash_static)


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
	_video_texture_apply_serial += 1
	_apply_video_texture_after_frames(_video_texture_apply_serial)


func _queue_video_player_host_setup() -> void:
	if _video_host_setup_queued:
		return
	_video_host_setup_queued = true
	call_deferred("_flush_video_player_host_setup")


func _flush_video_player_host_setup() -> void:
	_video_host_setup_queued = false
	_ensure_video_player_host()


func _ensure_video_player_host() -> bool:
	if video_player == null:
		video_player = VideoStreamPlayer.new()
		video_player.name = "TVVideoPlayer"

	_video_viewport = get_node_or_null("TVVideoViewport") as SubViewport
	if _video_viewport == null:
		_video_viewport = SubViewport.new()
		_video_viewport.name = "TVVideoViewport"
		_video_viewport.size = Vector2i(640, 360)
		_video_viewport.disable_3d = true
		_video_viewport.transparent_bg = false
		_video_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		_video_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_video_viewport)

	if video_player.get_parent() != _video_viewport:
		var old_parent := video_player.get_parent()
		if old_parent != null:
			old_parent.remove_child(video_player)
		_video_viewport.add_child(video_player)

	video_player.visible = true
	video_player.position = Vector2.ZERO
	video_player.size = Vector2(_video_viewport.size)
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_player.volume_db = volume_db
	video_player.autoplay = false
	video_player.loop = true
	_apply_viewport_texture_to_screen()
	return true


func _queue_channel_play(flash_static: bool) -> void:
	_channel_play_queued = true
	_queued_flash_static = flash_static
	_queue_video_player_host_setup()
	call_deferred("_flush_channel_play")


func _flush_channel_play() -> void:
	if not _channel_play_queued:
		return
	if not _ensure_video_player_host():
		call_deferred("_flush_channel_play")
		return

	var flash_static := _queued_flash_static
	_channel_play_queued = false
	_queued_flash_static = false
	if flash_static and ResourceLoader.exists(fallback_video_path):
		_play_video_path(fallback_video_path)
		await get_tree().create_timer(static_flash_seconds).timeout
	_play_pending_channel()


func _prepare_screen_material() -> void:
	if screen_mesh == null:
		push_warning("TVVideoScreen: Screen MeshInstance3D missing.")
		return

	_screen_material = StandardMaterial3D.new()
	_screen_material.albedo_color = Color.WHITE
	_screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen_material.roughness = 0.28
	_screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_screen_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_screen_material.emission_enabled = true
	_screen_material.emission = Color.WHITE
	_screen_material.emission_energy_multiplier = screen_emission_energy
	screen_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen_mesh.material_override = null
	screen_mesh.set_surface_override_material(0, _screen_material)


func _apply_video_texture_after_frames(serial: int) -> void:
	for _frame in range(16):
		if serial != _video_texture_apply_serial:
			return
		if _apply_video_texture():
			return
		await get_tree().process_frame
	if serial == _video_texture_apply_serial:
		_apply_video_texture()


func _apply_video_texture() -> bool:
	if _screen_material == null:
		return false

	var texture: Texture2D = null
	if _video_viewport != null:
		texture = _video_viewport.get_texture()
	elif video_player != null:
		texture = video_player.get_video_texture()
	if texture == null:
		return false

	screen_mesh.material_override = null
	_screen_material.albedo_color = Color.WHITE
	_screen_material.emission = Color.WHITE
	_screen_material.albedo_texture = texture
	_screen_material.emission_texture = texture
	_screen_material.emission_energy_multiplier = screen_emission_energy
	return true


func _apply_viewport_texture_to_screen() -> void:
	if _screen_material == null or _video_viewport == null:
		return
	var texture := _video_viewport.get_texture()
	if texture == null:
		return
	_screen_material.albedo_color = Color.WHITE
	_screen_material.emission = Color.WHITE
	_screen_material.albedo_texture = texture
	_screen_material.emission_texture = texture
	_screen_material.emission_energy_multiplier = screen_emission_energy


func _apply_fallback_screen_color() -> void:
	if _screen_material == null:
		return

	_screen_material.albedo_texture = null
	_screen_material.emission_texture = null
	_screen_material.albedo_color = Color(0.16, 0.42, 0.34, 1.0)
	_screen_material.emission = Color(0.16, 0.42, 0.34, 1.0)
	_screen_material.emission_energy_multiplier = 1.4


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
