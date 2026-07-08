extends CanvasLayer

@export var toggle_key := KEY_1
@export_range(0.12, 0.35, 0.01) var screen_width_ratio: float = 0.24
@export_range(0.45, 0.9, 0.01) var screen_height_ratio: float = 0.72
@export var animation_time: float = 0.22

var _phone_root: Control
var _screen: ColorRect
var _tween: Tween
var _is_open := false
var _animating := false


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout_phone)
	_build_phone_ui()
	_apply_screen_shader()
	_set_phone_open(false, true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			_set_phone_open(not _is_open)
			get_viewport().set_input_as_handled()
			return
		if _is_open and _is_other_keyboard_action(event):
			_set_phone_open(false)
			return

	if _is_open and event is InputEventMouseButton and event.pressed:
		_set_phone_open(false)


func _process(_delta: float) -> void:
	if not _is_open:
		return

	if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
		_set_phone_open(false)


func _build_phone_ui() -> void:
	_phone_root = Control.new()
	_phone_root.name = "PhoneRoot"
	_phone_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_phone_root)

	var halo := ColorRect.new()
	halo.name = "PhoneLightHalo"
	halo.color = Color(0.60, 0.78, 1.0, 0.14)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_root.add_child(halo)

	var frame := ColorRect.new()
	frame.name = "PhoneBlackFrame"
	frame.color = Color(0.015, 0.014, 0.012, 1.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_root.add_child(frame)

	_screen = ColorRect.new()
	_screen.name = "PhoneWhiteScreen"
	_screen.color = Color(0.90, 0.96, 1.0, 1.0)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_screen)

	var inner_glow := ColorRect.new()
	inner_glow.name = "PhoneInnerGlow"
	inner_glow.color = Color(0.72, 0.86, 1.0, 0.16)
	inner_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(inner_glow)

	_layout_phone()


func _layout_phone() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var phone_width := viewport_size.x * screen_width_ratio
	var phone_height := viewport_size.y * screen_height_ratio
	phone_width = clampf(phone_width, 150.0, 315.0)
	phone_height = maxf(phone_height, phone_width * 1.95)

	var margin_x := maxf(18.0, viewport_size.x * 0.035)
	var margin_y := maxf(4.0, viewport_size.y * 0.018)
	_phone_root.size = Vector2(phone_width + 46.0, phone_height + 54.0)
	var target_y := viewport_size.y - _phone_root.size.y - margin_y + 18.0
	target_y = minf(target_y, viewport_size.y - _phone_root.size.y - 2.0)
	_phone_root.position = Vector2(viewport_size.x - _phone_root.size.x - margin_x, target_y)

	var halo := _phone_root.get_node("PhoneLightHalo") as ColorRect
	halo.position = Vector2(0.0, 0.0)
	halo.size = _phone_root.size

	var frame := _phone_root.get_node("PhoneBlackFrame") as ColorRect
	frame.position = Vector2(23.0, 27.0)
	frame.size = Vector2(phone_width, phone_height)

	_screen.position = Vector2(5.0, 5.0)
	_screen.size = frame.size - Vector2(10.0, 10.0)
	var inner_glow := _screen.get_node("PhoneInnerGlow") as ColorRect
	inner_glow.position = Vector2.ZERO
	inner_glow.size = _screen.size


func _apply_screen_shader() -> void:
	if _screen == null:
		return

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 screen_color : source_color = vec4(0.90, 0.96, 1.0, 1.0);
uniform float flicker_strength = 0.035;
uniform float scanline_strength = 0.018;

void fragment() {
	float flicker = sin(TIME * 18.0) * flicker_strength + sin(TIME * 41.0) * flicker_strength * 0.5;
	float scanline = sin(UV.y * 760.0) * scanline_strength;
	vec3 col = screen_color.rgb + vec3(flicker - scanline);
	COLOR = vec4(col, screen_color.a);
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	_screen.material = material


func _set_phone_open(open: bool, immediate: bool = false) -> void:
	if _is_open == open and not immediate:
		return

	_is_open = open
	_animating = not immediate
	if _tween != null:
		_tween.kill()

	_phone_root.visible = true
	_layout_phone()

	var viewport_size := get_viewport().get_visible_rect().size
	var shown_position := _phone_root.position
	var hidden_position := Vector2(shown_position.x, viewport_size.y + 16.0)

	if immediate:
		_phone_root.position = shown_position if open else hidden_position
		_phone_root.modulate.a = 1.0 if open else 0.0
		_phone_root.visible = open
		_animating = false
		return

	if open:
		_phone_root.position = hidden_position
		_phone_root.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	_tween.tween_property(_phone_root, "position", shown_position if open else hidden_position, animation_time)
	_tween.tween_property(_phone_root, "modulate:a", 1.0 if open else 0.0, animation_time)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		_phone_root.visible = _is_open
		_animating = false
	)


func _is_other_keyboard_action(event: InputEventKey) -> bool:
	if event.keycode == KEY_W or event.keycode == KEY_A or event.keycode == KEY_S or event.keycode == KEY_D:
		return false
	if event.keycode == KEY_SHIFT or event.keycode == KEY_CTRL or event.keycode == KEY_ALT:
		return false
	return true
