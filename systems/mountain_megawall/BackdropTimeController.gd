extends Node
class_name BackdropTimeController

@export var target_root_path: NodePath
@export var cycle_duration_sec: float = 240.0
@export var autoplay: bool = false

var _t := 0.0
var _root: MountainMegawallRoot

func _ready() -> void:
	_root = get_node_or_null(target_root_path) as MountainMegawallRoot

func _process(delta: float) -> void:
	if not autoplay or _root == null:
		return
	_t = fmod(_t + delta, cycle_duration_sec)
	var phase := _t / cycle_duration_sec
	# Long day, shorter night, soft transitions.
	var night := smoothstep(0.52, 0.78, phase) * (1.0 - smoothstep(0.92, 1.0, phase))
	_root.set_day_night(night)
