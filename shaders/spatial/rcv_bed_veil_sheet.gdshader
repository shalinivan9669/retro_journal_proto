shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 veil_color : source_color = vec4(1.0, 0.98, 0.90, 0.18);
uniform float density : hint_range(0.0, 2.0) = 0.72;
uniform float drift_speed : hint_range(0.0, 2.0) = 0.18;
uniform float grain_scale : hint_range(1.0, 80.0) = 22.0;

float hash(vec2 p) {
	p = fract(p * vec2(133.3, 277.7));
	p += dot(p, p + 31.31);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
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
	float t = TIME * drift_speed;
	float n = noise(UV * vec2(grain_scale, grain_scale * 0.42) + vec2(t, -t * 0.6));
	float edge = smoothstep(0.0, 0.14, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
	edge *= smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
	float oval = 1.0 - smoothstep(0.18, 0.72, length((UV - vec2(0.5)) * vec2(1.0, 1.45)));
	float alpha = clamp(veil_color.a * density * edge * (oval * 0.65 + n * 0.45), 0.0, 0.42);
	ALBEDO = veil_color.rgb;
	EMISSION = veil_color.rgb * alpha * 0.8;
	ALPHA = alpha;
}
