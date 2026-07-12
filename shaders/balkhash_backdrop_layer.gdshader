shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D layer_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 color_modulate : source_color = vec4(1.0);
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float edge_fade : hint_range(0.0, 0.15) = 0.025;
uniform float fade_left : hint_range(0.0, 1.0) = 0.0;
uniform float fade_right : hint_range(0.0, 1.0) = 0.0;
uniform float red_shadow_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(layer_texture, UV);
	float left_fade = mix(1.0, smoothstep(0.0, edge_fade, UV.x), fade_left);
	float right_fade = mix(1.0, smoothstep(0.0, edge_fade, 1.0 - UV.x), fade_right);
	vec3 color = tex.rgb * color_modulate.rgb;
	color.r += red_shadow_strength * tex.a * 0.08;
	ALBEDO = color;
	ALPHA = tex.a * color_modulate.a * alpha_multiplier * left_fade * right_fade;
}
