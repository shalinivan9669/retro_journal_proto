shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D terminal_image : source_color, filter_nearest_mipmap, repeat_disable;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phosphor_color : source_color = vec3(0.92, 0.96, 0.92);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	// Keep the portrait artwork intact within the landscape laptop display.
	const float IMAGE_WIDTH_FRACTION = 0.538;
	vec2 image_uv = vec2((UV.x - (1.0 - IMAGE_WIDTH_FRACTION) * 0.5) / IMAGE_WIDTH_FRACTION, UV.y);
	float image_mask = step(0.0, image_uv.x) * step(image_uv.x, 1.0);
	vec3 image_color = texture(terminal_image, clamp(image_uv, vec2(0.0), vec2(1.0))).rgb * image_mask;
	float mono = dot(image_color, vec3(0.299, 0.587, 0.114));
	float scanline = 0.88 + sin(UV.y * 520.0) * 0.06;
	float grain = (hash21(FRAGCOORD.xy + floor(TIME * 18.0)) - 0.5) * 0.045;
	float vignette = 1.0 - smoothstep(0.46, 0.78, length(UV * 2.0 - 1.0));
	float signal = max(0.0, mono * scanline + grain) * (0.68 + vignette * 0.32) * power;
	vec3 color = phosphor_color * signal;
	ALBEDO = color;
	EMISSION = color * (1.0 + power * 1.8);
}
