extends Node3D

@export var particles: GPUParticles3D
@export var interaction_area: Area3D
@export var cooldown_seconds := 30.0
@export var interact_action := "interact"
@export var start_active := false

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
	if particles:
		particles.emitting = false
		particles.visible = false
	await get_tree().create_timer(cooldown_seconds).timeout
	if particles:
		particles.visible = start_active
		particles.emitting = start_active
		if start_active:
			particles.restart()
	disabled = false


func shovel_dig(_player: Node = null) -> void:
	if ritual_completed:
		return
	ritual_completed = true
	disabled = true
	start_active = false
	if particles:
		particles.emitting = false
		particles.visible = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("pacify_albasty_from_blood_ritual"):
		game_state.call("pacify_albasty_from_blood_ritual")


func get_interaction_prompt() -> String:
	if ritual_completed:
		return ""
	return "2: лопата, ЛКМ: копать"
