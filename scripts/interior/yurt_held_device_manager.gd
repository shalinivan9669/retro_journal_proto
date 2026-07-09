extends Node
class_name YurtHeldDeviceManager

const CASSETTE_SCENE_PATHS := [
	"res://assets/polyhaven/props/cassette_player_2k.gltf",
	"res://assets/polyhaven/props/cassette_player_1k.gltf",
	"res://assets/polyhaven/processed/interior/cassette_player_viewmodel.glb"
]

@export var enabled: bool = true
@export var camera_path: NodePath
@export var viewmodel_position := Vector3(0.46, -0.08, -0.88)
@export var viewmodel_rotation_degrees := Vector3(-8.0, -17.0, 3.0)
@export var viewmodel_scale := Vector3.ONE * 2.72

var _viewmodel: Node3D


func set_held_open(open: bool) -> void:
	if not enabled:
		return
	_ensure_viewmodel()
	if _viewmodel == null:
		return
	_viewmodel.visible = open


func _ensure_viewmodel() -> void:
	if _viewmodel != null and is_instance_valid(_viewmodel):
		return
	var camera := _find_camera()
	if camera == null:
		return
	_viewmodel = _instantiate_cassette()
	_viewmodel.name = "HeldCassettePlayerViewmodel"
	_viewmodel.position = viewmodel_position
	_viewmodel.rotation_degrees = viewmodel_rotation_degrees
	_viewmodel.scale = viewmodel_scale
	_viewmodel.visible = false
	camera.add_child(_viewmodel)


func _find_camera() -> Camera3D:
	if camera_path != NodePath():
		var camera := get_node_or_null(camera_path)
		if camera is Camera3D:
			return camera as Camera3D
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var player := scene.get_node_or_null("Player")
	if player != null:
		var camera := player.get_node_or_null("Head/Camera3D")
		if camera is Camera3D:
			return camera as Camera3D
	return get_viewport().get_camera_3d()


func _instantiate_cassette() -> Node3D:
	for path in CASSETTE_SCENE_PATHS:
		if not ResourceLoader.exists(path, "PackedScene"):
			continue
		var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		var node := instance as Node3D
		if node != null:
			_prepare_imported(node)
			return node
		var wrapper := Node3D.new()
		wrapper.add_child(instance)
		return wrapper
	return _make_fallback_cassette()


func _prepare_imported(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_prepare_imported(child)


func _make_fallback_cassette() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackHeldCassettePlayer"
	var body_mat := _mat(Color(0.055, 0.052, 0.048, 1.0), 0.74)
	var metal_mat := _mat(Color(0.45, 0.43, 0.38, 1.0), 0.52)
	var label_mat := _mat(Color(0.78, 0.68, 0.45, 1.0), 0.88)
	_add_box(root, "CassetteBody", Vector3(1.35, 0.78, 0.18), Vector3.ZERO, body_mat)
	_add_box(root, "CassetteLabel", Vector3(0.68, 0.32, 0.025), Vector3(0.0, 0.02, -0.105), label_mat)
	for x in [-0.34, 0.34]:
		var reel := MeshInstance3D.new()
		reel.name = "TapeReel"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.16
		mesh.bottom_radius = 0.16
		mesh.height = 0.035
		mesh.radial_segments = 28
		reel.mesh = mesh
		reel.position = Vector3(x, 0.02, -0.13)
		reel.rotation_degrees.x = 90.0
		reel.set_surface_override_material(0, metal_mat)
		root.add_child(reel)
	for index in range(5):
		_add_box(root, "TopButton_%02d" % index, Vector3(0.15, 0.06, 0.08), Vector3(-0.36 + float(index) * 0.18, 0.45, -0.03), metal_mat)
	return root


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
