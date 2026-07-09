extends Node3D
class_name MountainMicroEventController


const EVENT_KIND := {
	"tiny_light_pulse": 0,
	"distant_storm_flash": 1,
	"industrial_flash": 2,
	"aircraft_blink": 3,
	"avalanche_drift": 4,
	"snow_drift": 4,
}

@export var enable_events: bool = true
@export var min_interval_sec: float = 45.0
@export var max_interval_sec: float = 180.0
@export_range(1, 2, 1) var max_simultaneous_events: int = 1
@export_range(0.0, 1.0, 0.01) var day_night_threshold: float = 0.45
@export var event_radius: float = 342.0
@export var center_yaw_degrees: float = 90.0

var day_night: float = 0.0
var _timer := 0.0
var _active := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_reset_timer()


func _process(delta: float) -> void:
	if not enable_events or day_night < day_night_threshold:
		return

	_timer -= delta
	if _timer <= 0.0 and _active < max_simultaneous_events:
		_spawn_random_event()
		_reset_timer()


func debug_force_event(event_name: String = "industrial_flash") -> void:
	_spawn_event(event_name)


func _reset_timer() -> void:
	_timer = _rng.randf_range(min_interval_sec, max_interval_sec)


func _spawn_random_event() -> void:
	var events := [
		"tiny_light_pulse",
		"distant_storm_flash",
		"industrial_flash",
		"aircraft_blink",
		"avalanche_drift",
	]
	_spawn_event(events[_rng.randi_range(0, events.size() - 1)])


func _spawn_event(event_name: String) -> void:
	_active += 1
	var kind := int(EVENT_KIND.get(event_name, EVENT_KIND["industrial_flash"]))
	var quad := MeshInstance3D.new()
	quad.name = "DistantEvent_%s" % event_name

	var mesh := QuadMesh.new()
	var duration := _rng.randf_range(4.0, 14.0)
	var intensity := _rng.randf_range(0.08, 0.28)
	var event_color := Color(0.52, 0.68, 0.94, 1.0)

	match kind:
		0:
			mesh.size = Vector2(_rng.randf_range(1.0, 2.4), _rng.randf_range(0.7, 1.4))
			duration = _rng.randf_range(5.0, 11.0)
			intensity = _rng.randf_range(0.06, 0.14)
			event_color = Color(0.75, 0.82, 0.72, 1.0)
		1:
			mesh.size = Vector2(_rng.randf_range(22.0, 42.0), _rng.randf_range(18.0, 34.0))
			duration = _rng.randf_range(2.2, 4.4)
			intensity = _rng.randf_range(0.10, 0.22)
			event_color = Color(0.45, 0.58, 0.95, 1.0)
		2:
			mesh.size = Vector2(_rng.randf_range(3.0, 7.0), _rng.randf_range(1.5, 3.5))
			duration = _rng.randf_range(4.0, 8.0)
			intensity = _rng.randf_range(0.09, 0.18)
			event_color = Color(0.58, 0.70, 0.86, 1.0)
		3:
			mesh.size = Vector2(1.4, 1.4)
			duration = _rng.randf_range(9.0, 16.0)
			intensity = _rng.randf_range(0.08, 0.16)
			event_color = Color(0.75, 0.70, 0.58, 1.0)
		4:
			mesh.size = Vector2(_rng.randf_range(32.0, 66.0), _rng.randf_range(7.0, 15.0))
			duration = _rng.randf_range(10.0, 18.0)
			intensity = _rng.randf_range(0.035, 0.08)
			event_color = Color(0.62, 0.68, 0.70, 1.0)

	quad.mesh = mesh

	var yaw := deg_to_rad(center_yaw_degrees + _rng.randf_range(-36.0, 36.0))
	var event_y := _rng.randf_range(42.0, 210.0)
	if kind == 0 or kind == 2:
		event_y = _rng.randf_range(18.0, 62.0)
	elif kind == 3:
		event_y = _rng.randf_range(145.0, 250.0)
	elif kind == 4:
		event_y = _rng.randf_range(82.0, 160.0)

	quad.position = Vector3(sin(yaw) * event_radius, event_y, cos(yaw) * event_radius)
	quad.rotation.y = yaw + PI

	var mat := ShaderMaterial.new()
	mat.shader = load("res://systems/mountain_megawall/shaders/mountain_event_emission.gdshader")
	mat.set_shader_parameter("event_kind", kind)
	mat.set_shader_parameter("start_time", Time.get_ticks_msec() * 0.001)
	mat.set_shader_parameter("duration", duration)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("event_color", event_color)
	quad.material_override = mat
	add_child(quad)

	await get_tree().create_timer(duration + 0.5).timeout
	if is_instance_valid(quad):
		quad.queue_free()
	_active = maxi(0, _active - 1)
