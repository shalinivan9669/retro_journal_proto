class_name SteppeStructureBuilder
extends Node3D

## Deterministic, low-cost landmarks that need real silhouette and interior
## volume rather than another height-field bump. Both entrances stay north of
## the barrage endpoint corridor (all scheduled launch/impact Z values <= -70).

const EAST_CAVE_XZ := Vector2(72.0, -12.0)
const WEST_TUNNEL_XZ := Vector2(-158.0, -18.0)
const DETERMINISTIC_SEED := 1847

const CAVE_ROCK_SCENE := preload(
	"res://assets/lost_signal/forest/kenney_nature/cliff_cave_rock.glb"
)
const BLOCK_CAVE_ROCK_SCENE := preload(
	"res://assets/lost_signal/forest/kenney_nature/cliff_blockCave_rock.glb"
)

var terrain: BarrageTerrain
var _performance_mode := false
var _player_origin := Vector3(0.0, 0.0, 92.0)
var _rng := RandomNumberGenerator.new()
var _earth_material: StandardMaterial3D
var _rock_material: StandardMaterial3D
var _rim_material: StandardMaterial3D
var _interior_material: StandardMaterial3D
var _timber_material: StandardMaterial3D


func build(
	target_terrain: BarrageTerrain,
	use_performance_profile: bool = false,
	player_origin: Vector3 = Vector3(0.0, 0.0, 92.0)
) -> void:
	if terrain != null or target_terrain == null:
		return
	terrain = target_terrain
	_performance_mode = use_performance_profile
	_player_origin = player_origin
	_rng.seed = DETERMINISTIC_SEED
	set_meta(&"deterministic_seed", DETERMINISTIC_SEED)
	set_meta(&"barrage_safe_min_z", -70.0)
	_create_materials()

	_build_tunnel_entrance(
		&"EastCaveEntrance",
		EAST_CAVE_XZ,
		CAVE_ROCK_SCENE,
		Vector3(18.0, 7.0, 8.0),
		false
	)
	_build_tunnel_entrance(
		&"WestCollapsedTunnelEntrance",
		WEST_TUNNEL_XZ,
		BLOCK_CAVE_ROCK_SCENE,
		Vector3(19.0, 7.2, 9.0),
		true
	)


func get_landmark_world_xz() -> Dictionary:
	return {
		&"EastCaveEntrance": EAST_CAVE_XZ,
		&"WestCollapsedTunnelEntrance": WEST_TUNNEL_XZ,
	}


func _create_materials() -> void:
	_earth_material = StandardMaterial3D.new()
	_earth_material.albedo_color = Color(0.19, 0.172, 0.148)
	_earth_material.roughness = 1.0
	_earth_material.emission_enabled = true
	_earth_material.emission = Color(0.0045, 0.0050, 0.0060)

	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = Color(0.31, 0.30, 0.285)
	_rock_material.roughness = 0.96
	_rock_material.emission_enabled = true
	_rock_material.emission = Color(0.022, 0.024, 0.028)
	_rock_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Pale fractured faces catch enough of the monochrome night treatment to
	# make the entrance readable without adding another real-time light.
	_rim_material = StandardMaterial3D.new()
	_rim_material.albedo_color = Color(0.12, 0.13, 0.15)
	_rim_material.roughness = 1.0
	_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_interior_material = StandardMaterial3D.new()
	_interior_material.albedo_color = Color(0.0025, 0.0035, 0.0055)
	_interior_material.roughness = 1.0
	_interior_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_interior_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_timber_material = StandardMaterial3D.new()
	_timber_material.albedo_color = Color(0.065, 0.052, 0.039)
	_timber_material.roughness = 0.94


func _build_tunnel_entrance(
	landmark_name: StringName,
	world_xz: Vector2,
	exterior_scene: PackedScene,
	exterior_scale: Vector3,
	with_timber_supports: bool
) -> void:
	var ground_y := terrain.height_at_world(world_xz.x, world_xz.y)
	var up := terrain.normal_at_world(world_xz.x, world_xz.y, 1.5).normalized()
	var toward_player := _player_origin - Vector3(world_xz.x, ground_y, world_xz.y)
	toward_player -= up * toward_player.dot(up)
	if toward_player.length_squared() <= 0.0001:
		toward_player = Vector3(0.0, 0.0, 1.0)
	var forward := toward_player.normalized()
	var right := up.cross(forward).normalized()

	var landmark := Node3D.new()
	landmark.name = landmark_name
	add_child(landmark)
	landmark.global_transform = Transform3D(
		Basis(right, up, forward).orthonormalized(),
		Vector3(world_xz.x, ground_y + 0.45, world_xz.y)
	)
	landmark.set_meta(&"world_xz", world_xz)
	landmark.set_meta(&"distance_from_player_m", Vector2(
		_player_origin.x,
		_player_origin.z
	).distance_to(world_xz))

	var exterior := exterior_scene.instantiate() as Node3D
	exterior.name = "RockPortalExterior"
	exterior.position = Vector3(0.0, 0.0, -1.35)
	exterior.scale = exterior_scale
	landmark.add_child(exterior)
	_override_geometry_material(exterior, _rock_material)

	_add_earth_shoulders(landmark)
	_add_passage_volume(landmark)
	_add_portal_rim(landmark)
	_add_collision_volume(landmark)
	_add_rubble(landmark, 5 if _performance_mode else 9)
	if with_timber_supports:
		_add_timber_frame(landmark)


func _override_geometry_material(node: Node, material: Material) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.material_override = material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_override_geometry_material(child, material)


func _add_earth_shoulders(parent: Node3D) -> void:
	_add_ellipsoid(
		parent,
		"LeftEarthShoulder",
		Vector3(-7.9, 1.45, -1.8),
		Vector3(5.9, 3.15, 6.2)
	)
	_add_ellipsoid(
		parent,
		"RightEarthShoulder",
		Vector3(7.9, 1.35, -1.6),
		Vector3(5.8, 3.05, 6.1)
	)
	_add_ellipsoid(
		parent,
		"EarthCrown",
		Vector3(0.0, 6.4, -2.3),
		Vector3(10.5, 2.35, 6.2)
	)


func _add_ellipsoid(
	parent: Node3D,
	node_name: String,
	local_position: Vector3,
	local_scale: Vector3
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12 if _performance_mode else 18
	sphere.rings = 6 if _performance_mode else 9
	instance.mesh = sphere
	instance.material_override = _earth_material
	instance.position = local_position
	instance.scale = local_scale
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)


func _add_passage_volume(parent: Node3D) -> void:
	var passage := Node3D.new()
	passage.name = "TunnelPassageVolume"
	parent.add_child(passage)

	# The front is left genuinely open. Four separate surfaces form a hollow,
	# walk-in passage; the only black panel is 10 m behind the visible portal.
	_add_box(
		passage,
		"LeftInteriorWall",
		Vector3(0.55, 4.15, 10.8),
		Vector3(-3.55, 2.05, -1.0),
		_interior_material
	)
	_add_box(
		passage,
		"RightInteriorWall",
		Vector3(0.55, 4.15, 10.8),
		Vector3(3.55, 2.05, -1.0),
		_interior_material
	)
	_add_box(
		passage,
		"InteriorCeiling",
		Vector3(7.65, 0.55, 10.8),
		Vector3(0.0, 4.12, -1.0),
		_interior_material
	)
	_add_box(
		passage,
		"InteriorFloor",
		Vector3(7.2, 0.10, 10.8),
		Vector3(0.0, 0.03, -1.0),
		_interior_material
	)

	var deep_shadow := MeshInstance3D.new()
	deep_shadow.name = "DeepTunnelShadow"
	deep_shadow.mesh = _create_deep_shadow_mesh(7.2, 4.15)
	deep_shadow.material_override = _interior_material
	deep_shadow.position = Vector3(0.0, 0.0, -6.42)
	deep_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	passage.add_child(deep_shadow)


func _add_portal_rim(parent: Node3D) -> void:
	var rim := Node3D.new()
	rim.name = "ReadableStonePortalRim"
	parent.add_child(rim)
	_add_box(
		rim,
		"LeftPortalPier",
		Vector3(1.20, 4.25, 1.0),
		Vector3(-4.15, 2.05, 4.72),
		_rim_material,
		Vector3(0.0, 0.0, deg_to_rad(-4.0))
	)
	_add_box(
		rim,
		"RightPortalPier",
		Vector3(1.20, 4.25, 1.0),
		Vector3(4.15, 2.05, 4.72),
		_rim_material,
		Vector3(0.0, 0.0, deg_to_rad(3.0))
	)
	var arch := MeshInstance3D.new()
	arch.name = "StoneArchBand"
	arch.mesh = _create_arch_band_mesh()
	arch.material_override = _rim_material
	arch.position.z = 4.78
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rim.add_child(arch)


func _create_arch_band_mesh() -> ArrayMesh:
	const SEGMENTS := 12
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment in range(SEGMENTS + 1):
		var ratio := float(segment) / float(SEGMENTS)
		var angle := ratio * PI
		vertices.append(Vector3(cos(angle) * 4.75, 2.0 + sin(angle) * 3.65, 0.0))
		vertices.append(Vector3(cos(angle) * 3.55, 2.25 + sin(angle) * 2.45, 0.0))
		normals.append(Vector3.FORWARD)
		normals.append(Vector3.FORWARD)
		uvs.append(Vector2(ratio, 0.0))
		uvs.append(Vector2(ratio, 1.0))
		if segment < SEGMENTS:
			var vertex_index := segment * 2
			indices.append_array(PackedInt32Array([
				vertex_index,
				vertex_index + 2,
				vertex_index + 1,
				vertex_index + 2,
				vertex_index + 3,
				vertex_index + 1,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _create_deep_shadow_mesh(width: float, height: float) -> ArrayMesh:
	var half_width := width * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width, 0.0, 0.0),
		Vector3(half_width, 0.0, 0.0),
		Vector3(half_width, height, 0.0),
		Vector3(-half_width, height, 0.0),
	])
	var normals := PackedVector3Array([
		Vector3.FORWARD,
		Vector3.FORWARD,
		Vector3.FORWARD,
		Vector3.FORWARD,
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _add_collision_volume(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "TunnelStructureCollision"
	parent.add_child(body)
	_add_collision_box(
		body,
		"LeftPassageCollision",
		Vector3(1.1, 4.8, 11.5),
		Vector3(-4.25, 2.2, -1.0)
	)
	_add_collision_box(
		body,
		"RightPassageCollision",
		Vector3(1.1, 4.8, 11.5),
		Vector3(4.25, 2.2, -1.0)
	)
	_add_collision_box(
		body,
		"CrownCollision",
		Vector3(9.0, 2.0, 8.0),
		Vector3(0.0, 5.25, -1.6)
	)
	_add_collision_box(
		body,
		"TunnelBackCollision",
		Vector3(7.3, 4.2, 0.45),
		Vector3(0.0, 2.0, -6.55)
	)


func _add_collision_box(
	parent: StaticBody3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3
) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = local_position
	parent.add_child(collision)


func _add_rubble(parent: Node3D, rubble_count: int) -> void:
	var rubble_root := Node3D.new()
	rubble_root.name = "EntranceRubble"
	parent.add_child(rubble_root)
	var unit_block := BoxMesh.new()
	unit_block.size = Vector3.ONE
	for index in range(rubble_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var rubble := MeshInstance3D.new()
		rubble.name = "Rubble_%02d" % index
		rubble.mesh = unit_block
		rubble.material_override = _rock_material
		rubble.position = Vector3(
			side * _rng.randf_range(4.2, 10.5),
			_rng.randf_range(0.15, 0.55),
			_rng.randf_range(3.2, 5.2)
		)
		rubble.scale = Vector3(
			_rng.randf_range(0.65, 1.9),
			_rng.randf_range(0.45, 1.25),
			_rng.randf_range(0.55, 1.6)
		)
		rubble.rotation = Vector3(
			_rng.randf_range(-0.22, 0.22),
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-0.25, 0.25)
		)
		rubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rubble_root.add_child(rubble)


func _add_timber_frame(parent: Node3D) -> void:
	var frame := Node3D.new()
	frame.name = "CollapsedTimberSupport"
	parent.add_child(frame)
	_add_box(
		frame,
		"LeftPost",
		Vector3(0.42, 4.35, 0.50),
		Vector3(-3.55, 2.15, 4.48),
		_timber_material,
		Vector3(0.0, 0.0, deg_to_rad(-3.5))
	)
	_add_box(
		frame,
		"RightPost",
		Vector3(0.42, 4.05, 0.50),
		Vector3(3.55, 2.0, 4.48),
		_timber_material,
		Vector3(0.0, 0.0, deg_to_rad(4.5))
	)
	_add_box(
		frame,
		"Lintel",
		Vector3(7.75, 0.46, 0.58),
		Vector3(0.0, 4.2, 4.46),
		_timber_material,
		Vector3(0.0, 0.0, deg_to_rad(-2.0))
	)


func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	material: Material,
	local_rotation: Vector3 = Vector3.ZERO
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = local_position
	instance.rotation = local_rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
