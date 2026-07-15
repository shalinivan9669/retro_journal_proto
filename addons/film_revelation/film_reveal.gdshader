shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D original_revealed_texture : source_color, filter_linear;

uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_active : hint_range(0.0, 1.0) = 0.0;
uniform float aim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float ghost_amount : hint_range(0.0, 0.25) = 0.06;
uniform float film_opacity : hint_range(0.0, 1.0) = 0.52;
uniform float exposure_gain : hint_range(0.0, 2.0) = 1.08;
uniform float bleach_low : hint_range(0.0, 1.0) = 0.56;
uniform float bleach_high : hint_range(0.0, 1.5) = 0.84;
uniform float aim_brightness_boost : hint_range(0.0, 0.5) = 0.28;
uniform float aim_contrast_boost : hint_range(0.0, 0.5) = 0.18;
uniform float capture_flash : hint_range(0.0, 1.0) = 0.0;
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

float calculate_reveal_mask(float field, float threshold, float chemical_progress) {
	float mask = 1.0 - smoothstep(threshold - 0.035, threshold + 0.035, field);
	// Keep the two source photographs completely separate while the film is idle.
	mask *= smoothstep(0.0, 0.018, chemical_progress);
	return clamp(mask, 0.0, 1.0);
}

float front_micro_dots(vec2 uv) {
	vec2 cell = floor(uv * vec2(520.0, 440.0));
	return step(0.992, hash21(cell + vec2(19.0, 43.0)));
}

float front_branch_tracks(vec2 uv) {
	float track_a = abs(value_noise(uv * vec2(96.0, 23.0) + vec2(4.3, 9.1)) - 0.5);
	float track_b = abs(value_noise(uv.yx * vec2(71.0, 29.0) + vec2(8.7, 2.4)) - 0.5);
	float narrow_track = 1.0 - smoothstep(0.006, 0.022, min(track_a, track_b));
	float short_segments = smoothstep(
		0.48,
		0.68,
		value_noise(uv * vec2(18.0, 31.0) + vec2(5.0))
	);
	return narrow_track * short_segments;
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

	// The chemical field is retained, but the 4.8 second timeline now has distinct
	// awakening, branching burn, photograph transition and stabilization phases.
	float chemical_progress = smoothstep(0.08, 0.72, reveal_progress);
	float photograph_progress = smoothstep(0.30, 0.90, reveal_progress);
	float stabilization = smoothstep(0.82, 1.0, reveal_progress);
	float completion_gate = 1.0 - step(0.999, reveal_progress);
	float field = emulsion_field(UV);
	float threshold = mix(-0.035, 1.08, chemical_progress);
	float inner_edge = exp(-pow((field - threshold) / 0.018, 2.0));
	float outer_edge = exp(-pow((field - threshold) / 0.060, 2.0));
	float front_activity = (
		reveal_active
		* smoothstep(0.06, 0.10, reveal_progress)
		* (1.0 - stabilization)
		* completion_gate
	);
	float branch_variation = 0.70 + value_noise(UV * 58.0 + vec2(7.0, 13.0)) * 0.30;
	inner_edge *= front_activity * branch_variation;
	outer_edge *= front_activity;

	// Only the narrow active front distorts the sheet, by roughly 0.22% in UV.
	vec2 warp_direction = vec2(
		value_noise(UV * 37.0 + vec2(2.3, 8.1)),
		value_noise(UV * 37.0 + vec2(9.4, 1.7))
	) - 0.5;
	warp_direction = normalize(warp_direction + vec2(0.0001));
	vec2 active_uv = clamp(
		UV + warp_direction * 0.0022 * outer_edge * completion_gate,
		vec2(0.0),
		vec2(1.0)
	);
	vec3 warped_negative = texture(TEXTURE, active_uv).rgb;
	vec3 warped_original = texture(original_revealed_texture, active_uv).rgb;
	float local_deformation = clamp(outer_edge * 0.72, 0.0, 1.0);

	// ghost_amount is a faint displaced echo of the initial negative only. It never
	// samples or previews original_revealed_texture before the chemical transition.
	vec2 ghost_uv = clamp(UV + vec2(0.0016, -0.0011), vec2(0.0), vec2(1.0));
	vec3 negative_ghost = texture(TEXTURE, ghost_uv).rgb;
	vec3 sharp_negative = negative_photo.rgb + (
		negative_ghost - negative_photo.rgb
	) * ghost_amount * 0.22;
	sharp_negative = mix(sharp_negative, warped_negative, local_deformation);

	// Aiming wakes the negative without advancing the chemical field: +28%
	// brightness, +18% contrast, then a silver-blue lift confined to highlights.
	vec3 aimed_negative = sharp_negative * mix(vec3(1.0), film_base_tint.rgb, 0.16);
	aimed_negative *= 1.0 + aim_strength * aim_brightness_boost;
	aimed_negative = (aimed_negative - vec3(0.5)) * (
		1.0 + aim_strength * aim_contrast_boost
	) + vec3(0.5);
	float aimed_luma = dot(aimed_negative, vec3(0.2126, 0.7152, 0.0722));
	float cold_highlights = smoothstep(0.42, 0.88, aimed_luma) * aim_strength;
	aimed_negative = mix(
		aimed_negative,
		aimed_negative * cold_negative_tint.rgb * 1.12,
		cold_highlights * 0.58
	);
	aimed_negative += vec3(0.88, 0.96, 1.0) * capture_flash;
	aimed_negative = clamp(aimed_negative, vec3(0.0), vec3(1.35));

	float developed_mask = calculate_reveal_mask(field, threshold, chemical_progress);
	float reveal_mask = developed_mask * photograph_progress;
	vec3 transition_original = mix(
		original_photo.rgb,
		warped_original,
		local_deformation
	);
	vec3 transformed_photo = mix(aimed_negative, transition_original, reveal_mask);

	// A short dark/desaturated wake follows immediately behind the cold front and
	// disappears as the supplied photograph stabilizes.
	float behind_front = threshold - field;
	float trailing_band = smoothstep(0.004, 0.020, behind_front) * (
		1.0 - smoothstep(0.052, 0.125, behind_front)
	);
	trailing_band *= front_activity * (1.0 - photograph_progress * 0.72);
	float transition_luma = dot(transformed_photo, vec3(0.2126, 0.7152, 0.0722));
	vec3 exhausted_emulsion = vec3(transition_luma) * vec3(0.68, 0.72, 0.76);
	transformed_photo = mix(transformed_photo, exhausted_emulsion, trailing_band * 0.58);

	// Sparse micro-dots and short branching tracks exist only inside the two front
	// bands. The peak is intentionally HDR-bright, but remains cold white/cyan.
	float micro_dots = front_micro_dots(UV) * inner_edge;
	float branch_tracks = front_branch_tracks(UV) * outer_edge;
	float chemical_pulse = 0.96 + sin(time_sec * 11.0) * 0.04;
	vec3 front_emission = reveal_edge_tint.rgb * chemical_pulse * (
		inner_edge * 1.32
		+ outer_edge * 0.30
		+ micro_dots * 0.92
		+ branch_tracks * 0.44
	);
	float awakening_flash = exp(-pow((reveal_progress - 0.045) / 0.028, 2.0));
	awakening_flash *= reveal_active * completion_gate;
	transformed_photo += front_emission;
	transformed_photo += vec3(0.90, 0.97, 1.08) * awakening_flash * 0.86;

	// The idle sheet has a very slight edge vignette. It is gone before the final
	// clean original, while the alpha edge below keeps the card physically legible.
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_interior = smoothstep(0.0, 0.028, edge_distance);
	float idle_edge_shade = (1.0 - edge_interior) * 0.045 * completion_gate * (
		1.0 - photograph_progress
	);
	transformed_photo *= 1.0 - idle_edge_shade;

	// At completion the supplied original is exact: every chemical overlay, local
	// deformation, ghost, tint and procedural trace is forcibly removed.
	if (reveal_progress >= 0.999) {
		transformed_photo = original_photo.rgb;
	}

	// External light is independent from aiming and development.  Bright moonlight,
	// tracers and explosions physically bleach either source photograph.
	float incident_luminance = screen_luminance(SCREEN_UV) * exposure_gain;
	float light_bleach = smoothstep(bleach_low, bleach_high, incident_luminance);
	vec3 final_color = mix(transformed_photo, vec3(0.965, 0.975, 0.99), light_bleach * 0.94);

	float photo_luma = dot(transformed_photo, vec3(0.2126, 0.7152, 0.0722));
	float physical_alpha = mix(0.48, 0.82, clamp(photo_luma, 0.0, 1.0));
	physical_alpha += film_opacity - 0.52;
	physical_alpha *= mix(0.64, 1.0, edge_interior);
	physical_alpha += inner_edge * 0.07 + light_bleach * 0.10;
	float final_alpha = clamp(physical_alpha, 0.30, 0.92);
	COLOR = vec4(final_color, final_alpha * equip_alpha);
}
