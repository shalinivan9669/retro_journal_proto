extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/Main.tscn") as PackedScene
	var main := scene.instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	var blood := main.get_node_or_null("BloodSprayPlaceholder")
	var particles := main.get_node_or_null("BloodSprayPlaceholder/BloodParticles") as GPUParticles3D
	var puddle := main.get_node_or_null("BullHeadBloodPuddle") as MeshInstance3D
	var glow := main.get_node_or_null("BullHeadBloodGlow") as OmniLight3D
	var spawner := main.get_node_or_null("SteppeEnvironment/AlbastyHorsePrototype/AlbastySpawner")
	var bull_head := main.get_node_or_null("BleedingBullHead") as Node3D
	if blood == null or particles == null or puddle == null or glow == null or spawner == null or bull_head == null:
		_fail("Required ritual nodes are missing")
		return

	await process_frame
	spawner.call("spawn_albasty")
	blood.call("shovel_dig")
	var game_state := root.get_node_or_null("/root/GameState")
	var hidden := game_state != null and bool(game_state.call("is_albasty_hidden_by_ritual"))
	var bull_scale := bull_head.transform.basis.get_scale()
	print("[RitualCheck] particles_visible=", particles.visible, " emitting=", particles.emitting, " puddle=", puddle.visible, " glow=", glow.visible, " albasty_hidden=", hidden, " bull_scale=", bull_scale)
	if particles.visible or particles.emitting or puddle.visible or glow.visible or not hidden or not is_equal_approx(bull_scale.y, 10.8):
		_fail("Shovel ritual state validation failed")
		return
	await process_frame
	if not get_nodes_in_group("albasty").is_empty():
		_fail("Albasty was not removed by shovel ritual")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
