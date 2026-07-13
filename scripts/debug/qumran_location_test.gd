extends Node3D

@export var respawn_height := -32.0
@export var debug_update_interval := 0.12

@onready var visual_root: Node3D = $Terrain/VisualMesh
@onready var terrain_body: StaticBody3D = $Terrain/StaticBody3D
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var player: CharacterBody3D = $Player
@onready var kill_plane: Area3D = $NavigationAndBoundaries/KillPlane
@onready var stats_label: Label = $DebugUI/Panel/Margin/VBox/Stats

var _collision_ready := false
var _debug_elapsed := 0.0


func _ready() -> void:
	_build_terrain_collision_once()
	kill_plane.body_entered.connect(_on_kill_plane_body_entered)
	_update_debug_ui()


func _process(delta: float) -> void:
	if player.global_position.y < respawn_height:
		_respawn_player()
	_debug_elapsed += delta
	if _debug_elapsed >= debug_update_interval:
		_debug_elapsed = 0.0
		_update_debug_ui()


func _build_terrain_collision_once() -> void:
	if _collision_ready or terrain_body.get_child_count() > 0:
		return
	var collision_count := 0
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		if shape == null:
			continue
		# Full photogrammetry collision is acceptable for this static debug level.
		# Replace these two shapes with a decimated proxy if the source scan grows.
		shape.backface_collision = true
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "TerrainCollision_%02d" % collision_count
		collision_shape.shape = shape
		terrain_body.add_child(collision_shape)
		collision_shape.global_transform = mesh_instance.global_transform
		collision_count += 1
	_collision_ready = collision_count > 0
	if not _collision_ready:
		push_error("QumranLocationTest: no terrain meshes were available for collision")


func _on_kill_plane_body_entered(body: Node3D) -> void:
	if body == player:
		_respawn_player.call_deferred()


func _respawn_player() -> void:
	player.global_transform = player_spawn.global_transform
	player.velocity = Vector3.ZERO
	player.set("pitch", 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation.x = 0.0


func _update_debug_ui() -> void:
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	stats_label.text = (
		"FPS: %d\nPosition: %.1f, %.1f, %.1f\nOn floor: %s\nSpeed: %.1f m/s"
		% [
			Engine.get_frames_per_second(),
			player.global_position.x,
			player.global_position.y,
			player.global_position.z,
			"yes" if player.is_on_floor() else "no",
			horizontal_speed,
		]
	)
