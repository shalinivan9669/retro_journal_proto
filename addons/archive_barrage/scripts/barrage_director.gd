class_name BarrageDirector
extends Node3D

const FX_TIME_SCALE := 0.84
const LOOP_DURATION := 56.0
const SMOKE_TEXTURE := preload(
	"res://addons/archive_barrage/assets/generated/fx/smoke_atlas_4x4_2k.png"
)
const FLASH_TEXTURE := preload(
	"res://addons/archive_barrage/assets/generated/fx/flash_radial_1k.png"
)
const DIRT_SPRAY_SCRIPT := preload(
	"res://addons/archive_barrage/scripts/barrage_dirt_spray.gd"
)
const SLOWMO_HOLD_SECONDS := 0.30
const SLOWMO_RECOVERY_SECONDS := 1.25
const SLOWMO_COOLDOWN_MSEC := 1800

var camera: Camera3D
var player: CharacterBody3D
var terrain: BarrageTerrain
var light_pool: DynamicLightPool
var post_process: ArchivePostProcess
var environment_props: EnvironmentPropBuilder
var audio_director: BarrageAudioDirector

var event_time := 0.0
var _schedule: Array[Dictionary] = []
var _next_event := 0
var _trails: Array[BallisticTrail3D] = []
var _trail_pool: Array[BallisticTrail3D] = []
var _smoke_columns: Array[SmokeColumn] = []
var _smoke_pool: Array[SmokeColumn] = []
var _bursts: Array[BarrageFlashBurst] = []
var _burst_pool: Array[BarrageFlashBurst] = []
var _dirt_sprays: Array = []
var _dirt_spray_pool: Array = []
var _rng := RandomNumberGenerator.new()
var _smoke_texture: Texture2D
var _minor_shot_count := 38
var _maximum_trail_count := 48
var _trail_sample_step := 1.0 / 32.0
var _smoke_sprite_count := 24
var _performance_mode := false
var _distant_schedule: Array[Dictionary] = []
var _next_distant_event := 0
var _previous_time_scale := 1.0
var _base_mouse_sensitivity := 0.0025
var _slowmo_active := false
var _slowmo_started_msec := 0
var _slowmo_cooldown_until_msec := 0
var _slowmo_strength := 0.0
var _configured := false


func configure(
	view_camera: Camera3D,
	view_player: CharacterBody3D,
	target_terrain: BarrageTerrain,
	target_light_pool: DynamicLightPool,
	target_post_process: ArchivePostProcess,
	target_environment_props: EnvironmentPropBuilder,
	target_audio_director: BarrageAudioDirector,
	use_performance_profile: bool = false
) -> void:
	camera = view_camera
	player = view_player
	terrain = target_terrain
	light_pool = target_light_pool
	post_process = target_post_process
	environment_props = target_environment_props
	audio_director = target_audio_director
	_performance_mode = use_performance_profile
	_minor_shot_count = 25 if use_performance_profile else 38
	_maximum_trail_count = 35 if use_performance_profile else 48
	_trail_sample_step = 1.0 / 20.0 if use_performance_profile else 1.0 / 32.0
	_smoke_sprite_count = 12 if use_performance_profile else 24
	_smoke_texture = SMOKE_TEXTURE
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 1.0
	if player != null:
		_base_mouse_sensitivity = float(player.get("mouse_sensitivity"))
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prewarm_pools()
	_build_schedule()
	_build_distant_schedule()
	_configured = true


func _exit_tree() -> void:
	_restore_time_state()


func _process(delta: float) -> void:
	if camera == null:
		return
	_update_slow_motion()
	var fx_delta := delta * FX_TIME_SCALE
	event_time += fx_delta

	while _next_event < _schedule.size() and float(_schedule[_next_event]["time"]) <= event_time:
		_spawn_shot(_schedule[_next_event])
		_next_event += 1
	while (
		_next_distant_event < _distant_schedule.size()
		and float(_distant_schedule[_next_distant_event]["time"]) <= event_time
	):
		_spawn_distant_event(_distant_schedule[_next_distant_event])
		_next_distant_event += 1

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

	for burst in _bursts.duplicate():
		if not is_instance_valid(burst):
			_bursts.erase(burst)
			continue
		burst.advance(fx_delta)
		if burst.is_finished():
			burst.recycle()
			_bursts.erase(burst)
			_burst_pool.append(burst)

	for dirt_spray in _dirt_sprays.duplicate():
		if not is_instance_valid(dirt_spray):
			_dirt_sprays.erase(dirt_spray)
			continue
		dirt_spray.advance(fx_delta)
		if dirt_spray.is_finished():
			dirt_spray.recycle()
			_dirt_sprays.erase(dirt_spray)
			_dirt_spray_pool.append(dirt_spray)

	light_pool.advance(fx_delta, _trails, camera)
	if environment_props != null:
		environment_props.set_flash_response(light_pool.atmospheric_flash_level())
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


func _build_distant_schedule() -> void:
	_distant_schedule = [
		{"time": 23.8, "x": -385.0, "z": -560.0, "strength": 0.28},
		{"time": 29.6, "x": 410.0, "z": -515.0, "strength": 0.34},
		{"time": 43.4, "x": -330.0, "z": -610.0, "strength": 0.24},
		{"time": 50.8, "x": 360.0, "z": -585.0, "strength": 0.31},
	]
	_next_distant_event = 0


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

	var flash_energy := lerpf(9.0, 24.0, importance)
	light_pool.spawn_launch_flash(start, flash_energy)
	post_process.register_flash(camera, start, flash_energy, 0)
	_spawn_burst(start + Vector3.UP * 0.8, importance * 0.72, false)
	if audio_director != null:
		audio_director.queue_launch(start, importance)

	if importance > 0.46 or _rng.randf() < 0.24:
		var smoke := _acquire_smoke()
		smoke.global_position = start
		smoke.configure(_smoke_texture, importance, _rng.randi(), _smoke_sprite_count)
		_smoke_columns.append(smoke)


func _on_trail_impact(
	world_position: Vector3,
	incoming_velocity: Vector3,
	visual_importance: float
) -> void:
	if terrain == null:
		return
	var impact_position := Vector3(
		world_position.x,
		terrain.height_at_world(world_position.x, world_position.z) + 0.22,
		world_position.z
	)
	var impact_energy := lerpf(48.0, 118.0, clampf(visual_importance, 0.0, 1.0))
	light_pool.spawn_impact_flash(impact_position, impact_energy)
	var visible_strength := post_process.register_flash(
		camera, impact_position + Vector3.UP * 2.0, impact_energy, 1
	)
	_spawn_burst(impact_position, visual_importance, true)
	_spawn_dirt_spray(impact_position, incoming_velocity, visual_importance)
	if audio_director != null:
		audio_director.queue_impact(impact_position, visual_importance)

	var smoke := _acquire_smoke()
	smoke.global_position = impact_position
	smoke.configure(
		_smoke_texture,
		clampf(visual_importance * 1.08, 0.25, 1.0),
		_rng.randi(),
		maxi(8, int(round(float(_smoke_sprite_count) * 0.72)))
	)
	_smoke_columns.append(smoke)

	if visible_strength >= 0.56 and visual_importance >= 0.64:
		_trigger_slow_motion(visible_strength)


func _spawn_distant_event(data: Dictionary) -> void:
	var x := float(data["x"])
	var z := float(data["z"])
	var strength := float(data["strength"])
	var position := Vector3(x, terrain.height_at_world(x, z) + 0.35, z)
	var energy := lerpf(13.0, 24.0, strength)
	light_pool.spawn_distant_flash(position, energy)
	post_process.register_flash(camera, position + Vector3.UP * 4.0, energy, 2)
	_spawn_burst(position, strength, true)
	if audio_director != null:
		audio_director.queue_distant(position, strength)


func _reset_loop() -> void:
	event_time = 0.0
	_next_event = 0
	_next_distant_event = 0
	for trail in _trails:
		if is_instance_valid(trail):
			trail.recycle()
			_trail_pool.append(trail)
	_trails.clear()
	for dirt_spray in _dirt_sprays:
		if is_instance_valid(dirt_spray):
			dirt_spray.recycle()
			_dirt_spray_pool.append(dirt_spray)
	_dirt_sprays.clear()


func _prewarm_pools() -> void:
	while _trail_pool.size() + _trails.size() < _maximum_trail_count:
		var trail := BallisticTrail3D.new()
		trail.visible = false
		add_child(trail)
		_connect_trail(trail)
		_trail_pool.append(trail)
	var smoke_reserve := 6 if _smoke_sprite_count <= 12 else 10
	while _smoke_pool.size() + _smoke_columns.size() < smoke_reserve:
		var smoke := SmokeColumn.new()
		smoke.visible = false
		add_child(smoke)
		_smoke_pool.append(smoke)
	var burst_reserve := 8 if _performance_mode else 14
	while _burst_pool.size() + _bursts.size() < burst_reserve:
		var burst := BarrageFlashBurst.new()
		burst.visible = false
		add_child(burst)
		_burst_pool.append(burst)
	var dirt_reserve := 8 if _performance_mode else 14
	while _dirt_spray_pool.size() + _dirt_sprays.size() < dirt_reserve:
		var dirt_spray = DIRT_SPRAY_SCRIPT.new()
		dirt_spray.visible = false
		add_child(dirt_spray)
		_dirt_spray_pool.append(dirt_spray)


func _acquire_trail() -> BallisticTrail3D:
	if _trail_pool.is_empty():
		var trail := BallisticTrail3D.new()
		add_child(trail)
		_connect_trail(trail)
		return trail
	return _trail_pool.pop_back()


func _acquire_smoke() -> SmokeColumn:
	if _smoke_pool.is_empty():
		var smoke := SmokeColumn.new()
		add_child(smoke)
		return smoke
	return _smoke_pool.pop_back()


func _connect_trail(trail: BallisticTrail3D) -> void:
	if not trail.impact_reached.is_connected(_on_trail_impact):
		trail.impact_reached.connect(_on_trail_impact)


func _spawn_burst(position: Vector3, importance: float, impact: bool) -> void:
	var burst: BarrageFlashBurst
	if _burst_pool.is_empty():
		burst = BarrageFlashBurst.new()
		add_child(burst)
	else:
		burst = _burst_pool.pop_back()
	burst.configure(
		camera,
		FLASH_TEXTURE,
		position,
		clampf(importance, 0.08, 1.0),
		impact,
		_rng.randi()
	)
	_bursts.append(burst)


func _spawn_dirt_spray(
	position: Vector3,
	incoming_velocity: Vector3,
	visual_importance: float
) -> void:
	var dirt_spray
	if _dirt_spray_pool.is_empty():
		dirt_spray = DIRT_SPRAY_SCRIPT.new()
		add_child(dirt_spray)
	else:
		dirt_spray = _dirt_spray_pool.pop_back()
	dirt_spray.configure(
		camera,
		terrain,
		position,
		incoming_velocity,
		terrain.normal_at_world(position.x, position.z),
		clampf(visual_importance, 0.08, 1.0),
		_rng.randi(),
		_performance_mode
	)
	_dirt_sprays.append(dirt_spray)


func _trigger_slow_motion(strength: float) -> void:
	var now := Time.get_ticks_msec()
	if _slowmo_active:
		_slowmo_strength = maxf(_slowmo_strength, strength)
		return
	if now < _slowmo_cooldown_until_msec:
		return
	_slowmo_active = true
	_slowmo_strength = clampf(strength, 0.0, 1.0)
	_slowmo_started_msec = now
	_slowmo_cooldown_until_msec = now + SLOWMO_COOLDOWN_MSEC


func _update_slow_motion() -> void:
	if not _configured or not _slowmo_active:
		return
	var elapsed_real := float(Time.get_ticks_msec() - _slowmo_started_msec) / 1000.0
	var minimum_scale := lerpf(0.56, 0.42, _slowmo_strength)
	var target_scale := minimum_scale
	if elapsed_real > SLOWMO_HOLD_SECONDS:
		var recovery := clampf(
			(elapsed_real - SLOWMO_HOLD_SECONDS) / SLOWMO_RECOVERY_SECONDS, 0.0, 1.0
		)
		var eased := recovery * recovery * (3.0 - 2.0 * recovery)
		target_scale = lerpf(minimum_scale, 1.0, eased)
	Engine.time_scale = target_scale
	if player != null:
		player.set("mouse_sensitivity", _base_mouse_sensitivity * target_scale)
	if elapsed_real >= SLOWMO_HOLD_SECONDS + SLOWMO_RECOVERY_SECONDS:
		_slowmo_active = false
		Engine.time_scale = 1.0
		if player != null:
			player.set("mouse_sensitivity", _base_mouse_sensitivity)


func _restore_time_state() -> void:
	if not _configured:
		return
	Engine.time_scale = _previous_time_scale
	if player != null and is_instance_valid(player):
		player.set("mouse_sensitivity", _base_mouse_sensitivity)
	_slowmo_active = false
