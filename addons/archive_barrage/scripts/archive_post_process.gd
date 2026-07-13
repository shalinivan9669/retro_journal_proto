class_name ArchivePostProcess
extends CanvasLayer

const FILM_SHADER := preload("res://addons/archive_barrage/shaders/archive_film.gdshader")

var retina_level := 0.0
var _spots := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _material: ShaderMaterial


func _ready() -> void:
	layer = 100
	_material = ShaderMaterial.new()
	_material.shader = FILM_SHADER

	var rect := ColorRect.new()
	rect.name = "ArchiveFilmPass"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _material
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_update_viewport_aspect)
	_update_viewport_aspect()


func register_flash(camera: Camera3D, world_position: Vector3, energy: float) -> void:
	if camera == null or camera.is_position_behind(world_position):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(world_position)
	var uv := Vector2(screen.x / viewport_size.x, screen.y / viewport_size.y)
	if uv.x < -0.2 or uv.x > 1.2 or uv.y < -0.2 or uv.y > 1.2:
		return

	var strength := clampf(energy / 30.0, 0.0, 1.0)
	retina_level = maxf(retina_level, strength)

	var weakest := 0
	for index in range(1, _spots.size()):
		if _spots[index].z < _spots[weakest].z:
			weakest = index
	_spots[weakest] = Vector3(uv.x, uv.y, strength)


func _process(delta: float) -> void:
	retina_level *= exp(-delta / 0.82)
	for index in range(_spots.size()):
		_spots[index].z *= exp(-delta / 0.52)

	_material.set_shader_parameter("retina_level", retina_level)
	for index in range(_spots.size()):
		_material.set_shader_parameter("retina_spot_%d" % index, _spots[index])


func _update_viewport_aspect() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	_material.set_shader_parameter("viewport_aspect", aspect)
