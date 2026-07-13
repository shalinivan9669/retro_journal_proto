shader_type spatial;
render_mode cull_disabled;

uniform sampler2D puddle_mask : source_color, filter_linear_mipmap, repeat_disable;
uniform float roughness = 0.055;

void fragment() {
	float mask = texture(puddle_mask, UV).a;
	if (mask < 0.075) {
		discard;
	}
	ALBEDO = vec3(0.0045, 0.0050, 0.0055);
	ROUGHNESS = roughness;
	SPECULAR = 0.92;
	METALLIC = 0.0;
}
