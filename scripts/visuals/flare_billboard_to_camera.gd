extends MeshInstance3D

@export var camera_path: NodePath

func _process(_delta: float) -> void:
	var cam: Camera3D = null
	if camera_path != NodePath(""):
		cam = get_node_or_null(camera_path) as Camera3D
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam:
		look_at(cam.global_position, Vector3.UP)
