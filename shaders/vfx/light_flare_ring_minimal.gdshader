shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 inner_color : source_color = vec3(0.55, 0.78, 1.0);
uniform vec3 outer_color : source_color = vec3(0.95, 0.38, 0.18);
uniform float emission_power : hint_range(0.0, 10.0) = 2.2;
uniform float ring_radius : hint_range(0.0, 1.0) = 0.42;
uniform float ring_width : hint_range(0.001, 0.4) = 0.055;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.1;
uniform float alpha_power : hint_range(0.1, 8.0) = 2.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float d = length(centered);
	float pulse = sin(TIME * pulse_speed) * 0.025;
	float ring = 1.0 - smoothstep(ring_width, ring_width * 2.1, abs(d - ring_radius - pulse));
	float core = 1.0 - smoothstep(0.0, 0.8, d);
	float streak = pow(max(0.0, 1.0 - abs(centered.y) * 8.0), 4.0) * (1.0 - smoothstep(0.15, 1.0, abs(centered.x)));

	vec3 col = mix(outer_color, inner_color, core);
	float a = clamp(ring + streak * 0.55 + core * 0.12, 0.0, 1.0);
	ALBEDO = col;
	EMISSION = col * emission_power * a;
	ALPHA = pow(a, alpha_power);
}
