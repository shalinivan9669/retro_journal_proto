shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D source_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 fallback_low : source_color = vec3(0.30, 0.28, 0.26);
uniform vec3 fallback_high : source_color = vec3(0.07, 0.075, 0.09);
uniform float panorama_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 aurora_color_a : source_color = vec3(0.24, 0.55, 0.42);
uniform vec3 aurora_color_b : source_color = vec3(0.18, 0.34, 0.56);
uniform float aurora_strength : hint_range(0.0, 1.0) = 0.38;
uniform float aurora_speed : hint_range(0.0, 0.25) = 0.028;
uniform float aurora_scale : hint_range(1.0, 18.0) = 7.0;
uniform float aurora_softness : hint_range(0.02, 0.35) = 0.14;
uniform float exposure : hint_range(0.1, 3.0) = 1.0;

varying vec3 dome_dir;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise2(p) * amp;
		p = p * 2.03 + vec2(7.13, 3.71);
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	dome_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

void fragment() {
	vec3 dir = normalize(dome_dir);
	float up = clamp(dir.y, 0.0, 1.0);
	vec2 uv = UV;

	vec3 panorama = texture(source_panorama, uv).rgb;
	vec3 gradient = mix(fallback_low, fallback_high, smoothstep(0.0, 1.0, up));
	vec3 sky_color = mix(gradient, panorama, panorama_strength);

	float t = TIME * aurora_speed;
	float n = fbm(vec2(uv.x * aurora_scale + t * 0.65, up * 5.2));
	float slow_wave = sin(uv.x * 10.8 + t * 5.4 + n * 2.8);
	float center_a = 0.58 + slow_wave * 0.055;
	float center_b = 0.76 + sin(uv.x * 15.5 - t * 3.7 + n * 2.1) * 0.045;

	float ribbon_a = 1.0 - smoothstep(0.025, aurora_softness, abs(up - center_a));
	float ribbon_b = 1.0 - smoothstep(0.020, aurora_softness * 0.82, abs(up - center_b));
	float curtain_noise = fbm(vec2(uv.x * aurora_scale * 1.8 - t * 0.9, up * 12.0 + n));
	float curtain = smoothstep(0.42, 0.86, curtain_noise);
	float top_fade = smoothstep(0.34, 0.54, up) * (1.0 - smoothstep(0.95, 1.0, up));
	float horizon_breakup = smoothstep(0.12, 0.92, fbm(vec2(uv.x * 3.5 + t, 2.0)));
	float aurora = clamp((ribbon_a + ribbon_b * 0.62) * curtain * top_fade * horizon_breakup * aurora_strength, 0.0, 1.0);

	vec3 aurora_color = mix(aurora_color_a, aurora_color_b, smoothstep(0.35, 0.95, n));
	vec3 color = sky_color + aurora_color * aurora;
	color = mix(color, sky_color * 0.72 + aurora_color * 0.45, aurora * 0.18);

	ALBEDO = clamp(color * exposure, vec3(0.0), vec3(1.0));
}
