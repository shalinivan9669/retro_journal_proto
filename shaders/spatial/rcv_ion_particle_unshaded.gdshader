shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 ion_color : source_color = vec4(1.0, 0.83, 0.42, 0.56);
uniform float core_power : hint_range(0.5, 8.0) = 2.4;
uniform float flicker : hint_range(0.0, 1.0) = 0.34;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float d = length(centered);
	float soft = pow(max(0.0, 1.0 - smoothstep(0.02, 0.52, d)), core_power);
	float n = hash(UV * 64.0 + floor(TIME * 30.0));
	float f = mix(1.0, n, flicker);
	ALBEDO = ion_color.rgb * f;
	EMISSION = ion_color.rgb * soft * f * 1.8;
	ALPHA = ion_color.a * soft * f;
}
