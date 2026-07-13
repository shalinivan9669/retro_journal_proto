shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform sampler2D sky_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float energy = 0.72;

void fragment() {
	vec3 sky = texture(sky_texture, UV).rgb;
	ALBEDO = sky * energy;
}
