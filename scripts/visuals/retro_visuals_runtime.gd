extends Node

## Safe stage-1 visual installer for retro_journal_proto.
## Add scenes/visuals/VisualEffectsRuntime.tscn as a child of Main.tscn.
## It does NOT change gameplay. It only creates runtime materials/lights/overlay.

@export var tune_world_environment := true
@export var apply_tv_radio_emission := true
@export var enable_device_glitch_overlay := true
@export var enable_outdoor_sandstorm := false # Keep off by default. Enable manually after checking it outside the yurt.

@export var glitch_distance := 0.5
@export var tv_light_energy := 0.55
@export var radio_light_energy := 0.16
@export var tv_light_range := 3.0
@export var radio_light_range := 1.4

@export var sandstorm_position := Vector3(0.0, 1.65, -14.0)
@export var sandstorm_size := Vector3(42.0, 4.5, 30.0)

const TV_MATERIAL_PATH := "res://materials/devices/mat_tv_screen_glow.tres"
const RADIO_MATERIAL_PATH := "res://materials/devices/mat_radio_display_glow.tres"
const GLITCH_MATERIAL_PATH := "res://materials/postprocess/mat_glitch_double_vision_soft.tres"
const SANDSTORM_MATERIAL_PATH := "res://materials/fog/mat_sandstorm_fog_soft.tres"

var _glitch_overlay: ColorRect
var _glitch_targets: Array[Node3D] = []
var _device_points: Array[Node3D] = []

func _ready() -> void:
	if tune_world_environment:
		_tune_world_environment()

	if apply_tv_radio_emission:
		_apply_device_materials_and_lights()

	if enable_device_glitch_overlay:
		_create_glitch_overlay()

	if enable_outdoor_sandstorm:
		_create_outdoor_sandstorm()

func _process(_delta: float) -> void:
	_update_glitch_overlay()

func _tune_world_environment() -> void:
	var world_env := _find_node_by_class(get_tree().current_scene, "WorldEnvironment") as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return

	var env := world_env.environment
	_safe_set(env, "glow_enabled", true)
	_safe_set(env, "glow_intensity", 0.22)
	_safe_set(env, "glow_strength", 0.55)
	_safe_set(env, "adjustment_enabled", true)
	_safe_set(env, "adjustment_saturation", 0.82)
	_safe_set(env, "adjustment_contrast", 1.12)
	_safe_set(env, "ambient_light_energy", 0.34)
	_safe_set(env, "fog_enabled", true)
	_safe_set(env, "fog_density", 0.0035)
	_safe_set(env, "fog_light_color", Color(0.42, 0.40, 0.37, 1.0))

func _apply_device_materials_and_lights() -> void:
	var tv_root := get_tree().current_scene.find_child("InteractableTV", true, false)
	var radio_root := get_tree().current_scene.find_child("RadioOnBox", true, false)

	if tv_root is Node3D:
		_apply_device(tv_root, TV_MATERIAL_PATH, Color(0.17, 0.78, 0.68), tv_light_energy, tv_light_range, "TVColdScreenLight", false)

	if radio_root is Node3D:
		_apply_device(radio_root, RADIO_MATERIAL_PATH, Color(1.0, 0.32, 0.08), radio_light_energy, radio_light_range, "RadioAmberDisplayLight", true)

func _apply_device(root: Node, material_path: String, light_color: Color, energy: float, light_range: float, light_name: String, override_screen_material: bool) -> void:
	if not ResourceLoader.exists(material_path):
		push_warning("Visual material not found: " + material_path)
		return

	var mat := load(material_path) as Material
	var screen_mesh := _find_screen_mesh(root)
	if screen_mesh:
		if override_screen_material:
			screen_mesh.material_override = mat
		if screen_mesh is Node3D:
			_device_points.append(screen_mesh)

	if root is Node3D:
		root.add_to_group("glitch_device")
		_glitch_targets.append(root)

		if root.find_child(light_name, false, false) == null:
			var light := OmniLight3D.new()
			light.name = light_name
			light.light_color = light_color
			light.light_energy = energy
			light.omni_range = light_range
			light.shadow_enabled = false
			root.add_child(light)

			if screen_mesh and screen_mesh is Node3D:
				light.global_position = (screen_mesh as Node3D).global_position
			else:
				light.position = Vector3(0.0, 0.25, 0.0)

func _create_glitch_overlay() -> void:
	if not ResourceLoader.exists(GLITCH_MATERIAL_PATH):
		push_warning("Glitch material not found: " + GLITCH_MATERIAL_PATH)
		return

	var layer := CanvasLayer.new()
	layer.name = "DeviceGlitchOverlayLayer"
	layer.layer = 80
	add_child(layer)

	_glitch_overlay = ColorRect.new()
	_glitch_overlay.name = "DeviceGlitchOverlay"
	_glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_overlay.offset_left = 0
	_glitch_overlay.offset_top = 0
	_glitch_overlay.offset_right = 0
	_glitch_overlay.offset_bottom = 0
	_glitch_overlay.material = load(GLITCH_MATERIAL_PATH)
	_glitch_overlay.visible = false
	layer.add_child(_glitch_overlay)

func _update_glitch_overlay() -> void:
	if _glitch_overlay == null:
		return

	var camera := _find_active_camera(get_tree().current_scene)
	if camera == null:
		_glitch_overlay.visible = false
		return

	var active := false
	for point in _device_points:
		if is_instance_valid(point):
			var d := camera.global_position.distance_to(point.global_position)
			if d <= glitch_distance:
				active = true
				break

	if not active:
		for target in _glitch_targets:
			if is_instance_valid(target):
				var d2 := camera.global_position.distance_to(target.global_position)
				if d2 <= glitch_distance:
					active = true
					break

	_glitch_overlay.visible = active

func _create_outdoor_sandstorm() -> void:
	if not ClassDB.class_exists("FogVolume"):
		push_warning("FogVolume class is not available in this renderer/build.")
		return

	if not ResourceLoader.exists(SANDSTORM_MATERIAL_PATH):
		push_warning("Sandstorm material not found: " + SANDSTORM_MATERIAL_PATH)
		return

	if get_tree().current_scene.find_child("OutdoorSandstormFogVolume", true, false):
		return

	var fog := FogVolume.new()
	fog.name = "OutdoorSandstormFogVolume"
	fog.position = sandstorm_position
	fog.size = sandstorm_size
	fog.material = load(SANDSTORM_MATERIAL_PATH)
	get_tree().current_scene.add_child.call_deferred(fog)

func _find_screen_mesh(root: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var stack: Array[Node] = [root]

	while stack.size() > 0:
		var node: Node = stack.pop_back()
		var lower: String = node.name.to_lower()
		if node is MeshInstance3D:
			if lower.contains("screen") or lower.contains("display") or lower.contains("monitor") or lower.contains("crt"):
				return node as MeshInstance3D
			if best == null:
				best = node as MeshInstance3D
		for child in node.get_children():
			stack.append(child)

	return best

func _find_active_camera(root: Node) -> Camera3D:
	if root == null:
		return null

	var fallback: Camera3D = null
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is Camera3D:
			var cam := node as Camera3D
			if cam.current:
				return cam
			if fallback == null:
				fallback = cam
		for child in node.get_children():
			stack.append(child)
	return fallback

func _find_node_by_class(root: Node, target_class_name: String) -> Node:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node.get_class() == target_class_name or node.is_class(target_class_name):
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _safe_set(obj: Object, property_name: String, property_value: Variant) -> void:
	if obj == null:
		return
	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == property_name:
			obj.set(property_name, property_value)
			return
