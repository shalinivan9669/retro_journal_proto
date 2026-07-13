shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D smoke_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float density = 0.72;
uniform float flash_energy = 0.0;

void fragment() {
	vec4 smoke = texture(smoke_atlas, UV);
	float alpha = pow(smoke.a, 1.24) * density;
	ALBEDO = vec3(0.16, 0.165, 0.17);
	ROUGHNESS = 1.0;
	EMISSION = vec3(1.0) * flash_energy * alpha;
	ALPHA = alpha;
}
