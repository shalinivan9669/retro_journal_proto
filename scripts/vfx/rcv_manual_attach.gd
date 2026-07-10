extends Node3D
class_name RCVManualAttach

## Tiny helper for manual editor placement.
## Add this script as a child of an object, choose preset, run the game.

const TARGET_VFX_SCRIPT := preload("res://scripts/vfx/rcv_target_vfx.gd")

@export var preset: RCVTargetVFX.Preset = RCVTargetVFX.Preset.LEP_RADIATION
@export_range(0.2, 18.0, 0.1) var activation_distance: float = 5.0
@export_range(0.0, 2.0, 0.01) var screen_intensity: float = 1.0
@export_range(0.0, 4.0, 0.05) var particle_intensity: float = 1.0

func _ready() -> void:
	if find_child("RCV_ManualRuntime", false, false) != null:
		return
	var vfx := TARGET_VFX_SCRIPT.new() as RCVTargetVFX
	vfx.name = "RCV_ManualRuntime"
	vfx.preset = preset
	vfx.activation_distance = activation_distance
	vfx.screen_intensity = screen_intensity
	vfx.particle_intensity = particle_intensity
	add_child(vfx)
