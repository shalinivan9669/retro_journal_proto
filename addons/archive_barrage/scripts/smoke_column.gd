class_name SmokeColumn
extends Node3D

var age := 0.0
var lifetime := 22.0
var wind := Vector3(2.2, 0.0, 0.6)
var importance := 1.0
var _sprites: Array[Sprite3D] = []
var _velocity: Array[Vector3] = []
var _spawn_delay: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _active_sprite_count := 0


func configure(
	texture: Texture2D,
	visual_importance: float,
	seed_value: int,
	sprite_count: int = 24
) -> void:
	age = 0.0
	importance = visual_importance
	_rng.seed = seed_value
	visible = true
	_active_sprite_count = maxi(1, sprite_count)
	while _sprites.size() < _active_sprite_count:
		var sprite := Sprite3D.new()
		sprite.hframes = 4
		sprite.vframes = 4
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = true
		sprite.double_sided = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.pixel_size = 0.012
		add_child(sprite)
		_sprites.append(sprite)

	_velocity.clear()
	_spawn_delay.clear()
	for index in range(_sprites.size()):
		var sprite := _sprites[index]
		if index >= _active_sprite_count:
			sprite.visible = false
			continue
		sprite.texture = texture
		sprite.frame = _rng.randi_range(0, 15)
		sprite.position = Vector3.ZERO
		sprite.scale = Vector3.ONE
		sprite.modulate = Color(0.32, 0.325, 0.33, 0.0)
		sprite.visible = false
		_velocity.append(
			Vector3(
				_rng.randf_range(-0.5, 0.5), _rng.randf_range(2.0, 5.0), _rng.randf_range(-0.4, 0.4)
			)
		)
		_spawn_delay.append(_rng.randf_range(0.0, 3.8))


func advance(fx_delta: float) -> void:
	age += fx_delta
	for index in range(_active_sprite_count):
		var local_age := age - _spawn_delay[index]
		var sprite := _sprites[index]
		if local_age <= 0.0:
			sprite.visible = false
			continue
		sprite.visible = true
		sprite.position += (_velocity[index] + wind * minf(local_age / 4.0, 1.0)) * fx_delta
		var scale_value := lerpf(0.42, 1.85, clampf(local_age / 9.0, 0.0, 1.0))
		sprite.scale = Vector3.ONE * scale_value * lerpf(0.8, 1.25, importance)
		var fade_in := smoothstep(0.0, 0.65, local_age)
		var fade_out := 1.0 - smoothstep(lifetime * 0.62, lifetime, local_age)
		var alpha := fade_in * fade_out * lerpf(0.28, 0.62, importance)
		sprite.modulate = Color(0.28, 0.285, 0.29, alpha)


func is_finished() -> bool:
	return age > lifetime + 4.0


func recycle() -> void:
	age = 0.0
	visible = false
	for sprite in _sprites:
		sprite.visible = false
