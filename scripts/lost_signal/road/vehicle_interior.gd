class_name LostSignalVehicleInterior
extends Node3D

@export_range(0.0, 24.0, 0.1) var headlight_energy := 11.2
@export_range(40.0, 180.0, 1.0) var headlight_range := 128.0
@export_range(0.0, 0.25, 0.005) var beam_motion_strength_degrees := 0.055
@export_range(1.0, 200.0, 0.5) var imported_vehicle_scale := 100.0
@export var imported_vehicle_offset := Vector3(0.0, 0.05, 0.0)
@export var driver_eye_position := Vector3(-0.43, 1.42, -0.10)

const TRAVERSE_MODEL_PATH := "res://assets/lost_signal/vehicles/chevrolet_traverse_rs/2023_chevrolet_traverse_rs.glb"
const HEADLIGHT_HEIGHT := 0.97
const LOW_BEAM_TARGET_DISTANCE := 28.0
const LOW_BEAM_HALF_WIDTH := 7.4
const PROJECTOR_TARGET_DISTANCE := 105.0
const PROJECTOR_HALF_WIDTH := 5.2
const SHOULDER_SPILL_TARGET_DISTANCE := 22.0
const SHOULDER_SPILL_HALF_WIDTH := 9.5

var yaw_pivot: Node3D
var pitch_pivot: Node3D
var camera: Camera3D
var dashcam_focus_anchor: Marker3D
var front_feed_anchor: Marker3D
var rear_feed_anchor: Marker3D
var dashcam_screen_mesh: MeshInstance3D
var dashboard_lights: Array[Node3D] = []
var headlight_layers: Array[SpotLight3D] = []
var headlight_base_rotations: Array[Vector3] = []


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
	if _build_imported_vehicle():
		_build_dashcam(self, metal, vinyl, gauge)
		_build_camera_rig()
		_build_headlights()
		return

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


func _build_imported_vehicle() -> bool:
	var packed := load(TRAVERSE_MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("Chevrolet Traverse model is unavailable; using the procedural vehicle fallback.")
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		push_warning("Chevrolet Traverse model could not be instantiated; using the procedural vehicle fallback.")
		return false
	model.name = "ChevroletTraverseRS2023"
	model.position = imported_vehicle_offset
	model.rotation_degrees.y = 180.0
	model.scale = Vector3.ONE * imported_vehicle_scale
	add_child(model)
	for candidate in model.find_children("*", "Camera3D", true, false):
		var imported_camera := candidate as Camera3D
		imported_camera.current = false
	for candidate in model.find_children("*", "Light3D", true, false):
		var imported_light := candidate as Light3D
		imported_light.visible = false
	return true


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
	root.position = Vector3(0.42, 1.58, -0.72)
	parent.add_child(root)
	LostSignalVisualFactory.box(root, "Body", Vector3(0.34, 0.19, 0.10), Vector3.ZERO, dark, Vector3(-3, 0, 0))
	dashcam_screen_mesh = LostSignalVisualFactory.box(root, "Screen", Vector3(0.26, 0.12, 0.012), Vector3(0, 0, -0.058), screen, Vector3(-3, 0, 0), false)
	dashcam_screen_mesh.set_layer_mask_value(1, false)
	dashcam_screen_mesh.set_layer_mask_value(4, true)
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
	yaw_pivot.position = driver_eye_position
	add_child(yaw_pivot)
	pitch_pivot = Node3D.new()
	pitch_pivot.name = "DriverPitchPivot"
	yaw_pivot.add_child(pitch_pivot)
	camera = Camera3D.new()
	camera.name = "DriverCamera"
	camera.fov = 60.0
	camera.near = 0.04
	camera.far = 260.0
	camera.current = true
	pitch_pivot.add_child(camera)
	front_feed_anchor = Marker3D.new()
	front_feed_anchor.name = "FrontFeedAnchor"
	front_feed_anchor.position = Vector3(0, 1.46, -0.84)
	add_child(front_feed_anchor)
	rear_feed_anchor = Marker3D.new()
	rear_feed_anchor.name = "RearFeedAnchor"
	rear_feed_anchor.position = Vector3(0, 1.46, 0.82)
	rear_feed_anchor.rotation_degrees.y = 180.0
	add_child(rear_feed_anchor)


func _build_headlights() -> void:
	var low_pitch := -rad_to_deg(atan(HEADLIGHT_HEIGHT / LOW_BEAM_TARGET_DISTANCE))
	var low_angle := rad_to_deg(atan(LOW_BEAM_HALF_WIDTH / LOW_BEAM_TARGET_DISTANCE))
	var projector_pitch := -rad_to_deg(atan(HEADLIGHT_HEIGHT / PROJECTOR_TARGET_DISTANCE))
	var projector_angle := rad_to_deg(atan(PROJECTOR_HALF_WIDTH / PROJECTOR_TARGET_DISTANCE))
	var spill_pitch := -rad_to_deg(atan(HEADLIGHT_HEIGHT / SHOULDER_SPILL_TARGET_DISTANCE))
	var spill_angle := rad_to_deg(atan(SHOULDER_SPILL_HALF_WIDTH / SHOULDER_SPILL_TARGET_DISTANCE))
	var low_cookie := _make_beam_cookie(false)
	var projector_cookie := _make_beam_cookie(true)

	# Outer reflectors: wide, low, asymmetric pools over the first 30 metres.
	for x in [-0.69, 0.69]:
		var low_beam := SpotLight3D.new()
		low_beam.name = "LowBeamLeft" if x < 0.0 else "LowBeamRight"
		low_beam.position = Vector3(x, HEADLIGHT_HEIGHT, -2.15)
		low_beam.rotation_degrees.x = low_pitch
		low_beam.rotation_degrees.y = -1.25 if x < 0.0 else 1.25
		low_beam.light_color = Color(1.0, 0.82, 0.64)
		low_beam.light_energy = headlight_energy
		low_beam.spot_range = 68.0
		low_beam.spot_angle = low_angle
		low_beam.spot_angle_attenuation = 1.65
		low_beam.light_projector = low_cookie
		low_beam.light_volumetric_fog_energy = 0.44
		low_beam.shadow_enabled = true
		low_beam.shadow_bias = 0.025
		add_child(low_beam)
		headlight_layers.append(low_beam)
		headlight_base_rotations.append(low_beam.rotation_degrees)

	# Inner lenses: narrow hot spots focused one hundred metres down the road.
	for x in [-0.43, 0.43]:
		var projector := SpotLight3D.new()
		projector.name = "ProjectorLeft" if x < 0.0 else "ProjectorRight"
		projector.position = Vector3(x, HEADLIGHT_HEIGHT + 0.015, -2.17)
		projector.rotation_degrees.x = projector_pitch
		projector.rotation_degrees.y = -0.35 if x < 0.0 else 0.35
		projector.light_color = Color(1.0, 0.90, 0.76)
		projector.light_energy = headlight_energy * 0.82
		projector.spot_range = headlight_range
		projector.spot_angle = projector_angle
		projector.spot_angle_attenuation = 1.12
		projector.light_projector = projector_cookie
		projector.light_volumetric_fog_energy = 0.68
		projector.shadow_enabled = false
		add_child(projector)
		headlight_layers.append(projector)
		headlight_base_rotations.append(projector.rotation_degrees)

	# Real reflector housings leak a weak, broad layer into both verges. These
	# two independent pools reveal nearby scrub without flattening the horizon.
	for x in [-0.72, 0.72]:
		var spill := SpotLight3D.new()
		spill.name = "ShoulderSpillLeft" if x < 0.0 else "ShoulderSpillRight"
		spill.position = Vector3(x, HEADLIGHT_HEIGHT, -2.12)
		spill.rotation_degrees.x = spill_pitch
		spill.rotation_degrees.y = -7.0 if x < 0.0 else 7.0
		spill.light_color = Color(1.0, 0.78, 0.57)
		spill.light_energy = headlight_energy * 0.34
		spill.spot_range = 48.0
		spill.spot_angle = spill_angle
		spill.spot_angle_attenuation = 2.25
		spill.light_volumetric_fog_energy = 0.075
		spill.shadow_enabled = false
		add_child(spill)
		headlight_layers.append(spill)
		headlight_base_rotations.append(spill.rotation_degrees)
	var cabin := OmniLight3D.new()
	cabin.name = "DashboardBounce"
	cabin.position = Vector3(-0.25, 1.18, -0.85)
	cabin.omni_range = 2.2
	cabin.light_color = Color(0.12, 0.56, 0.68)
	cabin.light_energy = 0.24
	cabin.shadow_enabled = false
	add_child(cabin)


func update_headlight_motion(distance_travelled: float) -> void:
	# A few hundredths of a degree become several centimetres of light travel
	# at 100 m, enough to imply suspension motion without visible camera shake.
	var pitch_offset := (
		sin(distance_travelled * 0.71) * 0.72
		+ sin(distance_travelled * 2.13 + 0.8) * 0.28
	) * beam_motion_strength_degrees
	var yaw_offset := sin(distance_travelled * 0.29) * beam_motion_strength_degrees * 0.22
	for index in headlight_layers.size():
		var base := headlight_base_rotations[index]
		headlight_layers[index].rotation_degrees = Vector3(base.x + pitch_offset, base.y + yaw_offset, base.z)


func _make_beam_cookie(focused: bool) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for py in 128:
		for px in 128:
			var u := (float(px) + 0.5) / 128.0 * 2.0 - 1.0
			var v := (float(py) + 0.5) / 128.0 * 2.0 - 1.0
			var horizontal_scale := 0.46 if focused else 0.92
			var vertical_scale := 0.42 if focused else 0.58
			var shifted_v := v - (0.04 if focused else 0.16)
			var elliptical_radius := pow(absf(u) / horizontal_scale, 4.0) + pow(absf(shifted_v) / vertical_scale, 4.0)
			var optical_falloff := exp(-elliptical_radius * (1.42 if focused else 1.08))
			var cutoff := 1.0
			if not focused:
				cutoff = smoothstep(-0.30, -0.08, v)
			var intensity := clampf(optical_falloff * cutoff, 0.0, 1.0)
			image.set_pixel(px, py, Color(intensity, intensity, intensity, 1.0))
	return ImageTexture.create_from_image(image)
