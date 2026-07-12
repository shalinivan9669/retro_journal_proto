class_name BasementPropSetBuilder
extends RefCounted

const FAN_SCRIPT: Script = preload("res://scripts/props/ceiling_fan.gd")
const CAMERA_SCRIPT: Script = preload("res://scripts/props/security_camera_mount.gd")

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
