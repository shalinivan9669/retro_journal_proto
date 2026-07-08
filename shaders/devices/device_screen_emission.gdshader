shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 screen_color : source_color = vec3(0.42, 0.75, 1.0);
uniform float emission_power : hint_range(0.0, 8.0) = 1.65;
uniform float flicker_strength : hint_range(0.0, 0.5) = 0.045;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.06;
uniform float scanline_density : hint_range(50.0, 1400.0) = 520.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.35;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float scanline = sin(UV.y * scanline_density) * scanline_strength;
	float flicker = sin(TIME * 17.0) * flicker_strength
		+ sin(TIME * 43.0) * flicker_strength * 0.45
		+ (hash(floor(TIME * 14.0)) - 0.5) * flicker_strength * 0.35;

	vec3 col = screen_color + vec3(scanline + flicker);
	col = max(col, vec3(0.0));

	ALBEDO = col * 0.16;
	EMISSION = col * emission_power;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
