class_name TerrainHeightField
extends Resource

## Deterministic earthen, torn highland with a deliberately composed hill on
## the azimuth opposite the moon. Coordinates are metres in world XZ.

@export var seed: int = 667
@export var player_origin_xz := Vector2.ZERO
@export_range(-180.0, 180.0, 0.1) var moon_azimuth_deg: float = 62.0

@export_group("General relief")
@export_range(0.0, 20.0, 0.1) var macro_amplitude_m: float = 7.2
@export_range(0.0, 12.0, 0.1) var meso_amplitude_m: float = 3.4
@export_range(0.0, 4.0, 0.05) var micro_amplitude_m: float = 0.65
@export_range(0.0, 40.0, 0.5) var safe_radius_m: float = 13.0

@export_group("Film steppe landforms")
@export var film_steppe_enabled := true
@export_range(0.0, 20.0, 0.1) var film_macro_strength_m: float = 9.6
@export_range(0.0, 10.0, 0.1) var film_meso_strength_m: float = 4.4
@export_range(0.0, 12.0, 0.1) var film_ravine_depth_m: float = 7.2
@export_range(0.0, 1.0, 0.01) var film_crater_density: float = 0.70
@export_range(4.0, 40.0, 0.5) var film_crater_min_radius_m: float = 12.0
@export_range(8.0, 60.0, 0.5) var film_crater_max_radius_m: float = 30.0
@export_range(0.0, 15.0, 0.1) var film_crater_depth_m: float = 8.4
@export_range(0.0, 8.0, 0.1) var film_crater_rim_height_m: float = 2.8
@export_range(0.0, 20.0, 0.1) var film_observation_lift_m: float = 9.0
@export_range(4.0, 60.0, 0.5) var film_observation_top_radius_m: float = 32.0
@export_range(20.0, 160.0, 0.5) var film_observation_slope_radius_m: float = 88.0
@export_range(0.0, 60.0, 0.5) var film_safe_inner_radius_m: float = 32.0
@export_range(1.0, 100.0, 0.5) var film_safe_outer_radius_m: float = 52.0
@export_range(0.0, 40.0, 0.5) var film_max_depression_m: float = 18.0
@export_range(0.0, 50.0, 0.5) var film_max_rise_m: float = 24.0

@export_group("Hero hill opposite moon")
@export_range(20.0, 250.0, 1.0) var hill_distance_m: float = 92.0
@export_range(1.0, 40.0, 0.1) var hill_height_m: float = 33.0
@export_range(5.0, 80.0, 0.5) var hill_forward_sigma_m: float = 18.0
@export_range(5.0, 100.0, 0.5) var hill_lateral_sigma_m: float = 31.0
@export_range(0.0, 10.0, 0.1) var hill_shoulder_height_m: float = 6.4

var _macro := FastNoiseLite.new()
var _meso := FastNoiseLite.new()
var _micro := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _configured_seed: int = -2147483648

func moon_direction_xz() -> Vector2:
	var angle := deg_to_rad(moon_azimuth_deg)
	return Vector2(cos(angle), sin(angle)).normalized()

func hill_direction_xz() -> Vector2:
	return -moon_direction_xz()

func hill_center_xz() -> Vector2:
	return player_origin_xz + hill_direction_xz() * hill_distance_m

func hill_aim_point(extra_height_m: float = 1.2) -> Vector3:
	var center := hill_center_xz()
	return Vector3(center.x, sample_height(center) + extra_height_m, center.y)

func sample_height(world_xz: Vector2) -> float:
	_ensure_noise()
	var warp_vector := _sample_warp_vector(world_xz)
	return (
		_sample_general_relief_height(world_xz, warp_vector)
		+ _sample_film_steppe_height(world_xz, warp_vector)
		+ _sample_hero_hill_height(world_xz, warp_vector)
	)


func sample_film_steppe_height(world_xz: Vector2) -> float:
	## Film-enabled additive landscape in metres. This deliberately remains a
	## separate sampler: BarrageTerrain can layer it over its existing heightmap
	## while sample_hero_hill_height() keeps its hero-landmark-only contract.
	_ensure_noise()
	return _sample_film_steppe_height(world_xz, _sample_warp_vector(world_xz))


func sample_hero_hill_height(world_xz: Vector2) -> float:
	## Returns only the deliberately composed hero hill and shoulder in metres.
	## General macro/meso/micro relief is intentionally excluded so callers can
	## layer the landmark over an existing terrain without replacing its profile.
	_ensure_noise()
	return _sample_hero_hill_height(world_xz, _sample_warp_vector(world_xz))

func _sample_warp_vector(world_xz: Vector2) -> Vector2:
	return Vector2(
		_warp.get_noise_2d(world_xz.x, world_xz.y),
		_warp.get_noise_2d(world_xz.x + 741.0, world_xz.y - 319.0)
	) * 11.0

func _sample_general_relief_height(world_xz: Vector2, warp_vector: Vector2) -> float:
	var centered := world_xz - player_origin_xz
	var distance_from_player := centered.length()
	var safe_blend := smoothstep(safe_radius_m * 0.55, safe_radius_m, distance_from_player)

	var warped := world_xz + warp_vector

	var macro := _macro.get_noise_2d(warped.x, warped.y) * macro_amplitude_m
	var meso := _meso.get_noise_2d(warped.x, warped.y) * meso_amplitude_m
	var micro := _micro.get_noise_2d(world_xz.x, world_xz.y) * micro_amplitude_m
	return (macro + meso + micro) * safe_blend


func _sample_film_steppe_height(world_xz: Vector2, warp_vector: Vector2) -> float:
	if not film_steppe_enabled:
		return 0.0

	var observation_height := _sample_observation_plateau_height(world_xz)
	var protection := _sample_film_steppe_protection(world_xz)
	if protection <= 0.0001:
		return observation_height

	# Large forms are gently domain-warped so the ridges never read as regular
	# sine bands. Local blast damage receives much less warp, keeping rims crisp.
	var broad_point := world_xz + warp_vector * 1.35
	var local_point := world_xz + warp_vector * 0.22
	var damaged_relief := (
		_sample_broad_steppe_relief(broad_point)
		+ _sample_composed_foreground_hills(world_xz)
		+ _sample_sinuous_drainage(world_xz)
		+ _sample_bomb_crater_field(local_point)
		+ _sample_foreground_blast_basins(world_xz)
	)
	var height := observation_height + damaged_relief * protection
	height = clampf(height, -film_max_depression_m, film_max_rise_m)
	return height


func _sample_observation_plateau_height(world_xz: Vector2) -> float:
	# The opening viewpoint sits on a broad natural mesa rather than a pedestal:
	# a genuinely level additive crown, followed by a 56 m smooth shoulder that
	# settles into the torn steppe and forms a shallow saddle toward the rear ridge.
	var distance := world_xz.distance_to(player_origin_xz)
	var top_radius := maxf(film_observation_top_radius_m, 1.0)
	var slope_radius := maxf(film_observation_slope_radius_m, top_radius + 1.0)
	if distance <= top_radius:
		return film_observation_lift_m
	if distance >= slope_radius:
		return 0.0
	var shoulder := 1.0 - smoothstep(top_radius, slope_radius, distance)
	return film_observation_lift_m * shoulder


func _sample_film_steppe_protection(world_xz: Vector2) -> float:
	# Craters/noise cannot cut through the mesa crown. The hero ridge and its
	# computed crest-edge target also remain free of unrelated damage relief.
	var spawn_distance := world_xz.distance_to(player_origin_xz)
	var safe_inner := maxf(film_safe_inner_radius_m, safe_radius_m)
	var safe_outer := maxf(film_safe_outer_radius_m, safe_inner + 1.0)
	var spawn_blend := smoothstep(safe_inner, safe_outer, spawn_distance)
	var hill_blend := smoothstep(38.0, 72.0, world_xz.distance_to(hill_center_xz()))
	return spawn_blend * hill_blend


func _sample_broad_steppe_relief(world_xz: Vector2) -> float:
	var local := world_xz - player_origin_xz
	var continental := _macro.get_noise_2d(world_xz.x - 173.0, world_xz.y + 91.0)
	var ridge_noise := _macro.get_noise_2d(world_xz.x * 0.73 + 417.0, world_xz.y * 0.73 - 263.0)
	var folded_ridge := pow(clampf(1.0 - absf(ridge_noise), 0.0, 1.0), 2.4)
	var directional_wave := sin(
		local.dot(Vector2(0.82, 0.57)) / 116.0
		+ _meso.get_noise_2d(world_xz.x * 0.36, world_xz.y * 0.36) * 1.35
	)
	var macro := film_macro_strength_m * (
		continental * 0.56 + (folded_ridge - 0.28) * 0.30 + directional_wave * 0.14
	)

	var meso_a := _meso.get_noise_2d(world_xz.x + 211.0, world_xz.y - 337.0)
	var meso_b := _meso.get_noise_2d(world_xz.x * 1.47 - 509.0, world_xz.y * 1.47 + 127.0)
	var meso := film_meso_strength_m * (meso_a * 0.72 + meso_b * 0.28)
	var surface_breakup := _micro.get_noise_2d(world_xz.x - 71.0, world_xz.y + 619.0) * 0.42
	return macro + meso + surface_breakup


func _sample_composed_foreground_hills(world_xz: Vector2) -> float:
	# These broad, asymmetric silhouettes live in the player's initial view
	# (negative Z from the origin) rather than being left to random noise.
	return (
		_sample_elliptical_mound(
			world_xz, Vector2(-126.0, -142.0), 112.0, 43.0, 8.8, deg_to_rad(-38.0)
		)
		+ _sample_elliptical_mound(
			world_xz, Vector2(178.0, -226.0), 146.0, 58.0, 13.5, deg_to_rad(31.0)
		)
		+ _sample_elliptical_mound(
			world_xz, Vector2(-272.0, -354.0), 184.0, 78.0, 16.5, deg_to_rad(-17.0)
		)
		+ _sample_elliptical_mound(
			world_xz, Vector2(24.0, -468.0), 285.0, 86.0, 19.0, deg_to_rad(4.0)
		)
		+ _sample_elliptical_mound(
			world_xz, Vector2(31.0, -168.0), 94.0, 61.0, -4.8, deg_to_rad(12.0)
		)
	)


func _sample_elliptical_mound(
	world_xz: Vector2,
	relative_center: Vector2,
	forward_sigma_m: float,
	lateral_sigma_m: float,
	height_m: float,
	angle_rad: float
) -> float:
	var offset := world_xz - (player_origin_xz + relative_center)
	var axis := Vector2(cos(angle_rad), sin(angle_rad))
	var side := Vector2(-axis.y, axis.x)
	var power := 0.5 * (
		pow(offset.dot(axis) / maxf(forward_sigma_m, 0.1), 2.0)
		+ pow(offset.dot(side) / maxf(lateral_sigma_m, 0.1), 2.0)
	)
	if power >= 7.0:
		return 0.0
	return height_m * exp(-power)


func _sample_sinuous_drainage(world_xz: Vector2) -> float:
	# A broad front aryk crosses 35-75 m ahead; two deeper diagonal gullies
	# continue through the mid-ground. Raised banks make them readable at night.
	var depth_scale := film_ravine_depth_m / 7.2
	return depth_scale * (
		_sample_sinuous_channel(
			world_xz, Vector2.RIGHT, -57.0, 16.0, 6.2, 18.0, 102.0, 0.35, 1.7
		)
		+ _sample_sinuous_channel(
			world_xz, Vector2(0.78, -0.625).normalized(), -154.0,
			24.0, 8.0, 31.0, 154.0, 1.7, 2.3
		)
		+ _sample_sinuous_channel(
			world_xz, Vector2(0.96, 0.28).normalized(), -244.0,
			11.0, 4.1, 15.0, 79.0, 4.2, 1.0
		)
	)


func _sample_sinuous_channel(
	world_xz: Vector2,
	direction: Vector2,
	side_offset_m: float,
	half_width_m: float,
	depth_m: float,
	bend_amplitude_m: float,
	bend_scale_m: float,
	phase: float,
	bank_height_m: float
) -> float:
	var relative := world_xz - player_origin_xz
	var axis := direction.normalized()
	var side := Vector2(-axis.y, axis.x)
	var along := relative.dot(axis)
	var bend := (
		sin(along / bend_scale_m + phase) * bend_amplitude_m
		+ sin(along / (bend_scale_m * 2.73) - phase * 0.61) * bend_amplitude_m * 0.38
	)
	var distance_to_bed := absf(relative.dot(side) - side_offset_m - bend)
	var width := maxf(half_width_m, 0.5)
	if distance_to_bed >= width * 1.85:
		return 0.0

	var bed_t := clampf(1.0 - distance_to_bed / width, 0.0, 1.0)
	var bed := -depth_m * pow(bed_t, 1.55)
	var bank_center := width * 1.22
	var bank_sigma := width * 0.24
	var bank_delta := (distance_to_bed - bank_center) / maxf(bank_sigma, 0.1)
	var bank := bank_height_m * exp(-0.5 * bank_delta * bank_delta)
	var outer_fade := 1.0 - smoothstep(width * 1.55, width * 1.85, distance_to_bed)
	return (bed + bank) * outer_fade


func _sample_bomb_crater_field(world_xz: Vector2) -> float:
	# One deterministic candidate per 58 m cell yields hundreds of varied blast
	# scars over the 1.8 km terrain without storing or instancing scene nodes.
	const CELL_SIZE_M := 58.0
	var cell_x := int(floor(world_xz.x / CELL_SIZE_M))
	var cell_z := int(floor(world_xz.y / CELL_SIZE_M))
	var crater_sum := 0.0
	for z_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var candidate_x := cell_x + x_offset
			var candidate_z := cell_z + z_offset
			if _hash01(candidate_x, candidate_z, 11) > film_crater_density:
				continue
			var center := Vector2(
				(float(candidate_x) + _hash01(candidate_x, candidate_z, 23)) * CELL_SIZE_M,
				(float(candidate_z) + _hash01(candidate_x, candidate_z, 37)) * CELL_SIZE_M
			)
			var radius := lerpf(
				film_crater_min_radius_m,
				maxf(film_crater_max_radius_m, film_crater_min_radius_m),
				pow(_hash01(candidate_x, candidate_z, 47), 0.72)
			)
			var depth := film_crater_depth_m * lerpf(
				0.42, 1.0, _hash01(candidate_x, candidate_z, 59)
			)
			var rim := film_crater_rim_height_m * lerpf(
				0.38, 1.0, _hash01(candidate_x, candidate_z, 71)
			)
			var angle := _hash01(candidate_x, candidate_z, 83) * TAU
			var aspect := lerpf(0.78, 1.24, _hash01(candidate_x, candidate_z, 97))
			crater_sum += _sample_crater_shape(
				world_xz, center, radius, depth, rim, angle, aspect
			)
	return clampf(
		crater_sum,
		-film_crater_depth_m * 1.35,
		film_crater_rim_height_m * 1.65
	)


func _sample_foreground_blast_basins(world_xz: Vector2) -> float:
	# Hand-composed craters ensure the initial 25-220 m view is scarred even if
	# the seeded field happens to leave a quiet patch in front of the player.
	return (
		_sample_crater_shape(
			world_xz, player_origin_xz + Vector2(-27.0, -47.0),
			17.0, 6.5, 2.0, deg_to_rad(18.0), 0.88
		)
		+ _sample_crater_shape(
			world_xz, player_origin_xz + Vector2(39.0, -77.0),
			24.0, 9.3, 2.9, deg_to_rad(-27.0), 1.16
		)
		+ _sample_crater_shape(
			world_xz, player_origin_xz + Vector2(-77.0, -126.0),
			35.0, 11.4, 3.5, deg_to_rad(41.0), 0.81
		)
		+ _sample_crater_shape(
			world_xz, player_origin_xz + Vector2(88.0, -211.0),
			48.0, 13.2, 4.1, deg_to_rad(-9.0), 1.21
		)
	)


func _sample_crater_shape(
	world_xz: Vector2,
	center_xz: Vector2,
	radius_m: float,
	depth_m: float,
	rim_height_m: float,
	angle_rad: float,
	aspect: float
) -> float:
	var offset := world_xz - center_xz
	var axis := Vector2(cos(angle_rad), sin(angle_rad))
	var side := Vector2(-axis.y, axis.x)
	var safe_aspect := maxf(aspect, 0.2)
	var elliptical := Vector2(offset.dot(axis) / safe_aspect, offset.dot(side) * safe_aspect)
	var normalized_radius := elliptical.length() / maxf(radius_m, 0.1)
	if normalized_radius >= 1.55:
		return 0.0

	var bowl_t := clampf(1.0 - normalized_radius * normalized_radius, 0.0, 1.0)
	var bowl := -depth_m * bowl_t * bowl_t
	var rim_delta := (normalized_radius - 1.04) / 0.17
	var rim := rim_height_m * exp(-0.5 * rim_delta * rim_delta)
	var outer_fade := 1.0 - smoothstep(1.34, 1.55, normalized_radius)
	return (bowl + rim) * outer_fade


func _hash01(cell_x: int, cell_z: int, salt: int) -> float:
	# Float hash avoids mutable RNG state, so query order and profile resolution
	# cannot change crater placement.
	var phase := (
		float(cell_x) * 127.1
		+ float(cell_z) * 311.7
		+ float(seed + salt) * 0.137
	)
	var value := sin(phase) * 43758.5453123
	return value - floor(value)

func _sample_hero_hill_height(world_xz: Vector2, warp_vector: Vector2) -> float:
	var warped := world_xz + warp_vector
	var hill_dir := hill_direction_xz()
	var hill_side := Vector2(-hill_dir.y, hill_dir.x)
	var hill_local := world_xz - hill_center_xz() + warp_vector * 0.16
	var forward_m := hill_local.dot(hill_dir)
	var lateral_m := hill_local.dot(hill_side)
	var gaussian_power := 0.5 * (
		pow(forward_m / hill_forward_sigma_m, 2.0)
		+ pow(lateral_m / hill_lateral_sigma_m, 2.0)
	)
	var broken_factor := 1.0 + 0.15 * _meso.get_noise_2d(warped.x + 82.0, warped.y - 51.0)
	var hero_hill := hill_height_m * exp(-gaussian_power) * broken_factor

	var shoulder_local := hill_local - hill_side * 27.0 + hill_dir * 8.0
	var shoulder_power := 0.5 * (
		pow(shoulder_local.dot(hill_dir) / 25.0, 2.0)
		+ pow(shoulder_local.dot(hill_side) / 18.0, 2.0)
	)
	var shoulder := hill_shoulder_height_m * exp(-shoulder_power)
	return hero_hill + shoulder

func bake_normalized_heightmap(resolution: int = 513, world_size_m: float = 360.0) -> Dictionary:
	var safe_resolution := maxi(resolution, 3)
	var values := PackedFloat32Array()
	values.resize(safe_resolution * safe_resolution)
	var minimum_height := INF
	var maximum_height := -INF
	for pixel_y in range(safe_resolution):
		for pixel_x in range(safe_resolution):
			var normalized := Vector2(pixel_x, pixel_y) / float(safe_resolution - 1)
			var world_xz := player_origin_xz + (normalized - Vector2(0.5, 0.5)) * world_size_m
			var height := sample_height(world_xz)
			var index := pixel_y * safe_resolution + pixel_x
			values[index] = height
			minimum_height = minf(minimum_height, height)
			maximum_height = maxf(maximum_height, height)

	var image := Image.create(safe_resolution, safe_resolution, false, Image.FORMAT_RF)
	var height_range := maxf(maximum_height - minimum_height, 0.001)
	for pixel_y in range(safe_resolution):
		for pixel_x in range(safe_resolution):
			var index := pixel_y * safe_resolution + pixel_x
			var normalized_height := (values[index] - minimum_height) / height_range
			image.set_pixel(pixel_x, pixel_y, Color(normalized_height, 0.0, 0.0, 1.0))
	return {
		"image": image,
		"minimum_height_m": minimum_height,
		"maximum_height_m": maximum_height,
		"world_size_m": world_size_m,
	}

func _ensure_noise() -> void:
	if _configured_seed == seed:
		return
	_configured_seed = seed

	_macro.seed = seed
	_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_macro.frequency = 1.0 / 118.0
	_macro.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_macro.fractal_octaves = 4
	_macro.fractal_lacunarity = 2.05
	_macro.fractal_gain = 0.54

	_meso.seed = seed + 101
	_meso.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_meso.frequency = 1.0 / 37.0
	_meso.fractal_type = FastNoiseLite.FRACTAL_FBM
	_meso.fractal_octaves = 4
	_meso.fractal_lacunarity = 2.15
	_meso.fractal_gain = 0.50

	_micro.seed = seed + 233
	_micro.noise_type = FastNoiseLite.TYPE_PERLIN
	_micro.frequency = 1.0 / 8.5
	_micro.fractal_type = FastNoiseLite.FRACTAL_FBM
	_micro.fractal_octaves = 3
	_micro.fractal_gain = 0.45

	_warp.seed = seed + 419
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = 1.0 / 74.0
	_warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	_warp.fractal_octaves = 3
	_warp.fractal_gain = 0.52
