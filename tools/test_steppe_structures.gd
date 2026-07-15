extends Node

const CINEMATIC_SCENE := preload(
	"res://addons/archive_barrage/scenes/ArchiveNightBarrage.tscn"
)
const PERFORMANCE_SCENE := preload(
	"res://addons/archive_barrage/scenes/ArchiveNightBarragePerformance.tscn"
)
const PLAYER_XZ := Vector2(0.0, 92.0)
const HERO_TARGET_XZ := Vector2(-49.32, 150.87)
const BARRAGE_MAX_Z := -70.0

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _verify_profile(CINEMATIC_SCENE, "Cinematic")
	await _verify_profile(PERFORMANCE_SCENE, "Performance")
	if _failures == 0:
		print("STEPPE_STRUCTURES_TEST_PASS profiles=2 entrances=2")
	get_tree().quit(1 if _failures > 0 else 0)


func _verify_profile(scene: PackedScene, profile_name: String) -> void:
	var barrage := scene.instantiate() as Node3D
	add_child(barrage)
	for _frame in range(3):
		await get_tree().process_frame
		await get_tree().physics_frame
	barrage.process_mode = Node.PROCESS_MODE_DISABLED

	var structures := barrage.get_node_or_null("SteppeStructures") as Node3D
	_check(structures != null, "%s missing SteppeStructures" % profile_name)
	if structures != null:
		_check_entrance(
			structures,
			"EastCaveEntrance",
			Vector2(72.0, -12.0),
			profile_name
		)
		_check_entrance(
			structures,
			"WestCollapsedTunnelEntrance",
			Vector2(-158.0, -18.0),
			profile_name
		)
		_check(
			structures.has_meta(&"deterministic_seed")
			and int(structures.get_meta(&"deterministic_seed")) == 1847,
			"%s deterministic seed metadata mismatch" % profile_name
		)

	barrage.queue_free()
	await get_tree().process_frame


func _check_entrance(
	structures: Node3D,
	entrance_name: String,
	expected_xz: Vector2,
	profile_name: String
) -> void:
	var entrance := structures.get_node_or_null(entrance_name) as Node3D
	_check(entrance != null, "%s missing %s" % [profile_name, entrance_name])
	if entrance == null:
		return
	var actual_xz := Vector2(entrance.global_position.x, entrance.global_position.z)
	_check(
		actual_xz.distance_to(expected_xz) < 0.05,
		"%s %s XZ mismatch: %s" % [profile_name, entrance_name, actual_xz]
	)
	_check(
		actual_xz.distance_to(PLAYER_XZ) > 100.0,
		"%s %s is too close to player start" % [profile_name, entrance_name]
	)
	_check(
		actual_xz.distance_to(HERO_TARGET_XZ) > 190.0,
		"%s %s is too close to HorseHillTarget" % [profile_name, entrance_name]
	)
	_check(
		actual_xz.y > BARRAGE_MAX_Z + 40.0,
		"%s %s encroaches on barrage Z corridor" % [profile_name, entrance_name]
	)

	var required_children := [
		"RockPortalExterior",
		"TunnelPassageVolume/LeftInteriorWall",
		"TunnelPassageVolume/RightInteriorWall",
		"TunnelPassageVolume/InteriorCeiling",
		"TunnelPassageVolume/DeepTunnelShadow",
		"ReadableStonePortalRim/StoneArchBand",
		"TunnelStructureCollision/TunnelBackCollision",
	]
	for child_path in required_children:
		_check(
			entrance.get_node_or_null(child_path) != null,
			"%s %s missing %s" % [profile_name, entrance_name, child_path]
		)
	var shadow := entrance.get_node_or_null(
		"TunnelPassageVolume/DeepTunnelShadow"
	) as MeshInstance3D
	_check(
		shadow != null and shadow.mesh is ArrayMesh,
		"%s %s lacks ArrayMesh deep passage" % [profile_name, entrance_name]
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("STEPPE_STRUCTURES_TEST_FAIL: %s" % message)
