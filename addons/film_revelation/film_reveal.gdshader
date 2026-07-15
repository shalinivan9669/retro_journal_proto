shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D original_revealed_texture : source_color, filter_linear;

uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_active : hint_range(0.0, 1.0) = 0.0;
uniform float aim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float ghost_amount : hint_range(0.0, 0.25) = 0.06;
uniform float film_opacity : hint_range(0.0, 1.0) = 0.38;
uniform float exposure_gain : hint_range(0.0, 2.0) = 1.08;
uniform float bleach_low : hint_range(0.0, 1.0) = 0.56;
uniform float bleach_high : hint_range(0.0, 1.5) = 0.84;
uniform float time_sec = 0.0;
uniform float equip_alpha : hint_range(0.0, 1.0) = 0.0;

uniform vec4 cold_negative_tint : source_color = vec4(0.69, 0.82, 0.94, 1.0);
uniform vec4 film_base_tint : source_color = vec4(0.43, 0.52, 0.60, 1.0);
uniform vec4 reveal_edge_tint : source_color = vec4(0.78, 0.91, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	mat2 rotation = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 5; i++) {
		sum += amplitude * value_noise(p);
		p = rotation * p * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.5;
	}
	return sum;
}

float emulsion_field(vec2 uv) {
	vec2 warp = vec2(
		fbm(uv * 5.2 + vec2(1.7, 8.3)),
		fbm(uv * 5.2 + vec2(9.2, 2.1))
	) - 0.5;
	vec2 p = uv + warp * 0.095;

	float seed_a = length((p - vec2(0.27, 0.38)) * vec2(0.90, 1.16));
	float seed_b = length((p - vec2(0.72, 0.56)) * vec2(1.05, 0.92)) + 0.055;
	float seed_c = length((p - vec2(0.47, 0.82)) * vec2(1.24, 0.78)) + 0.13;
	float radial = min(seed_a, min(seed_b, seed_c));

	// Thin discontinuities pull the front into branching photographic tracks.
	float ridges = abs(value_noise(p * vec2(18.0, 11.0)) - 0.5);
	float channels = 1.0 - smoothstep(0.018, 0.11, ridges);
	float coarse = fbm(p * 8.0 + vec2(14.0)) - 0.5;
	return clamp(radial * 1.32 + coarse * 0.20 - channels * 0.075, 0.0, 1.0);
}

float calculate_reveal_mask(vec2 uv, float progress) {
	float field = emulsion_field(uv);
	float threshold = mix(-0.035, 1.08, progress);
	float mask = 1.0 - smoothstep(threshold - 0.035, threshold + 0.035, field);
	// Keep the two source photographs completely separate while the film is idle.
	mask *= smoothstep(0.0, 0.018, progress);
	return clamp(mask, 0.0, 1.0);
}

float screen_luminance(vec2 screen_uv) {
	vec2 pixel = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 weights = vec3(0.2126, 0.7152, 0.0722);
	float center = dot(textureLod(screen_texture, screen_uv, 1.5).rgb, weights);
	float ring = 0.0;
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2( 9.0,  0.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2(-9.0,  0.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2( 0.0,  9.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2( 0.0, -9.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2( 7.0,  7.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2(-7.0,  7.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2( 7.0, -7.0), 2.0).rgb, weights);
	ring += dot(textureLod(screen_texture, screen_uv + pixel * vec2(-7.0, -7.0), 2.0).rgb, weights);
	return max(center, ring * 0.125);
}

void fragment() {
	// Both photographs are sampled sharply at their native UI LOD.  textureLod is
	// deliberately reserved for the world-luminance probe in screen_luminance().
	vec4 negative_photo = texture(TEXTURE, UV);
	vec4 original_photo = texture(original_revealed_texture, UV);

	// The undeveloped sheet stays recognisably photographic.  Aiming only wakes up
	// the negative; it does not advance the chemical reveal mask.
	vec3 aimed_negative = negative_photo.rgb * vec3(0.92, 0.95, 1.0);
	aimed_negative *= 1.0 + aim_strength * 0.12;
	aimed_negative = (aimed_negative - vec3(0.5)) * (1.0 + aim_strength * 0.08) + vec3(0.5);
	aimed_negative = clamp(aimed_negative, vec3(0.0), vec3(1.0));

	float reveal_mask = calculate_reveal_mask(UV, reveal_progress);
	vec3 transformed_photo = mix(aimed_negative, original_photo.rgb, reveal_mask);

	// At completion the supplied original is exact: no tint, grain, edge colour or
	// procedural field remains over the photograph.
	if (reveal_progress >= 0.999) {
		transformed_photo = original_photo.rgb;
	}

	float field = emulsion_field(UV);
	float threshold = mix(-0.035, 1.08, reveal_progress);
	float front_distance = abs(field - threshold);
	float active_edge = exp(-pow(front_distance / 0.027, 2.0));
	active_edge *= reveal_active * (0.38 + 0.62 * value_noise(UV * 55.0 + vec2(time_sec * 0.7)));
	active_edge *= 1.0 - step(0.999, reveal_progress);
	transformed_photo = mix(
		transformed_photo,
		reveal_edge_tint.rgb,
		active_edge * 0.32
	);

	// External light is independent from aiming and development.  Bright moonlight,
	// tracers and explosions physically bleach either source photograph.
	float incident_luminance = screen_luminance(SCREEN_UV) * exposure_gain;
	float light_bleach = smoothstep(bleach_low, bleach_high, incident_luminance);
	vec3 final_color = mix(transformed_photo, vec3(0.965, 0.975, 0.99), light_bleach * 0.94);

	float photo_luma = dot(transformed_photo, vec3(0.2126, 0.7152, 0.0722));
	float physical_alpha = 0.34 + photo_luma * 0.32 + (film_opacity - 0.38);
	physical_alpha += active_edge * 0.06 + light_bleach * 0.16;
	float final_alpha = clamp(physical_alpha, 0.12, 0.86);
	COLOR = vec4(final_color, final_alpha * equip_alpha);
}
