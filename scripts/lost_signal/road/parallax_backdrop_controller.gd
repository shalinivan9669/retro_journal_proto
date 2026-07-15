class_name LostSignalParallaxBackdropController
extends Node3D

@export var road_path := NodePath("../LoopingRoad")
@export var left_material: ShaderMaterial
@export var right_material: ShaderMaterial
@export_range(0.0, 0.1, 0.001) var left_motion_factor := 0.012
@export_range(0.0, 0.1, 0.001) var right_motion_factor := 0.045
@export_range(100.0, 10000.0, 1.0) var left_panorama_span_m := 6702.0
@export_range(100.0, 10000.0, 1.0) var right_panorama_span_m := 3072.0


func _ready() -> void:
	var road := get_node_or_null(road_path)
	if road == null:
		push_warning("BackdropRig could not find the looping road at %s." % road_path)
		return
	if not road.has_signal(&"distance_advanced"):
		push_warning("BackdropRig requires the road distance_advanced signal.")
		return
	road.connect(&"distance_advanced", _on_distance_advanced)
	_on_distance_advanced(0.0)


func _on_distance_advanced(distance_m: float) -> void:
	# The lake scrolls toward its hidden outer edge; the right ridge scrolls in
	# the opposite direction. This keeps any texture wrap outside the available
	# head-turn range while preserving only a very weak sense of parallax.
	_set_offset(left_material, -distance_m, left_motion_factor, left_panorama_span_m)
	_set_offset(right_material, distance_m, right_motion_factor, right_panorama_span_m)


func _set_offset(material: ShaderMaterial, distance_m: float, factor: float, span_m: float) -> void:
	if material == null:
		return
	material.set_shader_parameter("travel_uv_offset", distance_m * factor / maxf(span_m, 1.0))
