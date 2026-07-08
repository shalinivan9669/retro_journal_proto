extends Node3D

@export var particles: GPUParticles3D
@export var interaction_area: Area3D
@export var cooldown_seconds := 30.0
@export var interact_action := "interact"

var player_inside := false
var disabled := false

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	if particles:
		particles.visible = true
		particles.emitting = true

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
		particles.visible = true
		particles.emitting = true
		particles.restart()
	disabled = false
