shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0) = 0.62;
uniform float grain_strength : hint_range(0.0, 2.0) = 0.78;
uniform float bloom_white : hint_range(0.0, 2.0) = 0.42;
uniform float soft_vignette : hint_range(0.0, 1.0) = 0.28;
uniform float pulse_speed : hint_range(0.0, 8.0) = 0.82;
uniform float dream_warp : hint_range(0.0, 0.05) = 0.006;
uniform vec4 white_tint : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform vec4 black_tint : source_color = vec4(0.02, 0.018, 0.018, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered * vec2(1.0, 0.78));
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float veil = value_noise(uv * vec2(5.0, 3.0) + vec2(TIME * 0.035, -TIME * 0.021));
	vec2 warped_uv = uv + normalize(centered + 0.0001) * (veil - 0.5) * dream_warp * (0.45 + pulse * 0.55);
	vec3 base = texture(screen_texture, warped_uv).rgb;

	float sharp_grain = hash(uv * vec2(1800.0, 1050.0) + floor(TIME * 24.0));
	float medium_grain = value_noise(uv * vec2(240.0, 140.0) + vec2(TIME * 1.7, TIME * -0.95));
	float bw = step(0.50, sharp_grain * 0.72 + medium_grain * 0.28);
	vec3 noise_col = mix(black_tint.rgb, white_tint.rgb, bw);

	float center_halo = 1.0 - smoothstep(0.08, 0.78, dist);
	float edge_dark = smoothstep(0.42, 0.95, dist) * soft_vignette;
	vec3 angelic = base;
	angelic = mix(angelic, vec3(dot(angelic, vec3(0.299, 0.587, 0.114))), 0.52);
	angelic += white_tint.rgb * center_halo * bloom_white * (0.55 + pulse * 0.45);
	angelic = mix(angelic, noise_col, grain_strength * opacity * (0.35 + center_halo * 0.35));
	angelic = mix(angelic, black_tint.rgb, edge_dark);

	COLOR = vec4(mix(base, angelic, opacity), 1.0);
}
