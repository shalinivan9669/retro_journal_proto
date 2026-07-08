extends Node

@export var sky_material: ShaderMaterial
@export var storm_light: DirectionalLight3D
@export var min_delay := 5.0
@export var max_delay := 15.0
@export var flash_chance := 0.35
@export var flash_energy := 2.3
@export var normal_light_energy := 0.45

var timer := 0.0

func _ready() -> void:
	timer = randf_range(min_delay, max_delay)

func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = randf_range(min_delay, max_delay)
	if randf() <= flash_chance:
		_flash()

func _flash() -> void:
	if sky_material:
		sky_material.set_shader_parameter("lightning_flash", 1.0)
	if storm_light:
		storm_light.light_energy = flash_energy
	await get_tree().create_timer(0.075).timeout
	if sky_material:
		sky_material.set_shader_parameter("lightning_flash", 0.0)
	if storm_light:
		storm_light.light_energy = normal_light_energy
