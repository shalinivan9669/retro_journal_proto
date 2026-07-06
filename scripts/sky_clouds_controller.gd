extends Node

# Attach this to Main.tscn as SkyCloudsController.
# Expected nodes can be assigned in Inspector or found by names.
@export var cloud_dark_path: NodePath
@export var cloud_rose_path: NodePath
@export var cloud_dark_speed := Vector3(0.03, 0.0, 0.0)
@export var cloud_rose_speed := Vector3(0.055, 0.0, 0.012)
@export var loop_radius := 260.0

var cloud_dark: Node3D
var cloud_rose: Node3D
var dark_start := Vector3.ZERO
var rose_start := Vector3.ZERO

func _ready() -> void:
	_resolve_cloud_nodes()

func _process(delta: float) -> void:
	if cloud_dark == null or cloud_rose == null:
		_resolve_cloud_nodes()

	if cloud_dark:
		cloud_dark.global_position += cloud_dark_speed * delta
		if cloud_dark.global_position.distance_to(dark_start) > loop_radius:
			cloud_dark.global_position = dark_start
	if cloud_rose:
		cloud_rose.global_position += cloud_rose_speed * delta
		if cloud_rose.global_position.distance_to(rose_start) > loop_radius:
			cloud_rose.global_position = rose_start


func _resolve_cloud_nodes() -> void:
	if cloud_dark == null and cloud_dark_path != NodePath(""):
		cloud_dark = get_node_or_null(cloud_dark_path) as Node3D
	if cloud_rose == null and cloud_rose_path != NodePath(""):
		cloud_rose = get_node_or_null(cloud_rose_path) as Node3D
	if cloud_dark == null and get_tree().current_scene != null:
		cloud_dark = get_tree().current_scene.find_child("CloudLayerDarkAshRed", true, false) as Node3D
	if cloud_rose == null and get_tree().current_scene != null:
		cloud_rose = get_tree().current_scene.find_child("CloudLayerRoseAshRed", true, false) as Node3D
	if cloud_dark and dark_start == Vector3.ZERO:
		dark_start = cloud_dark.global_position
	if cloud_rose and rose_start == Vector3.ZERO:
		rose_start = cloud_rose.global_position
