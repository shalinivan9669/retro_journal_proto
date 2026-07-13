shader_type sky;

uniform sampler2D sky_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D hdri_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float energy = 1.0;
uniform float ibl_strength = 5.0;
uniform float visible_strength = 0.08;
uniform float star_strength = 0.72;
uniform vec2 moon_uv = vec2(0.63, 0.43);
uniform float moon_energy = 0.72;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	vec2 panorama_uv = vec2(
		fract(atan(direction.x, -direction.z) / (2.0 * PI) + 0.5),
		acos(clamp(direction.y, -1.0, 1.0)) / PI
	);
	vec3 archive_gradient = texture(sky_texture, panorama_uv).rgb;
	vec3 hdri = texture(hdri_texture, panorama_uv).rgb;
	vec3 hdri_mapped = hdri / (hdri + vec3(1.8));
	float hdri_luma = luminance(hdri_mapped);
	vec3 silver_hdri = mix(hdri_mapped, vec3(hdri_luma), 0.82);

	float horizon = smoothstep(0.02, 0.74, panorama_uv.y);
	vec3 night_floor = mix(vec3(0.020, 0.022, 0.027), vec3(0.034, 0.036, 0.043), horizon);
	vec3 sky = max(archive_gradient * 1.8, night_floor);
	float star_mask = smoothstep(0.08, 0.48, hdri_luma);
	sky += silver_hdri * star_mask * star_strength;

	vec2 moon_delta = panorama_uv - moon_uv;
	moon_delta.x = min(abs(moon_delta.x), 1.0 - abs(moon_delta.x));
	moon_delta.x *= 2.0;
	float moon_distance = length(moon_delta);
	float moon_disc = 1.0 - smoothstep(0.0045, 0.0065, moon_distance);
	float lit_half = smoothstep(-0.002, 0.0035, moon_delta.x);
	float moon_halo = exp(-moon_distance * moon_distance / 0.00038) * 0.035;
	vec3 moon = vec3(1.0, 0.985, 0.94) * (moon_disc * lit_half + moon_halo) * moon_energy;

	vec3 visible_sky = sky * energy + moon;
	// The cubemap pass feeds image-based lighting and can be brighter than the
	// directly visible night sky. This mimics a fully dark-adapted eye without
	// turning the sky itself into daylight.
	COLOR = visible_sky * (AT_CUBEMAP_PASS ? ibl_strength : visible_strength);
}
