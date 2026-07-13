shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D puddle_mask : source_color, filter_linear_mipmap, repeat_disable;
uniform float roughness = 0.055;

void fragment() {
	float mask = smoothstep(0.07, 0.30, texture(puddle_mask, UV).a);
	ALBEDO = vec3(0.032, 0.036, 0.041);
	ROUGHNESS = max(roughness, 0.12);
	SPECULAR = 0.92;
	METALLIC = 0.0;
	ALPHA = mask * 0.58;
}
