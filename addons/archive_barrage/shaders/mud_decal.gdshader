shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D mud_mask : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 0.82;

void fragment() {
	float mask = texture(mud_mask, UV).a;
	ALBEDO = vec3(0.018, 0.017, 0.015);
	ROUGHNESS = 0.46;
	SPECULAR = 0.34;
	METALLIC = 0.0;
	ALPHA = mask * opacity;
}
