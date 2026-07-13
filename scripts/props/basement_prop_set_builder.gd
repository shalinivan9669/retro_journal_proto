class_name BasementPropSetBuilder
extends RefCounted

const FAN_SCRIPT: Script = preload("res://scripts/props/ceiling_fan.gd")
const CAMERA_SCRIPT: Script = preload("res://scripts/props/security_camera_mount.gd")
const TERMINAL_SCRIPT: Script = preload("res://scripts/basement_terminal.gd")
const TERMINAL_SHADER: Shader = preload("res://shaders/terminal_monochrome.gdshader")
const TERMINAL_IMAGE: Texture2D = preload("res://assets/archive/terminals/terminal_walking_walls.png")

const CART_PATH := "res://assets/polyhaven/industrial_storage_cart/industrial_storage_cart_4k.gltf"
const LAPTOP_PATH := "res://assets/polyhaven/classic_laptop/classic_laptop_4k.gltf"
const RADIO_PATH := "res://assets/polyhaven/vintage_radio_transceiver/vintage_radio_transceiver_4k.gltf"
const CAMERA_PATH := "res://assets/polyhaven/security_camera_02/security_camera_02_4k.gltf"
const FAN_PATH := "res://assets/polyhaven/ceiling_fan/ceiling_fan_4k.gltf"


static func build(parent: Node3D, turn_center: Vector3, workstation_center: Vector3, camera_center: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "BasementPropsRoot"
	parent.add_child(root)

	var target := Marker3D.new()
	target.name = "WorkstationLookTarget"
	root.add_child(target)
	target.global_position = workstation_center + Vector3(0.96, 1.15, 0.0)

	_build_workstation(root, workstation_center)
	_build_camera(root, camera_center, target)
	_build_fan(root, turn_center)
	return root


static func _build_workstation(root: Node3D, center: Vector3) -> void:
	var workstation := Node3D.new()
	workstation.name = "WorkstationRoot"
	root.add_child(workstation)
	workstation.global_position = center + Vector3(0.96, 0.0, 0.0)

	var cart := _instantiate_model(CART_PATH, "StorageCart")
	if cart != null:
		cart.rotation_degrees.y = 90.0
		workstation.add_child(cart)

	var collision := StaticBody3D.new()
	collision.name = "StorageCartCollision"
	collision.position = Vector3(0.0, 0.69, 0.0)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.10, 1.38, 1.60)
	shape_node.shape = shape
	collision.add_child(shape_node)
	workstation.add_child(collision)

	var laptop := _instantiate_model(LAPTOP_PATH, "Laptop")
	if laptop != null:
		laptop.position = Vector3(-0.02, 1.39, -0.38)
		laptop.rotation_degrees.y = 180.0
		workstation.add_child(laptop)
		_build_laptop_terminal(laptop)

	var radio := _instantiate_model(RADIO_PATH, "Radio")
	if radio != null:
		radio.position = Vector3(0.0, 1.49, 0.36)
		radio.rotation_degrees.y = 180.0
		workstation.add_child(radio)

	var glow := OmniLight3D.new()
	glow.name = "LaptopRadioGlow"
	glow.position = Vector3(-0.18, 1.72, -0.15)
	glow.light_color = Color(0.48, 0.72, 0.46, 1.0)
	glow.light_energy = 0.22
	glow.omni_range = 2.1
	workstation.add_child(glow)


static func _build_laptop_terminal(laptop: Node3D) -> void:
	# The imported Poly Haven laptop exposes its display under this name. The
	# terminal is a thin separate surface above it, preserving the real laptop.
	var laptop_screen := laptop.find_child("classic_laptop_screen", true, false) as MeshInstance3D
	if laptop_screen == null:
		push_warning("Basement terminal: classic_laptop_screen mesh was not found.")
		return

	var screen_material := ShaderMaterial.new()
	screen_material.shader = TERMINAL_SHADER
	screen_material.set_shader_parameter("terminal_image", TERMINAL_IMAGE)
	screen_material.set_shader_parameter("power", 0.0)

	# A 1 mm overlay sits directly in front of the native display surface. It
	# keeps the physical laptop bezel intact and supplies clean rectangular UVs.
	var screen_overlay := MeshInstance3D.new()
	screen_overlay.name = "WalkingWallsScreenOverlay"
	var overlay_mesh := QuadMesh.new()
	overlay_mesh.size = Vector2(0.44, 0.36)
	screen_overlay.mesh = overlay_mesh
	screen_overlay.position = Vector3(0.0, 0.24, 0.039)
	screen_overlay.material_override = screen_material
	screen_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laptop_screen.add_child(screen_overlay)

	var indicator_material := StandardMaterial3D.new()
	indicator_material.albedo_color = Color(0.42, 0.04, 0.02, 1.0)
	indicator_material.emission_enabled = true
	indicator_material.emission = Color(1.0, 0.08, 0.025, 1.0)
	indicator_material.emission_energy_multiplier = 0.05
	var indicator := MeshInstance3D.new()
	indicator.name = "PowerIndicator"
	var indicator_mesh := SphereMesh.new()
	indicator_mesh.radius = 0.014
	indicator_mesh.height = 0.028
	indicator.mesh = indicator_mesh
	indicator.position = Vector3(0.196, 0.081, 0.048)
	indicator.set_surface_override_material(0, indicator_material)
	laptop_screen.add_child(indicator)

	var light := OmniLight3D.new()
	light.name = "TerminalScreenGlow"
	light.position = Vector3(0.0, 0.24, 0.08)
	light.light_color = Color(0.85, 0.96, 0.88, 1.0)
	light.light_energy = 0.0
	light.omni_range = 2.3
	light.shadow_enabled = false
	laptop_screen.add_child(light)

	var button := Area3D.new()
	button.name = "TerminalPowerButton"
	button.set_script(TERMINAL_SCRIPT)
	button.position = Vector3(0.196, 0.081, 0.056)
	var button_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.055, 0.055, 0.04)
	button_shape.shape = shape
	button.add_child(button_shape)
	laptop_screen.add_child(button)
	button.call("configure", screen_material, light, indicator)


static func _build_camera(root: Node3D, center: Vector3, target: Marker3D) -> void:
	var surveillance := Node3D.new()
	surveillance.name = "SurveillanceRoot"
	root.add_child(surveillance)
	surveillance.global_position = center + Vector3(1.23, 2.45, -0.72)

	var pivot := Node3D.new()
	pivot.name = "SecurityCameraPivot"
	pivot.set_script(CAMERA_SCRIPT)
	surveillance.add_child(pivot)
	pivot.set("target_path", pivot.get_path_to(target))

	var camera := _instantiate_model(CAMERA_PATH, "SecurityCamera")
	if camera != null:
		camera.scale = Vector3.ONE * 1.45
		pivot.add_child(camera)

	var led := OmniLight3D.new()
	led.name = "CameraRedLED"
	led.position = Vector3(0.0, 0.0, 0.23)
	led.light_color = Color(1.0, 0.03, 0.02, 1.0)
	led.light_energy = 0.08
	led.omni_range = 0.65
	pivot.add_child(led)


static func _build_fan(root: Node3D, center: Vector3) -> void:
	var fan_root := Node3D.new()
	fan_root.name = "EntranceFanRoot"
	fan_root.set_script(FAN_SCRIPT)
	root.add_child(fan_root)
	fan_root.global_position = center + Vector3(0.0, 2.32, 0.0)

	var fan := _instantiate_model(FAN_PATH, "CeilingFan")
	if fan != null:
		fan_root.add_child(fan)


static func _instantiate_model(path: String, node_name: String) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Missing basement prop model: %s" % path)
		return null
	var model := scene.instantiate() as Node3D
	if model != null:
		model.name = node_name
	return model
