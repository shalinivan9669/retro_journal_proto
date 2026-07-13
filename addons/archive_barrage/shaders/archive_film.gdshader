shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_strength = 0.026;
uniform float vignette_strength = 0.04;
uniform float barrel_distortion = -0.025;
uniform float viewport_aspect = 1.7777778;
uniform float wall_time = 0.0;
uniform float retina_level = 0.0;
uniform float flash_peak = 0.0;
uniform vec3 retina_spot_0 = vec3(0.5, 0.5, 0.0);
uniform vec3 retina_spot_1 = vec3(0.5, 0.5, 0.0);
uniform vec3 retina_spot_2 = vec3(0.5, 0.5, 0.0);
uniform vec3 retina_spot_3 = vec3(0.5, 0.5, 0.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float retina_spot(vec2 uv, vec3 spot, float aspect) {
	vec2 d = uv - spot.xy;
	d.x *= aspect;
	float distance_squared = dot(d, d);
	float core = exp(-distance_squared / 0.012);
	float soft_halo = exp(-distance_squared / 0.052) * 0.22;
	return spot.z * (core + soft_halo);
}

void fragment() {
	float aspect = max(viewport_aspect, 0.1);
	vec2 p = SCREEN_UV - vec2(0.5);
	float r2 = dot(p, p);
	vec2 distorted_uv = vec2(0.5) + p * (1.0 + barrel_distortion * r2);
	distorted_uv = clamp(distorted_uv, vec2(0.001), vec2(0.999));
	vec3 source = texture(screen_texture, distorted_uv).rgb;

	float luminance = max(dot(source, vec3(0.22, 0.70, 0.08)), 0.0);
	float shadow_toe = 0.012 * (1.0 - smoothstep(0.015, 0.24, luminance));
	float image = pow(luminance + shadow_toe, 0.92);
	float shoulder = max(image - 0.72, 0.0);
	image /= 1.0 + shoulder * 0.22;

	float frame = floor(wall_time * 18.0);
	float exposure_flicker = 1.0 + sin(wall_time * 2.7) * 0.004;
	exposure_flicker += (hash21(vec2(frame, 11.0)) - 0.5) * 0.008;
	image *= exposure_flicker;

	float local_afterimage = retina_spot(SCREEN_UV, retina_spot_0, aspect);
	local_afterimage += retina_spot(SCREEN_UV, retina_spot_1, aspect);
	local_afterimage += retina_spot(SCREEN_UV, retina_spot_2, aspect);
	local_afterimage += retina_spot(SCREEN_UV, retina_spot_3, aspect);
	local_afterimage = clamp(local_afterimage, 0.0, 1.25);
	image *= 1.0 - retina_level * 0.44;

	float fine_grain = hash21(FRAGCOORD.xy + frame * 17.0);
	float coarse_grain = hash21(floor(FRAGCOORD.xy * 0.5) + frame * 7.0);
	float grain = mix(fine_grain, coarse_grain, 0.30) - 0.5;
	float local_grain = mix(grain_strength, grain_strength * 0.30, smoothstep(0.16, 0.84, image));
	image += grain * local_grain * 2.0;

	float dust_frame = floor(wall_time * 8.0);
	vec2 dust_cell = floor(FRAGCOORD.xy / 5.0);
	float dust_seed = hash21(dust_cell + vec2(dust_frame * 13.0, dust_frame * 3.0));
	float dust_shape = 1.0 - smoothstep(0.12, 0.48, length(fract(FRAGCOORD.xy / 5.0) - 0.5));
	float white_dust = step(0.9982, dust_seed) * dust_shape;
	float black_dust = step(0.9989, hash21(dust_cell + vec2(dust_frame * 5.0, 71.0))) * dust_shape;
	image += white_dust * 0.10;
	image -= black_dust * 0.07;

	float scratch_frame = floor(wall_time * 2.4);
	float scratch_active = step(0.82, hash21(vec2(scratch_frame, 37.0)));
	float scratch_x = hash21(vec2(scratch_frame, 83.0));
	float scratch = exp(-abs(SCREEN_UV.x - scratch_x) * 920.0);
	scratch *= scratch_active * smoothstep(0.02, 0.16, SCREEN_UV.y) * (1.0 - smoothstep(0.82, 0.99, SCREEN_UV.y));
	image += scratch * 0.045;

	vec2 vignette_uv = SCREEN_UV - vec2(0.5);
	vignette_uv.x *= aspect;
	float vignette = 1.0 - vignette_strength * smoothstep(0.32, 0.82, length(vignette_uv));
	image *= vignette;
	image = clamp(image, 0.0, 1.0);

	vec3 silver_shadow = vec3(0.975, 0.990, 1.015);
	vec3 sepia_mid = vec3(1.030, 1.005, 0.955);
	vec3 film_tint = mix(silver_shadow, sepia_mid, smoothstep(0.08, 0.58, image));
	vec3 film_color = vec3(image) * film_tint;
	float neutral_highlight = smoothstep(0.66, 0.94, image);
	film_color = mix(film_color, vec3(image), neutral_highlight);

	float neutral_flash = clamp(flash_peak * 0.18 + local_afterimage * 0.48, 0.0, 0.88);
	film_color = mix(film_color, vec3(1.0), neutral_flash);
	COLOR = vec4(clamp(film_color, vec3(0.0), vec3(1.0)), 1.0);
}
