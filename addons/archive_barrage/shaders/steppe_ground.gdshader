shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Texture-free rollback material.  It stays safe when external texture assets
// are unavailable, but remains lit so the terrain and barrage lights are legible.
uniform vec3 solid_ground_color : source_color = vec3(0.155, 0.170, 0.185);
uniform float macro_variation : hint_range(0.0, 0.25, 0.01) = 0.12;
uniform float micro_variation : hint_range(0.0, 0.12, 0.005) = 0.045;
uniform float roughness_floor : hint_range(0.75, 1.0, 0.01) = 0.92;
uniform float residual_specular : hint_range(0.0, 0.3, 0.01) = 0.08;

varying vec3 ground_world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float result = 0.0;
	float amplitude = 0.5;
	mat2 rotation = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int octave = 0; octave < 4; octave++) {
		result += value_noise(p) * amplitude;
		p = rotation * p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return result;
}

void vertex() {
	ground_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broad = fbm(ground_world_position.xz * 0.045);
	float grit = value_noise(ground_world_position.xz * 3.1 + vec2(11.2, -6.7));
	float tone = mix(1.0 - macro_variation, 1.0 + macro_variation * 0.55, broad);
	tone *= 1.0 + (grit - 0.5) * micro_variation;

	ALBEDO = solid_ground_color * tone;
	ROUGHNESS = clamp(
		mix(roughness_floor, 0.99, clamp(grit * 0.75 + broad * 0.25, 0.0, 1.0)),
		roughness_floor,
		1.0
	);
	METALLIC = 0.0;
	SPECULAR = residual_specular;
}
