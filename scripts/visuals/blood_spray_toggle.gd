extends Node3D

@export var particles: GPUParticles3D
@export var interaction_area: Area3D
@export var cooldown_seconds := 30.0
@export var shovel_ritual_duration_seconds := 600.0
@export var interact_action := "interact"
@export var start_active := false
@export var blood_visual_nodes: Array[NodePath] = []

var player_inside := false
var disabled := false
var ritual_completed := false

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	if particles:
		particles.visible = start_active
		particles.emitting = start_active

func _process(_delta: float) -> void:
	if player_inside and not disabled and Input.is_action_just_pressed(interact_action):
		_stop_temporarily()

func _on_body_entered(body: Node) -> void:
	if body.name.to_lower().contains("player") or body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.name.to_lower().contains("player") or body.is_in_group("player"):
		player_inside = false

func _stop_temporarily() -> void:
	disabled = true
	_set_blood_active(false)
	await get_tree().create_timer(cooldown_seconds).timeout
	_set_blood_active(start_active)
	disabled = false


func shovel_dig(_player: Node = null) -> void:
	if ritual_completed:
		return
	ritual_completed = true
	disabled = true
	_set_blood_active(false)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("pacify_albasty_from_blood_ritual"):
		game_state.call("pacify_albasty_from_blood_ritual")
	await get_tree().create_timer(shovel_ritual_duration_seconds).timeout
	_set_blood_active(start_active)
	ritual_completed = false
	disabled = false


func _set_blood_active(active: bool) -> void:
	if particles:
		particles.emitting = active
		particles.visible = active
		particles.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		if active:
			particles.restart()
		else:
			# Stop and clear already spawned droplets immediately; disabling
			# emission alone would leave existing particles frozen on screen.
			particles.restart()
	for node in find_children("*", "GPUParticles3D", true, false):
		var extra_particles := node as GPUParticles3D
		if extra_particles == particles:
			continue
		extra_particles.emitting = active
		extra_particles.visible = active
		extra_particles.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		if not active:
			extra_particles.restart()
	for path in blood_visual_nodes:
		var visual := get_node_or_null(path)
		if visual is VisualInstance3D:
			(visual as VisualInstance3D).visible = active


func get_interaction_prompt() -> String:
	if ritual_completed:
		return ""
	return "2: лопата, ЛКМ: копать"
