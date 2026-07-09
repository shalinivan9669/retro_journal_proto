extends Resource
class_name TerrainHeightSampler

enum LandscapeZone {
	NO_SPAWN,
	YURT_FLAT,
	YURT_EDGE,
	DRY_STEPPE,
	LOWLAND_WET,
	ROCKY_PATCH,
	PATH_EDGE,
	DISTANT_TREE_PATCH,
	SALT_DUST_EDGE
}

@export var seed_value: int = 9669
@export var base_height_scale: float = 1.45
@export var yurt_flat_radius: float = 14.0
@export var yurt_blend_radius: float = 26.0
@export var lake_direction: Vector2 = Vector2(-1.0, -0.12)
@export var lake_lowland_depth: float = -0.85
@export var hill_strength: float = 1.25
@export var rut_strength: float = 0.28

var noise_macro := FastNoiseLite.new()
var noise_detail := FastNoiseLite.new()
var noise_ruts := FastNoiseLite.new()
var noise_stony := FastNoiseLite.new()


func setup() -> void:
	lake_direction = lake_direction.normalized()

	noise_macro.seed = seed_value
	noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_macro.frequency = 0.018
	noise_macro.fractal_octaves = 4
	noise_macro.fractal_gain = 0.48

	noise_detail.seed = seed_value + 17
	noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_detail.frequency = 0.085
	noise_detail.fractal_octaves = 3
	noise_detail.fractal_gain = 0.42

	noise_ruts.seed = seed_value + 41
	noise_ruts.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_ruts.frequency = 0.045
	noise_ruts.fractal_octaves = 2

	noise_stony.seed = seed_value + 91
	noise_stony.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_stony.frequency = 0.032
	noise_stony.fractal_octaves = 3


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var dist := p.length()
	var flat_blend := smoothstep(yurt_flat_radius, yurt_blend_radius, dist)

	var macro := noise_macro.get_noise_2d(x, z) * base_height_scale * hill_strength
	var detail := noise_detail.get_noise_2d(x, z) * 0.22

	var lake_axis := p.dot(lake_direction)
	var lake_mask := smoothstep(18.0, 92.0, lake_axis)
	var lowland := lake_lowland_depth * lake_mask

	var rut_raw: float = abs(noise_ruts.get_noise_2d(x * 0.65, z * 1.25))
	var ruts := -pow(1.0 - rut_raw, 5.0) * rut_strength

	var yurt_ring := exp(-pow((dist - 18.0) / 7.0, 2.0)) * 0.18
	var rock_lift := _rock_cluster_height_influence(p)
	var stony_micro := noise_stony.get_noise_2d(x, z) * 0.08 * _rocky_mask(p)

	var h := macro + detail + lowland + ruts + yurt_ring + rock_lift + stony_micro
	return lerp(0.0, h, flat_blend)


func normal_at(x: float, z: float, sample_step: float = 0.65) -> Vector3:
	var h_l := height_at(x - sample_step, z)
	var h_r := height_at(x + sample_step, z)
	var h_d := height_at(x, z - sample_step)
	var h_u := height_at(x, z + sample_step)

	var dx := Vector3(sample_step * 2.0, h_r - h_l, 0.0)
	var dz := Vector3(0.0, h_u - h_d, sample_step * 2.0)
	var normal := dz.cross(dx).normalized()
	if normal.y < 0.0:
		normal = -normal
	return normal


func zone_at(x: float, z: float) -> int:
	var p := Vector2(x, z)
	var dist := p.length()

	if dist < 11.5:
		return LandscapeZone.NO_SPAWN

	if _inside_yurt_entrance_clear_path(p):
		return LandscapeZone.NO_SPAWN

	if dist < 22.0:
		return LandscapeZone.YURT_EDGE

	if _near_main_path(p):
		return LandscapeZone.PATH_EDGE

	if _near_rock_cluster(p):
		return LandscapeZone.ROCKY_PATCH

	if x < -82.0:
		return LandscapeZone.SALT_DUST_EDGE

	if x < -48.0:
		return LandscapeZone.LOWLAND_WET

	if dist > 58.0 and dist < 122.0:
		return LandscapeZone.DISTANT_TREE_PATCH

	return LandscapeZone.DRY_STEPPE


func path_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 99999.0
	var path_points := _main_path_points()
	for i in range(path_points.size() - 1):
		best = min(best, _distance_to_segment(p, path_points[i], path_points[i + 1]))
	return best


func rock_mask_at(x: float, z: float) -> float:
	return _rocky_mask(Vector2(x, z))


func _inside_yurt_entrance_clear_path(p: Vector2) -> bool:
	return abs(p.x) < 3.8 and p.y < -7.5 and p.y > -35.0


func _near_main_path(p: Vector2) -> bool:
	return path_distance(p.x, p.y) < 5.5


func _near_rock_cluster(p: Vector2) -> bool:
	for c in _rock_clusters():
		if p.distance_to(c) < 16.0:
			return true
	return false


func _rock_cluster_height_influence(p: Vector2) -> float:
	var influence := 0.0
	for c in _rock_clusters():
		var d := p.distance_to(c)
		var m := 1.0 - smoothstep(0.0, 18.0, d)
		influence += m * 0.32
	return influence


func _rocky_mask(p: Vector2) -> float:
	var influence := 0.0
	for c in _rock_clusters():
		influence = max(influence, 1.0 - smoothstep(5.0, 22.0, p.distance_to(c)))
	return influence


func _rock_clusters() -> Array[Vector2]:
	return [
		Vector2(28.0, -38.0),
		Vector2(-34.0, -52.0),
		Vector2(46.0, 22.0),
		Vector2(-76.0, -18.0)
	]


func _main_path_points() -> Array[Vector2]:
	return [
		Vector2(0.0, -12.0),
		Vector2(0.0, -24.0),
		Vector2(3.0, -39.0),
		Vector2(8.0, -58.0),
		Vector2(2.0, -78.0)
	]


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)
