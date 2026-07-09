extends Node3D
class_name AmbientFaunaController

@export var enabled: bool = true
@export var bird_count: int = 3
@export var seed_value: int = 9669
@export var orbit_radius: float = 115.0
@export var flight_height: float = 34.0

var _birds: Array[Node3D] = []
var _speeds: Array[float] = []
var _phase_offsets: Array[float] = []


func _ready() -> void:
	if not enabled:
		return
	_build_birds()


func _process(delta: float) -> void:
	if not enabled:
		return
	for i in range(_birds.size()):
		var bird := _birds[i]
		var phase := Time.get_ticks_msec() * 0.001 * _speeds[i] + _phase_offsets[i]
		var radius := orbit_radius + sin(phase * 0.47) * 18.0
		var x := cos(phase) * radius - 35.0
		var z := sin(phase * 0.84) * radius
		var y := flight_height + sin(phase * 1.7) * 2.4
		var old_pos := bird.position
		bird.position = Vector3(x, y, z)
		if bird.position.distance_squared_to(old_pos) > 0.001:
			bird.look_at(old_pos, Vector3.UP)


func _build_birds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := clampi(bird_count, 0, 4)
	for i in range(count):
		var bird := _make_bird("DistantBird_%02d" % i)
		add_child(bird)
		_birds.append(bird)
		_speeds.append(rng.randf_range(0.018, 0.036))
		_phase_offsets.append(rng.randf_range(0.0, TAU))


func _make_bird(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BirdSilhouetteMesh"
	mesh_instance.mesh = _bird_mesh()
	mesh_instance.set_surface_override_material(0, _bird_material())
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh_instance)
	root.scale = Vector3.ONE * 0.82
	return root


func _bird_mesh() -> Mesh:
	var vertices := PackedVector3Array([
		Vector3(-0.95, 0.0, 0.0),
		Vector3(-0.08, 0.0, 0.12),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.08, 0.0, 0.12),
		Vector3(0.95, 0.0, 0.0),
		Vector3(0.0, -0.06, -0.18)
	])
	var indices := PackedInt32Array([0, 1, 2, 2, 3, 4, 1, 5, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _bird_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.052, 0.047, 0.78)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
