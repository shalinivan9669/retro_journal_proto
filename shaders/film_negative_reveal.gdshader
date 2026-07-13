shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha, unshaded;

uniform sampler2D hidden_image : source_color, filter_linear_mipmap, repeat_disable;
uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float backlight_strength : hint_range(0.0, 4.0) = 1.25;
uniform float overexposure : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dark_film_color : source_color = vec3(0.028, 0.010, 0.006);
uniform vec3 backlight_color : source_color = vec3(1.0, 0.24, 0.028);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 source_image = texture(hidden_image, uv).rgb;
	float grain = hash21(uv * vec2(780.0, 440.0) + floor(TIME * 7.0));
	float scratch = sin((uv.x * 138.0 + hash21(vec2(floor(uv.x * 75.0), 9.0))) * 6.283) * 0.5 + 0.5;
	vec2 centered = uv * 2.0 - 1.0;
	float edge_mask = 1.0 - smoothstep(0.70, 1.13, length(centered * vec2(0.74, 1.0)));
	float reveal = smoothstep(0.07, 0.88, reveal_amount);
	float uneven = clamp(reveal + (grain - 0.5) * 0.15 + (scratch - 0.5) * 0.035, 0.0, 1.0);
	float image_visibility = uneven * edge_mask;
	vec3 negative = mix(backlight_color * 0.34, source_image, 0.84);
	vec3 final_color = mix(dark_film_color, negative, image_visibility);
	final_color += backlight_color * smoothstep(0.80, 1.0, reveal_amount) * overexposure * 0.16;
	ALBEDO = final_color;
	EMISSION = negative * image_visibility * backlight_strength;
	ALPHA = mix(0.92, 0.72, reveal) * (0.72 + edge_mask * 0.28);
}
