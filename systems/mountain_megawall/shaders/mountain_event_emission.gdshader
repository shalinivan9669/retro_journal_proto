shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform int event_kind = 2;
uniform float start_time = 0.0;
uniform float duration = 6.0;
uniform float intensity = 0.14;
uniform vec4 event_color : source_color = vec4(0.55, 0.70, 1.0, 1.0);

void fragment() {
	float age = max(TIME - start_time, 0.0);
	float life = clamp(age / max(duration, 0.001), 0.0, 1.0);
	float fade = smoothstep(0.0, 0.14, life) * (1.0 - smoothstep(0.72, 1.0, life));

	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float core = exp(-d * d * 5.0);
	float alpha = core;
	float pulse = 0.55 + 0.45 * sin(age * 6.28318 / max(duration * 0.38, 0.1));
	vec3 color = event_color.rgb;

	if (event_kind == 1) {
		float fork = smoothstep(0.98, 1.0, sin(UV.x * 34.0 + UV.y * 17.0 + age * 18.0));
		pulse = smoothstep(0.02, 0.16, life) * (1.0 - smoothstep(0.20, 0.55, life));
		alpha = max(core * 0.35, fork * 0.25);
	} else if (event_kind == 3) {
		pulse = step(0.72, fract(age * 1.45));
		alpha = core * pulse;
	} else if (event_kind == 4) {
		float smear = smoothstep(0.95, 0.05, abs(p.y)) * smoothstep(1.0, -0.2, p.x);
		float drift = 0.55 + 0.45 * sin((UV.x + age * 0.03) * 31.0 + UV.y * 8.0);
		alpha = smear * drift * 0.55;
		pulse = 0.55 + life * 0.25;
	} else {
		float flicker = 0.80 + 0.20 * sin(age * 19.0 + UV.x * 13.0);
		pulse *= flicker;
	}

	ALBEDO = color * intensity * pulse * fade;
	ALPHA = alpha * intensity * pulse * fade;
}
