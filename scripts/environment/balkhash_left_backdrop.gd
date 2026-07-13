extends Node3D

const ARC := preload("res://scripts/environment/balkhash_backdrop_arc.gd")
const LAYER_SHADER := preload("res://shaders/balkhash_backdrop_layer.gdshader")

@export var enabled := true
@export var sector_yaw_offset_degrees := -90.0
@export var sector_arc_degrees := 110.0
@export var horizon_height_offset := 0.0
@export var global_scale_multiplier := 1.0
@export var debug_enabled := false
@export var show_far_horizon := true
@export var show_lake_water := true
@export var show_distant_treeline := true
@export var show_side_dead_trees := true
@export var show_foreground_reeds := true

var _player: Node3D
var _spawn_player_position := Vector3.ZERO
var _layers: Array[Dictionary] = []

func _ready() -> void:
	visible = enabled
	call_deferred("_initialize_after_scene_ready")

func _initialize_after_scene_ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		push_warning("Balkhash backdrop could not find Player")
		return
	_spawn_player_position = _player.global_position
	# Spawn forward is -Z, spawn left is -X; sector is a fixed 90 degree left turn.
	# Keep the complete lake/shore backdrop at the far edge. The five cards are
	# separated by exactly 5 m so their parallax remains readable without any
	# layer drifting into the playable foreground.
	_build_layer($FarHorizon, "00_far_horizon", 220.0, 0.98, 1.1, 10.0, show_far_horizon, 0)
	_build_layer($LakeWater, "01_lake_water", 215.0, 0.96, -1.05, 21.0, show_lake_water, 1)
	_build_layer($DistantTreeline, "02_distant_treeline", 210.0, 0.90, -0.5, 16.0, show_distant_treeline, 2)
	_build_layer($SideDeadTrees, "03_side_dead_trees", 205.0, 0.78, -1.0, 25.0, show_side_dead_trees, 3)
	_build_layer($ForegroundReedsBushes, "04_foreground_reeds_bushes", 200.0, 0.60, -1.6, 13.0, show_foreground_reeds, 4)
	if debug_enabled:
		_build_debug()

func _process(_delta: float) -> void:
	if _player == null:
		return
	var movement := _player.global_position - _spawn_player_position
	for data in _layers:
		var node := data.node as Node3D
		node.position = Vector3(movement.x * data.follow_ratio, 0.0, movement.z * data.follow_ratio)

func _build_layer(parent: Node3D, layer: String, radius: float, follow_ratio: float, bottom_y: float, height: float, shown: bool, order: int) -> void:
	parent.visible = shown
	_layers.append({"node": parent, "follow_ratio": follow_ratio})
	if not shown:
		return
	var directory := "res://assets/environment/balkhash_left/runtime/%s" % layer
	var files: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir != null:
		for file in dir.get_files():
			if file.begins_with("tile_") and file.ends_with(".png"):
				files.append(directory + "/" + file)
	files.sort()
	if files.is_empty():
		push_warning("Balkhash runtime tiles missing for " + layer)
		return
	var center := deg_to_rad(sector_yaw_offset_degrees)
	var span := deg_to_rad(sector_arc_degrees) / float(files.size())
	for index in range(files.size()):
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "Tile_%02d" % index
		mesh_node.mesh = ARC.build_tile_arc(radius * global_scale_multiplier, center - deg_to_rad(sector_arc_degrees) * 0.5 + span * index, center - deg_to_rad(sector_arc_degrees) * 0.5 + span * (index + 1), bottom_y + horizon_height_offset, height, 32)
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = LAYER_SHADER
		material.set_shader_parameter("layer_texture", load(files[index]))
		material.set_shader_parameter("fade_left", 1.0 if index == 0 else 0.0)
		material.set_shader_parameter("fade_right", 1.0 if index == files.size() - 1 else 0.0)
		material.set_shader_parameter("red_shadow_strength", 0.18 if order >= 2 else 0.06)
		material.render_priority = order
		mesh_node.material_override = material
		parent.add_child(mesh_node)

func _build_debug() -> void:
	var mesh := ImmediateMesh.new()
	var center := deg_to_rad(sector_yaw_offset_degrees)
	var half_arc := deg_to_rad(sector_arc_degrees * 0.5)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for radius in [200.0, 205.0, 210.0, 215.0, 220.0]:
		for step in range(24):
			var a := center - half_arc + (half_arc * 2.0) * float(step) / 24.0
			var b := center - half_arc + (half_arc * 2.0) * float(step + 1) / 24.0
			mesh.surface_add_vertex(Vector3(sin(a) * radius, 0.12, -cos(a) * radius))
			mesh.surface_add_vertex(Vector3(sin(b) * radius, 0.12, -cos(b) * radius))
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(Vector3(0.0, 0.0, -32.0)) # spawn forward
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(Vector3(-32.0, 0.0, 0.0)) # spawn left
	mesh.surface_end()
	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "SectorDirectionsAndLayerRadii"
	debug_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.08, 0.06, 1.0)
	debug_mesh.material_override = material
	$Debug.add_child(debug_mesh)
