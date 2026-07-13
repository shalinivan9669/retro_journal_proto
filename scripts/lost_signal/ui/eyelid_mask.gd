class_name LostSignalEyelidMask
extends Control

var closure := 0.0:
	set(value):
		closure = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if closure <= 0.001:
		return
	var width := size.x
	var height := size.y
	var center := height * 0.5
	var top_edge := lerpf(0.0, center + height * 0.035, closure)
	var bottom_edge := lerpf(height, center - height * 0.035, closure)
	var base_curve := height * 0.085 * (1.0 - closure * 0.65)
	var top_curve := minf(base_curve, maxf(0.0, top_edge * 0.72))
	var bottom_curve := minf(base_curve, maxf(0.0, (height - bottom_edge) * 0.72))
	var points_top := PackedVector2Array([
		Vector2(0, 0), Vector2(width, 0),
		Vector2(width, top_edge - top_curve),
		Vector2(width * 0.78, top_edge - top_curve * 0.2),
		Vector2(width * 0.5, top_edge + top_curve),
		Vector2(width * 0.22, top_edge - top_curve * 0.2),
		Vector2(0, top_edge - top_curve),
	])
	var points_bottom := PackedVector2Array([
		Vector2(0, height), Vector2(width, height),
		Vector2(width, bottom_edge + bottom_curve),
		Vector2(width * 0.78, bottom_edge + bottom_curve * 0.2),
		Vector2(width * 0.5, bottom_edge - bottom_curve),
		Vector2(width * 0.22, bottom_edge + bottom_curve * 0.2),
		Vector2(0, bottom_edge + bottom_curve),
	])
	var black := Color(0.002, 0.003, 0.006, 1.0)
	draw_colored_polygon(points_top, black)
	draw_colored_polygon(points_bottom, black)
