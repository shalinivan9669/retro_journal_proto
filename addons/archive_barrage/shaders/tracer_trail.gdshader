shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float core_energy = 32.0;
uniform float halo_energy = 5.0;
uniform float head_energy = 72.0;
uniform float trail_decay = 2.05;
uniform float seed = 667.0;

float hash11(float p) {
	return fract(sin(p * 127.1 + seed * 311.7) * 43758.5453);
}

float value_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

void fragment() {
	float age = UV.x;
	float lateral = abs(UV.y * 2.0 - 1.0);

	float core = exp(-0.5 * pow(lateral / 0.052, 2.0));
	float halo = exp(-0.5 * pow(lateral / 0.34, 2.0));
	float head = exp(-0.5 * pow(age / 0.024, 2.0));

	float end_fade = 1.0 - smoothstep(0.80, 1.0, age);
	float persistence = exp(-age * trail_decay) * end_fade;
	float breakup = mix(0.70, 1.0, value_noise(age * 190.0));
	float head_flicker = mix(1.0, 0.82 + value_noise(TIME * 19.0) * 0.30, head);

	float energy = core * core_energy + halo * halo_energy + head * head_energy;
	energy *= persistence * breakup * head_flicker;

	EMISSION = vec3(energy);
	ALPHA = clamp((core + halo * 0.22) * persistence, 0.0, 1.0);
}
