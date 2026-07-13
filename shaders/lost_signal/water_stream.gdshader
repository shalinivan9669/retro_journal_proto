shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.55, 0.82, 0.96, 0.34);
uniform float scroll_speed = 1.35;
uniform float ripple_scale = 54.0;

void fragment() {
	float ripple = sin((UV.y + TIME * scroll_speed) * ripple_scale) * 0.035;
	float edge = smoothstep(0.0, 0.13, UV.x) * smoothstep(0.0, 0.13, 1.0 - UV.x);
	ALBEDO = water_color.rgb + ripple;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	ALPHA = water_color.a * edge;
	NORMAL = normalize(vec3(ripple * 2.0, 0.0, 1.0));
}
