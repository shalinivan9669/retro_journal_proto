shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D layer_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
uniform vec3 tint = vec3(1.0);

void fragment() {
	vec4 source = texture(layer_texture, UV);
	ALBEDO = source.rgb * tint;
	ALPHA = source.a * opacity;
}
