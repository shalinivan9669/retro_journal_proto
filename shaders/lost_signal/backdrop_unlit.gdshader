shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D panorama_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D emissive_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float travel_uv_offset = 0.0;
uniform float exposure : hint_range(0.05, 2.0) = 0.62;
uniform float emissive_strength : hint_range(0.0, 2.0) = 0.16;
uniform vec3 haze_color : source_color = vec3(0.025, 0.075, 0.095);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.14;
uniform vec2 panorama_uv_scale = vec2(1.0);
uniform vec2 panorama_uv_offset = vec2(0.0);
uniform float top_fade_start : hint_range(0.0, 1.0) = 0.12;
uniform float top_fade_end : hint_range(0.0, 1.0) = 0.58;
uniform float side_fade_width : hint_range(0.0, 0.25) = 0.065;


void fragment() {
	vec2 sample_uv = vec2(
		fract((UV.x + travel_uv_offset) * panorama_uv_scale.x + panorama_uv_offset.x),
		clamp(UV.y * panorama_uv_scale.y + panorama_uv_offset.y, 0.0, 1.0)
	);
	vec3 base = texture(panorama_texture, sample_uv).rgb;
	vec3 lights = texture(emissive_texture, sample_uv).rgb;
	float vertical_haze = smoothstep(0.45, 0.92, UV.y) * haze_amount;
	float vertical_alpha = smoothstep(top_fade_start, top_fade_end, UV.y);
	float left_alpha = smoothstep(0.0, side_fade_width, UV.x);
	float right_alpha = smoothstep(0.0, side_fade_width, 1.0 - UV.x);

	ALBEDO = mix(base * exposure, haze_color, vertical_haze);
	EMISSION = lights * emissive_strength;
	ALPHA = vertical_alpha * left_alpha * right_alpha;
}
