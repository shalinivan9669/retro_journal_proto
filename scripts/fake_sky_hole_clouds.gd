extends Node3D

@export var rotation_speed: float = 0.16
@export var cloud_spin_speed: float = -0.08
@export var cloud_drift_speed: float = 0.34
@export var cloud_drift_amount: float = 0.07

var _time := 0.0
var _cloud_base_positions := {}
var _cloud_phases := {}


func _ready() -> void:
	_cache_clouds()


func _process(delta: float) -> void:
	_time += delta
	rotate_y(rotation_speed * delta)

	for child in get_children():
		if child is MeshInstance3D and _is_cloud_node(child):
			var cloud := child as MeshInstance3D
			if not _cloud_base_positions.has(cloud):
				_cache_cloud(cloud)
			var base_position: Vector3 = _cloud_base_positions[cloud]
			var phase: float = _cloud_phases[cloud]
			cloud.position.x = base_position.x + sin(_time * cloud_drift_speed + phase) * cloud_drift_amount
			cloud.position.z = base_position.z + cos(_time * cloud_drift_speed * 0.73 + phase * 1.37) * cloud_drift_amount * 0.7
			cloud.rotate_y(cloud_spin_speed * delta)


func _cache_clouds() -> void:
	for child in get_children():
		if child is MeshInstance3D and _is_cloud_node(child):
			_cache_cloud(child as MeshInstance3D)


func _cache_cloud(cloud: MeshInstance3D) -> void:
	_cloud_base_positions[cloud] = cloud.position
	_cloud_phases[cloud] = float(abs(hash(cloud.name)) % 1000) * 0.01


func _is_cloud_node(node: Node) -> bool:
	return node.name.begins_with("Cloud") or node.name.begins_with("FallbackCloud")
