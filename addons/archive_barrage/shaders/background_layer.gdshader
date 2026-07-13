shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D layer_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float flash_level = 0.0;

void fragment() {
	vec4 source = texture(layer_texture, UV);
	vec3 color = source.rgb * tint;
	ALBEDO = color * mix(1.0, 1.55, flash_level);
	EMISSION = color * flash_level * 0.22;
	ALPHA = source.a * opacity;
}
