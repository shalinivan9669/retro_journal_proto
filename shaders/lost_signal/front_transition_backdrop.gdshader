shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D left_panorama : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D left_emissive : source_color, filter_linear_mipmap;
uniform sampler2D right_panorama : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D right_emissive : source_color, filter_linear_mipmap;
uniform vec4 left_uv_rect = vec4(0.50, 0.02, 0.326, 0.96);
uniform vec4 right_uv_rect = vec4(0.03, 0.02, 0.326, 0.96);
uniform float blend_start : hint_range(0.0, 1.0) = 0.62;
uniform float blend_end : hint_range(0.0, 1.0) = 0.90;
uniform float exposure : hint_range(0.05, 2.0) = 0.60;
uniform float emissive_strength : hint_range(0.0, 2.0) = 0.15;
uniform vec3 haze_color : source_color = vec3(0.025, 0.070, 0.090);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.12;
uniform float top_fade_start : hint_range(0.0, 1.0) = 0.12;
uniform float top_fade_end : hint_range(0.0, 1.0) = 0.58;
uniform float side_fade_width : hint_range(0.0, 0.25) = 0.13;


void fragment() {
	vec2 left_uv = clamp(left_uv_rect.xy + UV * left_uv_rect.zw, vec2(0.0), vec2(1.0));
	vec2 right_uv = clamp(right_uv_rect.xy + UV * right_uv_rect.zw, vec2(0.0), vec2(1.0));
	vec3 left_color = texture(left_panorama, left_uv).rgb;
	vec3 right_color = texture(right_panorama, right_uv).rgb;
	vec3 left_lights = texture(left_emissive, left_uv).rgb;
	vec3 right_lights = texture(right_emissive, right_uv).rgb;
	float blend_factor = smoothstep(blend_start, blend_end, UV.x);
	vec3 base = mix(left_color, right_color, blend_factor);
	vec3 lights = mix(left_lights, right_lights, blend_factor);
	float vertical_haze = smoothstep(0.45, 0.92, UV.y) * haze_amount;
	float vertical_alpha = smoothstep(top_fade_start, top_fade_end, UV.y);
	float left_alpha = smoothstep(0.0, side_fade_width, UV.x);
	float right_alpha = smoothstep(0.0, side_fade_width, 1.0 - UV.x);

	ALBEDO = mix(base * exposure, haze_color, vertical_haze);
	EMISSION = lights * emissive_strength;
	ALPHA = vertical_alpha * left_alpha * right_alpha;
}
