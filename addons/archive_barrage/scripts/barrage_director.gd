class_name BarrageDirector
extends Node3D

const FX_TIME_SCALE := 0.84
const LOOP_DURATION := 56.0
const SMOKE_TEXTURE := preload(
	"res://addons/archive_barrage/assets/generated/fx/smoke_atlas_4x4_2k.png"
)

var camera: Camera3D
var terrain: BarrageTerrain
var light_pool: DynamicLightPool
var post_process: ArchivePostProcess

var event_time := 0.0
var _schedule: Array[Dictionary] = []
var _next_event := 0
var _trails: Array[BallisticTrail3D] = []
var _trail_pool: Array[BallisticTrail3D] = []
var _smoke_columns: Array[SmokeColumn] = []
var _smoke_pool: Array[SmokeColumn] = []
var _rng := RandomNumberGenerator.new()
var _smoke_texture: Texture2D
var _minor_shot_count := 38
var _maximum_trail_count := 48
var _trail_sample_step := 1.0 / 32.0
var _smoke_sprite_count := 24


func configure(
	view_camera: Camera3D,
	target_terrain: BarrageTerrain,
	target_light_pool: DynamicLightPool,
	target_post_process: ArchivePostProcess,
	use_performance_profile: bool = false
) -> void:
	camera = view_camera
	terrain = target_terrain
	light_pool = target_light_pool
	post_process = target_post_process
	_minor_shot_count = 25 if use_performance_profile else 38
	_maximum_trail_count = 35 if use_performance_profile else 48
	_trail_sample_step = 1.0 / 20.0 if use_performance_profile else 1.0 / 32.0
	_smoke_sprite_count = 12 if use_performance_profile else 24
	_smoke_texture = SMOKE_TEXTURE
	_prewarm_pools()
	_build_schedule()


func _process(delta: float) -> void:
	if camera == null:
		return
	var fx_delta := delta * FX_TIME_SCALE
	event_time += fx_delta

	while _next_event < _schedule.size() and float(_schedule[_next_event]["time"]) <= event_time:
		_spawn_shot(_schedule[_next_event])
		_next_event += 1

	for trail in _trails.duplicate():
		if not is_instance_valid(trail):
			_trails.erase(trail)
			continue
		trail.advance(fx_delta)
		if trail.is_finished():
			trail.recycle()
			_trails.erase(trail)
			_trail_pool.append(trail)

	for smoke in _smoke_columns.duplicate():
		if not is_instance_valid(smoke):
			_smoke_columns.erase(smoke)
			continue
		smoke.advance(fx_delta)
		if smoke.is_finished():
			smoke.recycle()
			_smoke_columns.erase(smoke)
			_smoke_pool.append(smoke)

	light_pool.advance(fx_delta, _trails, camera)
	if event_time >= LOOP_DURATION:
		_reset_loop()


func _build_schedule() -> void:
	_rng.seed = 667
	_schedule.clear()
	var hero_times: Array[float] = [2.8, 4.1, 5.0, 6.25, 7.1, 8.0, 8.8, 9.6, 10.7, 12.0]
	for index in range(hero_times.size()):
		_schedule.append(
			{
				"time": hero_times[index],
				"start_x": (
					lerpf(-210.0, 205.0, float(index) / float(hero_times.size() - 1))
					+ _rng.randf_range(-34.0, 34.0)
				),
				"start_z": _rng.randf_range(-390.0, -185.0),
				"target_x": _rng.randf_range(-330.0, 330.0),
				"target_z": _rng.randf_range(-540.0, -90.0),
				"height": _rng.randf_range(155.0, 270.0),
				"importance": _rng.randf_range(0.78, 1.0),
			}
		)

	for index in range(_minor_shot_count):
		var center := 11.3
		var spread := 5.1
		var gaussian := _rng.randfn(0.0, 1.0)
		var spawn_time := clampf(center + gaussian * spread, 4.6, 21.5)
		_schedule.append(
			{
				"time": spawn_time,
				"start_x": _rng.randf_range(-310.0, 310.0),
				"start_z": _rng.randf_range(-500.0, -150.0),
				"target_x": _rng.randf_range(-430.0, 430.0),
				"target_z": _rng.randf_range(-600.0, -70.0),
				"height": _rng.randf_range(82.0, 190.0),
				"importance": _rng.randf_range(0.24, 0.72),
			}
		)
	_schedule.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"])
	)


func _spawn_shot(data: Dictionary) -> void:
	var start_x := float(data["start_x"])
	var start_z := float(data["start_z"])
	var target_x := float(data["target_x"])
	var target_z := float(data["target_z"])
	var importance := float(data["importance"])
	var start := Vector3(start_x, terrain.height_at_world(start_x, start_z) + 1.0, start_z)
	var target := Vector3(target_x, terrain.height_at_world(target_x, target_z) + 1.0, target_z)
	var apex_height := float(data["height"])
	var visual_gravity := 7.2
	var vertical_speed := sqrt(2.0 * visual_gravity * apex_height)
	var vertical_delta := target.y - start.y
	var descent_discriminant := maxf(
		vertical_speed * vertical_speed - 2.0 * visual_gravity * vertical_delta,
		0.001
	)
	var flight_time := (vertical_speed + sqrt(descent_discriminant)) / visual_gravity
	var horizontal := Vector3(target.x - start.x, 0.0, target.z - start.z) / flight_time
	var velocity := horizontal + Vector3.UP * vertical_speed

	var trail := _acquire_trail()
	trail.sample_step = _trail_sample_step
	trail.configure(
		camera,
		start,
		velocity,
		flight_time,
		lerpf(8.0, 13.0, importance),
		importance,
		float(_rng.randi())
	)
	_trails.append(trail)

	var flash_energy := lerpf(13.0, 31.0, importance)
	light_pool.spawn_launch_flash(start, flash_energy)
	post_process.register_flash(camera, start, flash_energy)

	if importance > 0.46 or _rng.randf() < 0.24:
		var smoke := _acquire_smoke()
		smoke.global_position = start
		smoke.configure(_smoke_texture, importance, _rng.randi(), _smoke_sprite_count)
		_smoke_columns.append(smoke)


func _reset_loop() -> void:
	event_time = 0.0
	_next_event = 0
	for trail in _trails:
		if is_instance_valid(trail):
			trail.recycle()
			_trail_pool.append(trail)
	_trails.clear()


func _prewarm_pools() -> void:
	while _trail_pool.size() + _trails.size() < _maximum_trail_count:
		var trail := BallisticTrail3D.new()
		trail.visible = false
		add_child(trail)
		_trail_pool.append(trail)
	var smoke_reserve := 6 if _smoke_sprite_count <= 12 else 10
	while _smoke_pool.size() + _smoke_columns.size() < smoke_reserve:
		var smoke := SmokeColumn.new()
		smoke.visible = false
		add_child(smoke)
		_smoke_pool.append(smoke)


func _acquire_trail() -> BallisticTrail3D:
	if _trail_pool.is_empty():
		var trail := BallisticTrail3D.new()
		add_child(trail)
		return trail
	return _trail_pool.pop_back()


func _acquire_smoke() -> SmokeColumn:
	if _smoke_pool.is_empty():
		var smoke := SmokeColumn.new()
		add_child(smoke)
		return smoke
	return _smoke_pool.pop_back()
