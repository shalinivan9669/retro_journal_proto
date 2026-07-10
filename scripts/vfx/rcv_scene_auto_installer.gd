extends Node
class_name RCVSceneAutoInstaller

## Drop scenes/vfx/RetroContaminationVFXRuntime.tscn into Main.tscn.
## This scanner installs object VFX at runtime without permanently changing imported GLB scenes.

const TARGET_VFX_SCRIPT := preload("res://scripts/vfx/rcv_target_vfx.gd")

@export var auto_install_on_ready: bool = true
@export var scan_root_path: NodePath
@export var install_bed_dream: bool = true
@export var install_tv_glitch: bool = true
@export var install_lep_effects: bool = true
@export var max_beds: int = 4
@export var max_tvs: int = 3
@export var max_leps: int = 12
@export var enable_debug_prints: bool = true

@export_group("Distances")
@export_range(0.2, 12.0, 0.1) var bed_distance: float = 3.4
@export_range(0.2, 12.0, 0.1) var tv_distance: float = 3.0
@export_range(0.2, 18.0, 0.1) var lep_distance: float = 7.5

@export_group("Name Scan Keywords")
@export var bed_keywords := PackedStringArray(["bed", "mattress", "pillow", "blanket", "cot", "sleep", "krovat", "кровать", "матрас", "подушка"])
@export var tv_keywords := PackedStringArray(["interactabletv", "tv", "television", "screen", "monitor", "crt", "телевизор", "экран"])
@export var lep_keywords := PackedStringArray(["lep", "leps", "лэп", "powerline", "power_line", "power-pole", "powerpole", "transmission", "electric_pole", "pole_white", "pylon", "tower_lep"])

@export_group("Groups: optional exact control")
@export var bed_group: StringName = &"vfx_bed_dream"
@export var tv_group: StringName = &"vfx_tv_glitch"
@export var lep_radiation_group: StringName = &"vfx_lep_radiation"
@export var lep_rust_group: StringName = &"vfx_lep_rust"
@export var lep_ion_group: StringName = &"vfx_lep_ion"
@export var lep_dead_signal_group: StringName = &"vfx_lep_dead_signal"

func _ready() -> void:
	if auto_install_on_ready:
		call_deferred("_install_after_scene_settled")

func _install_after_scene_settled() -> void:
	await get_tree().process_frame
	install_all()

func install_all() -> void:
	var root := _get_scan_root()
	if root == null:
		push_warning("RCVSceneAutoInstaller: scan root not found.")
		return

	if install_bed_dream:
		_install_beds(root)
	if install_tv_glitch:
		_install_tvs(root)
	if install_lep_effects:
		_install_leps(root)

func _get_scan_root() -> Node:
	if scan_root_path != NodePath(""):
		var custom_root := get_node_or_null(scan_root_path)
		if custom_root != null:
			return custom_root
	return get_tree().current_scene

func _install_beds(root: Node) -> void:
	var targets := _unique_node3d(_collect_group_nodes(bed_group))
	if targets.is_empty():
		targets = _find_nodes_by_keywords(root, bed_keywords)
	targets = _unique_node3d(targets)
	var count := 0
	for target in targets:
		if count >= max_beds:
			break
		if _has_vfx_child(target, "RCV_BedDream"):
			continue
		_attach_vfx(target, RCVTargetVFX.Preset.BED_DREAM, "RCV_BedDream", bed_distance, 1.0, 2.75)
		count += 1
	if count == 0:
		push_warning("RCVSceneAutoInstaller: no bed_dream target found.")
	_log("bed dream targets installed: %d" % count)

func _install_tvs(root: Node) -> void:
	var targets := _unique_node3d(_collect_group_nodes(tv_group))
	if targets.is_empty():
		targets = _find_nodes_by_keywords(root, tv_keywords)
	targets = _unique_node3d(targets)
	var count := 0
	for target in targets:
		if count >= max_tvs:
			break
		if _has_vfx_child(target, "RCV_TVGlitch"):
			continue
		_attach_vfx(target, RCVTargetVFX.Preset.TV_GLITCH, "RCV_TVGlitch", tv_distance, 1.12, 0.8)
		count += 1
	if count == 0:
		push_warning("RCVSceneAutoInstaller: no tv_glitch target found.")
	_log("tv glitch targets installed: %d" % count)

func _install_leps(root: Node) -> void:
	var explicit_radiation := _unique_node3d(_collect_group_nodes(lep_radiation_group))
	var explicit_rust := _unique_node3d(_collect_group_nodes(lep_rust_group))
	var explicit_ion := _unique_node3d(_collect_group_nodes(lep_ion_group))
	var explicit_dead := _unique_node3d(_collect_group_nodes(lep_dead_signal_group))

	var explicit_count := 0
	for target in explicit_radiation:
		explicit_count += _attach_if_missing(target, RCVTargetVFX.Preset.LEP_RADIATION, "RCV_LEPRadiation", lep_distance, 1.15, 2.35)
	for target in explicit_rust:
		explicit_count += _attach_if_missing(target, RCVTargetVFX.Preset.LEP_RUST, "RCV_LEPRust", lep_distance * 0.82, 0.0, 1.85)
	for target in explicit_ion:
		explicit_count += _attach_if_missing(target, RCVTargetVFX.Preset.LEP_ION_WHITE, "RCV_LEPWhiteIon", lep_distance * 0.86, 0.0, 2.15)
	for target in explicit_dead:
		explicit_count += _attach_if_missing(target, RCVTargetVFX.Preset.LEP_DEAD_SIGNAL, "RCV_LEPDeadSignal", lep_distance * 0.72, 0.65, 0.7)

	if explicit_count > 0:
		_log("lep explicit installed: %d; name-scan skipped because explicit groups were found" % explicit_count)
		return

	var discovered := _find_nodes_by_keywords(root, lep_keywords)
	discovered = _unique_node3d(discovered)
	var installed := 0
	for target in discovered:
		if installed >= max_leps:
			break
		if _has_any_rcv_child(target):
			continue
		var preset := RCVTargetVFX.Preset.LEP_RADIATION
		var child_name := "RCV_LEPRadiation"
		var screen_power := 1.0
		var particle_power := 1.0
		var dist := lep_distance
		var slot := installed % 3
		if slot == 1:
			preset = RCVTargetVFX.Preset.LEP_RUST
			child_name = "RCV_LEPRust"
			screen_power = 0.0
			particle_power = 0.82
			dist = lep_distance * 0.82
		elif slot == 2:
			preset = RCVTargetVFX.Preset.LEP_ION_WHITE
			child_name = "RCV_LEPWhiteIon"
			screen_power = 0.0
			particle_power = 1.0
			dist = lep_distance * 0.86
		_attach_vfx(target, preset, child_name, dist, screen_power, particle_power)
		installed += 1

	if installed == 0:
		push_warning("RCVSceneAutoInstaller: no LEP targets found.")
	_log("lep explicit installed: %d; lep name-scan installed: %d" % [explicit_count, installed])

func _attach_if_missing(target: Node3D, preset: int, child_name: String, distance: float, screen_power: float, particle_power: float) -> int:
	if target == null:
		return 0
	if _has_vfx_child(target, child_name):
		return 0
	_attach_vfx(target, preset, child_name, distance, screen_power, particle_power)
	return 1

func _attach_vfx(target: Node3D, preset: int, child_name: String, distance: float, screen_power: float, particle_power: float) -> void:
	if target == null:
		return
	var vfx := TARGET_VFX_SCRIPT.new() as RCVTargetVFX
	vfx.name = child_name
	vfx.preset = preset
	vfx.activation_distance = distance
	vfx.screen_intensity = screen_power
	vfx.particle_intensity = particle_power
	vfx.enable_debug_prints = false
	target.add_child(vfx)

func _collect_group_nodes(group_name: StringName) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D:
			result.append(node as Node3D)
	return result

func _find_nodes_by_keywords(root: Node, keywords: PackedStringArray) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if root == null:
		return result
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is Node3D:
			var lower: String = String(node.name).to_lower()
			for keyword in keywords:
				var k := String(keyword).to_lower()
				if k != "" and lower.contains(k):
					result.append(node as Node3D)
					break
		for child in node.get_children():
			stack.append(child)
	return result

func _unique_node3d(nodes: Array[Node3D]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var seen := {}
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		result.append(node)
	return result

func _has_vfx_child(target: Node, child_name: String) -> bool:
	return target != null and target.find_child(child_name, false, false) != null

func _has_any_rcv_child(target: Node) -> bool:
	if target == null:
		return false
	for child in target.get_children():
		if String(child.name).begins_with("RCV_"):
			return true
	return false

func _log(message: String) -> void:
	if enable_debug_prints:
		print("RCVSceneAutoInstaller: ", message)
