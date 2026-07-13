shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

instance uniform vec4 ground_color : source_color = vec4(1.0);
instance uniform float ground_diameter = 1.0;
instance uniform float ground_energy = 0.0;
instance uniform float ground_opacity = 0.0;
instance uniform float ring_progress = 0.0;
instance uniform float dust_progress = 0.0;
instance uniform float burst_seed = 0.0;


float hash_21(vec2 point) {
	vec3 value = fract(vec3(point.xyx) * vec3(0.1031, 0.1030, 0.0973));
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	float corner_00 = hash_21(cell);
	float corner_10 = hash_21(cell + vec2(1.0, 0.0));
	float corner_01 = hash_21(cell + vec2(0.0, 1.0));
	float corner_11 = hash_21(cell + vec2(1.0, 1.0));
	return mix(mix(corner_00, corner_10, blend.x), mix(corner_01, corner_11, blend.x), blend.y);
}


void vertex() {
	vec2 ground_offset = (UV - vec2(0.5)) * ground_diameter;
	vec3 center_world = MODEL_MATRIX[3].xyz;
	vec3 vertex_world = center_world + vec3(ground_offset.x, 0.0, ground_offset.y);
	VERTEX = (VIEW_MATRIX * vec4(vertex_world, 1.0)).xyz;
}


void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float radius = length(centered_uv);
	float inside = 1.0 - smoothstep(0.47, 0.505, radius);

	float ring_radius = mix(0.025, 0.455, clamp(ring_progress, 0.0, 1.0));
	float ring_width = mix(0.020, 0.048, clamp(ring_progress, 0.0, 1.0));
	float ring = 1.0 - smoothstep(ring_width, ring_width + 0.016, abs(radius - ring_radius));
	ring *= inside;

	vec2 noise_uv = centered_uv * 19.0 + vec2(burst_seed * 0.013, burst_seed * 0.021);
	float coarse_noise = value_noise(noise_uv);
	float fine_noise = value_noise(noise_uv * 2.37 + vec2(7.1, -4.3));
	float dust_noise = smoothstep(0.24, 0.82, coarse_noise * 0.68 + fine_noise * 0.32);
	float dust_radius = mix(0.035, 0.39, clamp(dust_progress, 0.0, 1.0));
	float dust_band_width = mix(0.12, 0.19, clamp(dust_progress, 0.0, 1.0));
	float dust_band = 1.0 - smoothstep(
		dust_band_width,
		dust_band_width + 0.08,
		abs(radius - dust_radius)
	);
	float center_dust = (1.0 - smoothstep(0.0, 0.34, radius)) * (1.0 - dust_progress);
	float dust = max(dust_band * dust_noise, center_dust * dust_noise * 0.46) * inside;

	float mask = clamp(ring + dust * 0.42, 0.0, 1.0);
	float emission_weight = mix(0.16, 1.0, clamp(ring, 0.0, 1.0));
	ALBEDO = vec3(0.0);
	EMISSION = ground_color.rgb * ground_energy * emission_weight;
	ALPHA = mask * ground_opacity * ground_color.a;
}
