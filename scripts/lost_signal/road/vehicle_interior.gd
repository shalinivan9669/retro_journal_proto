class_name LostSignalVehicleInterior
extends Node3D

var yaw_pivot: Node3D
var pitch_pivot: Node3D
var camera: Camera3D
var dashcam_focus_anchor: Marker3D
var front_feed_anchor: Marker3D
var rear_feed_anchor: Marker3D
var dashcam_screen_mesh: MeshInstance3D
var dashboard_lights: Array[Node3D] = []


func _ready() -> void:
	_build_vehicle()


func _build_vehicle() -> void:
	var vinyl := LostSignalVisualFactory.material(Color(0.025, 0.031, 0.038), 0.78)
	var vinyl_soft := LostSignalVisualFactory.material(Color(0.045, 0.052, 0.058), 0.9)
	var metal := LostSignalVisualFactory.material(Color(0.075, 0.09, 0.1), 0.34, 0.62)
	var trim := LostSignalVisualFactory.material(Color(0.14, 0.16, 0.17), 0.44, 0.22)
	var glass := LostSignalVisualFactory.material(Color(0.055, 0.095, 0.13, 0.18), 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var gauge := LostSignalVisualFactory.material(
		Color(0.015, 0.028, 0.03), 0.42, 0.0,
		Color(0.15, 0.74, 0.79), 1.8
	)
	var red_gauge := LostSignalVisualFactory.material(
		Color(0.07, 0.015, 0.01), 0.4, 0.0,
		Color(0.95, 0.14, 0.05), 1.4
	)

	var shell := Node3D.new()
	shell.name = "DetailedVehicleInterior"
	add_child(shell)
	LostSignalVisualFactory.box(shell, "Dashboard", Vector3(2.25, 0.42, 0.72), Vector3(0, 1.02, -1.05), vinyl, Vector3(-4, 0, 0))
	LostSignalVisualFactory.box(shell, "DashboardTop", Vector3(2.15, 0.10, 0.78), Vector3(0, 1.25, -1.08), vinyl_soft, Vector3(-6, 0, 0))
	LostSignalVisualFactory.box(shell, "CenterConsole", Vector3(0.38, 0.28, 1.55), Vector3(0.34, 0.62, -0.16), vinyl_soft, Vector3(-5, 0, 0))
	LostSignalVisualFactory.box(shell, "DriverDoor", Vector3(0.14, 0.72, 1.75), Vector3(-1.09, 0.93, 0.12), vinyl)
	LostSignalVisualFactory.box(shell, "PassengerDoor", Vector3(0.14, 0.72, 1.75), Vector3(1.09, 0.93, 0.12), vinyl)
	LostSignalVisualFactory.box(shell, "Roof", Vector3(2.18, 0.12, 2.7), Vector3(0, 2.02, 0.2), vinyl_soft)
	LostSignalVisualFactory.box(shell, "LeftAPillar", Vector3(0.13, 1.15, 0.16), Vector3(-0.94, 1.60, -0.72), trim, Vector3(18, 0, -13))
	LostSignalVisualFactory.box(shell, "RightAPillar", Vector3(0.13, 1.15, 0.16), Vector3(0.94, 1.60, -0.72), trim, Vector3(18, 0, 13))
	LostSignalVisualFactory.box(shell, "LeftBpillar", Vector3(0.14, 1.35, 0.18), Vector3(-1.02, 1.38, 0.62), trim)
	LostSignalVisualFactory.box(shell, "RightBpillar", Vector3(0.14, 1.35, 0.18), Vector3(1.02, 1.38, 0.62), trim)
	LostSignalVisualFactory.box(shell, "Windshield", Vector3(1.78, 0.93, 0.018), Vector3(0, 1.57, -0.86), glass, Vector3(-17, 0, 0), false)
	LostSignalVisualFactory.box(shell, "LeftWindow", Vector3(0.02, 0.7, 1.02), Vector3(-1.02, 1.52, 0.05), glass, Vector3.ZERO, false)
	LostSignalVisualFactory.box(shell, "RightWindow", Vector3(0.02, 0.7, 1.02), Vector3(1.02, 1.52, 0.05), glass, Vector3.ZERO, false)
	LostSignalVisualFactory.box(shell, "Hood", Vector3(1.78, 0.13, 2.4), Vector3(0, 0.83, -2.34), metal, Vector3(-2, 0, 0))

	_build_seat(shell, "DriverSeat", Vector3(-0.43, 0.58, 0.43), vinyl_soft)
	_build_seat(shell, "PassengerSeat", Vector3(0.62, 0.58, 0.43), vinyl_soft)

	var wheel_root := Node3D.new()
	wheel_root.name = "SteeringWheel"
	wheel_root.position = Vector3(-0.43, 1.12, -0.71)
	wheel_root.rotation_degrees = Vector3(68, 0, 0)
	shell.add_child(wheel_root)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.29
	torus.rings = 28
	torus.ring_segments = 10
	wheel.mesh = torus
	wheel.set_surface_override_material(0, vinyl_soft)
	wheel_root.add_child(wheel)
	LostSignalVisualFactory.box(wheel_root, "SpokeL", Vector3(0.22, 0.045, 0.06), Vector3(-0.11, 0, 0), trim)
	LostSignalVisualFactory.box(wheel_root, "SpokeR", Vector3(0.22, 0.045, 0.06), Vector3(0.11, 0, 0), trim)
	LostSignalVisualFactory.cylinder(wheel_root, "Hub", 0.105, 0.09, Vector3.ZERO, trim, Vector3(90, 0, 0), 20)

	LostSignalVisualFactory.cylinder(shell, "GaugeLeft", 0.17, 0.035, Vector3(-0.66, 1.22, -1.39), gauge, Vector3(90, 0, 0), 32)
	LostSignalVisualFactory.cylinder(shell, "GaugeRight", 0.17, 0.035, Vector3(-0.25, 1.22, -1.39), gauge, Vector3(90, 0, 0), 32)
	LostSignalVisualFactory.box(shell, "RadioDisplay", Vector3(0.38, 0.14, 0.035), Vector3(0.29, 1.14, -1.405), gauge)
	for index in 5:
		var indicator := LostSignalVisualFactory.box(shell, "Indicator%02d" % index, Vector3(0.035, 0.018, 0.018), Vector3(0.11 + index * 0.07, 1.27, -1.43), red_gauge, Vector3.ZERO, false)
		dashboard_lights.append(indicator)

	LostSignalVisualFactory.box(shell, "RearViewMirror", Vector3(0.62, 0.22, 0.055), Vector3(0, 1.72, -0.59), metal, Vector3(-5, 0, 0))
	var mirror_face := LostSignalVisualFactory.box(shell, "RearMirrorGlass", Vector3(0.56, 0.17, 0.012), Vector3(0, 1.72, -0.622), glass, Vector3(-5, 0, 0), false)
	mirror_face.set_layer_mask_value(4, false)

	_build_dashcam(shell, metal, vinyl, gauge)
	_build_camera_rig()
	_build_headlights()


func _build_seat(parent: Node, name: String, position: Vector3, mat: Material) -> void:
	var root := Node3D.new()
	root.name = name
	root.position = position
	parent.add_child(root)
	LostSignalVisualFactory.box(root, "Cushion", Vector3(0.62, 0.16, 0.7), Vector3(0, 0, 0.08), mat, Vector3(-5, 0, 0))
	LostSignalVisualFactory.box(root, "Back", Vector3(0.62, 0.88, 0.16), Vector3(0, 0.48, 0.39), mat, Vector3(-8, 0, 0))
	LostSignalVisualFactory.box(root, "Headrest", Vector3(0.34, 0.30, 0.17), Vector3(0, 1.04, 0.31), mat)


func _build_dashcam(parent: Node, metal: Material, dark: Material, screen: Material) -> void:
	var root := Node3D.new()
	root.name = "DashcamDevice"
	root.position = Vector3(0.48, 1.68, -0.66)
	parent.add_child(root)
	LostSignalVisualFactory.box(root, "Body", Vector3(0.34, 0.19, 0.10), Vector3.ZERO, dark, Vector3(-3, 0, 0))
	dashcam_screen_mesh = LostSignalVisualFactory.box(root, "Screen", Vector3(0.26, 0.12, 0.012), Vector3(0, 0, -0.058), screen, Vector3(-3, 0, 0), false)
	dashcam_screen_mesh.set_layer_mask_value(1, false)
	dashcam_screen_mesh.set_layer_mask_value(4, true)
	LostSignalVisualFactory.cylinder(root, "Lens", 0.045, 0.035, Vector3(0.12, 0.0, 0.07), metal, Vector3(90, 0, 0), 16)
	LostSignalVisualFactory.cylinder(root, "Mount", 0.025, 0.22, Vector3(0, 0.20, 0.03), metal, Vector3.ZERO, 10)
	dashcam_focus_anchor = Marker3D.new()
	dashcam_focus_anchor.name = "DashcamFocusAnchor"
	dashcam_focus_anchor.position = Vector3(0.0, -0.02, 0.26)
	# The dashcam screen faces the windshield (-Z). Keeping the focus anchor
	# aligned with the front camera prevents the cinematic zoom from turning
	# the road and the diner 180 degrees backwards.
	dashcam_focus_anchor.rotation_degrees = Vector3(-2, 0, 0)
	root.add_child(dashcam_focus_anchor)


func _build_camera_rig() -> void:
	yaw_pivot = Node3D.new()
	yaw_pivot.name = "DriverYawPivot"
	yaw_pivot.position = Vector3(-0.43, 1.49, 0.34)
	add_child(yaw_pivot)
	pitch_pivot = Node3D.new()
	pitch_pivot.name = "DriverPitchPivot"
	yaw_pivot.add_child(pitch_pivot)
	camera = Camera3D.new()
	camera.name = "DriverCamera"
	camera.fov = 72.0
	camera.near = 0.04
	camera.far = 260.0
	camera.current = true
	pitch_pivot.add_child(camera)
	front_feed_anchor = Marker3D.new()
	front_feed_anchor.name = "FrontFeedAnchor"
	front_feed_anchor.position = Vector3(0, 1.57, -0.78)
	add_child(front_feed_anchor)
	rear_feed_anchor = Marker3D.new()
	rear_feed_anchor.name = "RearFeedAnchor"
	rear_feed_anchor.position = Vector3(0, 1.58, 0.78)
	rear_feed_anchor.rotation_degrees.y = 180.0
	add_child(rear_feed_anchor)


func _build_headlights() -> void:
	for x in [-0.62, 0.62]:
		var light := SpotLight3D.new()
		light.name = "HeadlightL" if x < 0.0 else "HeadlightR"
		light.position = Vector3(x, 0.72, -2.15)
		light.rotation_degrees.x = -8.0
		light.light_color = Color(0.83, 0.9, 1.0)
		light.light_energy = 9.0
		light.spot_range = 64.0
		light.spot_angle = 28.0
		light.spot_angle_attenuation = 0.72
		light.shadow_enabled = x < 0.0
		add_child(light)
	var road_fill := SpotLight3D.new()
	road_fill.name = "CombinedHeadlightFill"
	road_fill.position = Vector3(0, 0.82, -2.0)
	road_fill.rotation_degrees.x = -7.0
	road_fill.light_color = Color(0.69, 0.82, 1.0)
	road_fill.light_energy = 4.2
	road_fill.spot_range = 72.0
	road_fill.spot_angle = 37.0
	road_fill.spot_angle_attenuation = 0.9
	road_fill.shadow_enabled = false
	add_child(road_fill)
	var cabin := OmniLight3D.new()
	cabin.name = "DashboardBounce"
	cabin.position = Vector3(-0.25, 1.18, -0.85)
	cabin.omni_range = 2.2
	cabin.light_color = Color(0.12, 0.56, 0.68)
	cabin.light_energy = 0.52
	cabin.shadow_enabled = false
	add_child(cabin)
