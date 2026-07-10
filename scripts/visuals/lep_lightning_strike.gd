extends Node3D

@export var strike_interval: float = 30.0
@export var first_strike_delay: float = 4.0
@export var bolt_height: float = 34.0
@export var bolt_width: float = 7.5
@export var flash_energy: float = 38.0
@export var flash_range: float = 82.0
@export var thunder_volume_db: float = -13.0

const SAMPLE_RATE := 22050
const BOLT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 bolt_color : source_color = vec4(0.72, 0.05, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.86, 1.0, 1.0);
uniform float emission_strength = 18.0;
uniform float core_width = 0.026;
uniform float glow_width = 0.18;
uniform float jaggedness = 0.18;
uniform float seed = 0.0;
uniform float flicker = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i + seed), hash(i + 1.0 + seed), u);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 28.0 + seed * 3.7;
	float n1 = noise(uv.y * 18.0 + t);
	float n2 = noise(uv.y * 43.0 - t * 0.62);
	float n3 = noise(uv.y * 91.0 + t * 1.23);
	float center = (n1 - 0.5) * jaggedness;
	center += (n2 - 0.5) * jaggedness * 0.58;
	center += (n3 - 0.5) * jaggedness * 0.26;

	float x = uv.x - 0.5 - center;
	float dist_to_core = abs(x);
	float core = 1.0 - smoothstep(core_width, core_width * 2.2, dist_to_core);
	float glow = 1.0 - smoothstep(core_width, glow_width, dist_to_core);

	float segment = smoothstep(0.08, 0.34, noise(uv.y * 74.0 + t * 1.9));
	float branches = 0.0;
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		float by = hash(fi * 31.17 + seed * 2.0);
		float side = hash(fi * 12.73 + seed) > 0.5 ? 1.0 : -1.0;
		float len = mix(0.1, 0.36, hash(fi * 9.41 + seed));
		float slope = side * mix(0.65, 1.9, hash(fi * 4.22 + seed));
		float local_y = uv.y - by;
		float active = step(0.0, local_y) * step(local_y, len);
		float bx = center + side * local_y * slope;
		float branch_dist = abs((uv.x - 0.5) - bx);
		float branch_line = 1.0 - smoothstep(core_width * 0.62, glow_width * 0.48, branch_dist);
		float fade = 1.0 - smoothstep(0.0, len, local_y);
		branches += branch_line * fade * active;
	}
	branches = clamp(branches * 0.9, 0.0, 1.0);

	float alpha = clamp(core * 1.7 + glow * 0.62 + branches * 0.72, 0.0, 1.0);
	alpha = pow(alpha * segment, 1.12) * flicker;
	vec3 color = mix(bolt_color.rgb, core_color.rgb, core);
	color += bolt_color.rgb * glow * 1.8;
	color += vec3(0.92, 0.22, 1.0) * branches;

	ALBEDO = color;
	EMISSION = color * emission_strength * alpha;
	ALPHA = alpha;
}
"""

var _bolt_material: ShaderMaterial
var _bolt_mesh: MeshInstance3D
var _impact_glow: MeshInstance3D
var _flash_light: OmniLight3D
var _down_light: SpotLight3D
var _thunder_player: AudioStreamPlayer3D
var _thunder_playback: AudioStreamGeneratorPlayback
var _audio_time := 0.0
var _audio_duration := 0.0
var _rng := RandomNumberGenerator.new()
var _running := false


func _ready() -> void:
	_rng.seed = 77191
	_build_visuals()
	_build_lights()
	_build_thunder_player()
	_running = true
	_loop_strikes()


func _exit_tree() -> void:
	_running = false
	if _thunder_player != null:
		_thunder_player.stop()


func _process(_delta: float) -> void:
	_fill_thunder_buffer()


func _loop_strikes() -> void:
	await get_tree().create_timer(maxf(0.1, first_strike_delay)).timeout
	while _running and is_inside_tree():
		await _strike()
		await get_tree().create_timer(maxf(1.0, strike_interval)).timeout


func _strike() -> void:
	var seed_value := _rng.randf_range(0.0, 1000.0)
	rotation_degrees.y = _rng.randf_range(-4.0, 4.0)
	rotation_degrees.z = _rng.randf_range(-2.0, 2.0)
	_bolt_material.set_shader_parameter("seed", seed_value)
	_bolt_material.set_shader_parameter("flicker", 1.0)
	_bolt_mesh.visible = true
	_impact_glow.visible = true
	_flash_light.visible = true
	_down_light.visible = true
	_trigger_thunder()

	var pulses := 4
	for pulse in range(pulses):
		var power: float = [1.0, 0.42, 0.82, 0.24][pulse]
		_bolt_material.set_shader_parameter("flicker", power)
		_bolt_material.set_shader_parameter("emission_strength", 20.0 + flash_energy * 0.35 * power)
		_flash_light.light_energy = flash_energy * power
		_flash_light.omni_range = flash_range * (0.88 + power * 0.16)
		_down_light.light_energy = flash_energy * 1.18 * power
		await get_tree().create_timer(0.035 + float(pulse % 2) * 0.018).timeout

		_bolt_material.set_shader_parameter("flicker", 0.08)
		_flash_light.light_energy = flash_energy * 0.08
		_down_light.light_energy = flash_energy * 0.1
		await get_tree().create_timer(0.022).timeout

	_bolt_mesh.visible = false
	_impact_glow.visible = false
	_flash_light.light_energy = 0.0
	_down_light.light_energy = 0.0
	_flash_light.visible = false
	_down_light.visible = false
	_bolt_material.set_shader_parameter("flicker", 0.0)


func _build_visuals() -> void:
	var shader := Shader.new()
	shader.code = BOLT_SHADER
	_bolt_material = ShaderMaterial.new()
	_bolt_material.resource_name = "mat_lep_purple_lightning_runtime"
	_bolt_material.shader = shader
	_bolt_material.set_shader_parameter("flicker", 0.0)

	_bolt_mesh = MeshInstance3D.new()
	_bolt_mesh.name = "PurpleLightningBolt"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(bolt_width, bolt_height)
	_bolt_mesh.mesh = mesh
	_bolt_mesh.position = Vector3(0.0, bolt_height * 0.5, 0.0)
	_bolt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt_mesh.set_surface_override_material(0, _bolt_material)
	_bolt_mesh.visible = false
	add_child(_bolt_mesh)

	_impact_glow = MeshInstance3D.new()
	_impact_glow.name = "PurpleLightningImpactGlow"
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 3.2
	glow_mesh.bottom_radius = 3.2
	glow_mesh.height = 0.045
	glow_mesh.radial_segments = 48
	_impact_glow.mesh = glow_mesh
	_impact_glow.position = Vector3(0.0, 0.08, 0.0)
	_impact_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_glow.set_surface_override_material(0, _make_impact_material())
	_impact_glow.visible = false
	add_child(_impact_glow)


func _build_lights() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.name = "LEPLightningPurpleFlash"
	_flash_light.position = Vector3(0.0, 13.5, 0.0)
	_flash_light.light_color = Color(0.74, 0.14, 1.0, 1.0)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = flash_range
	_flash_light.shadow_enabled = true
	_flash_light.shadow_bias = 0.045
	_flash_light.shadow_normal_bias = 1.0
	_flash_light.visible = false
	add_child(_flash_light)

	_down_light = SpotLight3D.new()
	_down_light.name = "LEPLightningDownBlast"
	_down_light.position = Vector3(0.0, 31.0, 0.0)
	_down_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_down_light.light_color = Color(0.93, 0.74, 1.0, 1.0)
	_down_light.light_energy = 0.0
	_down_light.spot_range = flash_range
	_down_light.spot_angle = 62.0
	_down_light.spot_attenuation = 0.82
	_down_light.shadow_enabled = true
	_down_light.shadow_bias = 0.035
	_down_light.visible = false
	add_child(_down_light)


func _build_thunder_player() -> void:
	_thunder_player = AudioStreamPlayer3D.new()
	_thunder_player.name = "QuietElectricThunder"
	_thunder_player.position = Vector3(0.0, 6.0, 0.0)
	_thunder_player.volume_db = thunder_volume_db
	_thunder_player.max_distance = 145.0
	_thunder_player.unit_size = 16.0
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 1.4
	_thunder_player.stream = stream
	add_child(_thunder_player)
	_thunder_player.play()
	_thunder_playback = _thunder_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _trigger_thunder() -> void:
	_audio_time = 0.0
	_audio_duration = 1.05
	if _thunder_player != null and not _thunder_player.playing:
		_thunder_player.play()
		_thunder_playback = _thunder_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_thunder_buffer() -> void:
	if _thunder_playback == null or _audio_time >= _audio_duration:
		return
	var frames_available := _thunder_playback.get_frames_available()
	var frames_to_push: int = mini(frames_available, 1024)
	for _i in range(frames_to_push):
		var t := _audio_time
		var crack_env := maxf(0.0, 1.0 - t / 0.16)
		var rumble_env := exp(-t * 2.8) * smoothstep(0.02, 0.22, t)
		var crack := (_rng.randf() * 2.0 - 1.0) * crack_env * 0.32
		var low := sin(TAU * 47.0 * t) * rumble_env * 0.16
		var mid := sin(TAU * 91.0 * t + sin(t * 18.0)) * rumble_env * 0.08
		var sample := clampf(crack + low + mid, -0.72, 0.72)
		_thunder_playback.push_frame(Vector2(sample, sample))
		_audio_time += 1.0 / float(SAMPLE_RATE)
		if _audio_time >= _audio_duration:
			break


func _make_impact_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.16, 1.0, 0.42)
	material.emission_enabled = true
	material.emission = Color(0.74, 0.06, 1.0, 1.0)
	material.emission_energy_multiplier = 6.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material
