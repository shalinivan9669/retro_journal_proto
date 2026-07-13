class_name LostSignalHUD
extends CanvasLayer

var chapter_label: Label
var objective_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: RichTextLabel
var prompt_panel: PanelContainer
var prompt_label: Label
var status_label: Label
var center_dot: ColorRect
var _subtitle_serial := 0


func _ready() -> void:
	layer = 120
	_build_ui()


func show_chapter(kicker: String, title: String, duration := 3.2) -> void:
	chapter_label.text = "[ %s ]\n%s" % [kicker.to_upper(), title.to_upper()]
	chapter_label.modulate.a = 0.0
	chapter_label.visible = true
	var tween := create_tween()
	tween.tween_property(chapter_label, "modulate:a", 1.0, 0.45)
	tween.tween_interval(duration)
	tween.tween_property(chapter_label, "modulate:a", 0.0, 0.7)


func set_objective(text: String) -> void:
	objective_label.text = text
	objective_label.visible = not text.is_empty()


func show_subtitle(speaker: String, line: String, duration := 2.8) -> void:
	_subtitle_serial += 1
	var serial := _subtitle_serial
	subtitle_label.text = "[color=#9bbcca]%s[/color]\n%s" % [speaker.to_upper(), line]
	subtitle_panel.visible = true
	subtitle_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(subtitle_panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration)
	tween.tween_property(subtitle_panel, "modulate:a", 0.0, 0.25)
	await tween.finished
	if serial == _subtitle_serial:
		subtitle_panel.visible = false


func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = not text.is_empty()


func hide_prompt() -> void:
	prompt_panel.visible = false


func set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()


func set_center_dot_visible(value: bool) -> void:
	center_dot.visible = value


func _build_ui() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec2 p=UV*2.0-1.0; float v=smoothstep(0.32,1.38,dot(p,p)); float scan=sin(UV.y*1080.0)*0.008; COLOR=vec4(0.005,0.008,0.015,clamp(v*0.50+scan,0.0,0.62));}"
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	vignette.material = shader_material
	add_child(vignette)

	chapter_label = Label.new()
	chapter_label.position = Vector2(54, 50)
	chapter_label.size = Vector2(780, 130)
	chapter_label.add_theme_font_size_override("font_size", 27)
	chapter_label.add_theme_color_override("font_color", Color(0.75, 0.86, 0.9))
	chapter_label.add_theme_constant_override("line_spacing", 8)
	chapter_label.visible = false
	add_child(chapter_label)

	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-630, 48)
	objective_label.size = Vector2(570, 55)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.76))
	add_child(objective_label)

	center_dot = ColorRect.new()
	center_dot.set_anchors_preset(Control.PRESET_CENTER)
	center_dot.position = Vector2(-2, -2)
	center_dot.size = Vector2(4, 4)
	center_dot.color = Color(0.82, 0.9, 0.92, 0.72)
	center_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_dot)

	subtitle_panel = PanelContainer.new()
	subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_panel.position = Vector2(-420, -190)
	subtitle_panel.size = Vector2(840, 105)
	var subtitle_style := StyleBoxFlat.new()
	subtitle_style.bg_color = Color(0.012, 0.018, 0.026, 0.88)
	subtitle_style.border_color = Color(0.18, 0.29, 0.34, 0.8)
	subtitle_style.set_border_width_all(1)
	subtitle_style.set_corner_radius_all(3)
	subtitle_style.content_margin_left = 24
	subtitle_style.content_margin_right = 24
	subtitle_style.content_margin_top = 13
	subtitle_style.content_margin_bottom = 13
	subtitle_panel.add_theme_stylebox_override("panel", subtitle_style)
	subtitle_panel.visible = false
	add_child(subtitle_panel)
	subtitle_label = RichTextLabel.new()
	subtitle_label.bbcode_enabled = true
	subtitle_label.fit_content = true
	subtitle_label.scroll_active = false
	subtitle_label.add_theme_font_size_override("normal_font_size", 21)
	subtitle_label.add_theme_color_override("default_color", Color(0.91, 0.92, 0.89))
	subtitle_panel.add_child(subtitle_label)

	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.position = Vector2(-270, -68)
	prompt_panel.size = Vector2(540, 42)
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.01, 0.016, 0.022, 0.78)
	prompt_style.border_color = Color(0.28, 0.45, 0.5, 0.55)
	prompt_style.set_border_width_all(1)
	prompt_style.set_corner_radius_all(2)
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	prompt_panel.visible = false
	add_child(prompt_panel)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.78, 0.9, 0.92))
	prompt_panel.add_child(prompt_label)

	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position = Vector2(38, -54)
	status_label.size = Vector2(740, 28)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.42, 0.58, 0.62))
	add_child(status_label)
