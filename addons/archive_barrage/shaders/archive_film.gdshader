shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_strength = 0.033;
uniform float vignette_strength = 0.21;
uniform float barrel_distortion = -0.025;
uniform float viewport_aspect = 1.7777778;
uniform float retina_level = 0.0;
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
	return spot.z * exp(-dot(d, d) / 0.012);
}

void fragment() {
	float aspect = max(viewport_aspect, 0.1);
	vec2 p = SCREEN_UV - vec2(0.5);
	float r2 = dot(p, p);
	vec2 distorted_uv = vec2(0.5) + p * (1.0 + barrel_distortion * r2);
	vec3 source = texture(screen_texture, distorted_uv).rgb;

	float luminance = dot(source, vec3(0.22, 0.70, 0.08));
	float image = max(luminance - 0.016, 0.0);
	image = clamp((image - 0.18) * 1.20 + 0.18, 0.0, 1.0);
	image = pow(image, 0.94);

	float frame = floor(TIME * 18.0);
	float exposure_flicker = 1.0 + sin(TIME * 2.7) * 0.006;
	exposure_flicker += (hash21(vec2(frame, 11.0)) - 0.5) * 0.012;
	image *= exposure_flicker;

	float afterimage = retina_spot(distorted_uv, retina_spot_0, aspect);
	afterimage += retina_spot(distorted_uv, retina_spot_1, aspect);
	afterimage += retina_spot(distorted_uv, retina_spot_2, aspect);
	afterimage += retina_spot(distorted_uv, retina_spot_3, aspect);
	image *= 1.0 - retina_level * 0.32;
	image += retina_level * 0.18 + afterimage * 0.42;

	float fine_grain = hash21(FRAGCOORD.xy + frame * 17.0);
	float coarse_grain = hash21(floor(FRAGCOORD.xy * 0.5) + frame * 7.0);
	float grain = mix(fine_grain, coarse_grain, 0.32) - 0.5;
	float local_grain = mix(grain_strength, grain_strength * 0.35, smoothstep(0.15, 0.82, image));
	image += grain * local_grain * 2.0;

	float dust_frame = floor(TIME * 9.0);
	vec2 dust_cell = floor(FRAGCOORD.xy / 5.0);
	float dust_seed = hash21(dust_cell + vec2(dust_frame * 13.0, dust_frame * 3.0));
	float dust_shape = 1.0 - smoothstep(0.12, 0.48, length(fract(FRAGCOORD.xy / 5.0) - 0.5));
	float white_dust = step(0.9978, dust_seed) * dust_shape;
	float black_dust = step(0.9986, hash21(dust_cell + vec2(dust_frame * 5.0, 71.0))) * dust_shape;
	image += white_dust * 0.16;
	image -= black_dust * 0.12;

	float scratch_frame = floor(TIME * 2.8);
	float scratch_active = step(0.78, hash21(vec2(scratch_frame, 37.0)));
	float scratch_x = hash21(vec2(scratch_frame, 83.0));
	float scratch = exp(-abs(SCREEN_UV.x - scratch_x) * 880.0);
	scratch *= scratch_active * smoothstep(0.02, 0.16, SCREEN_UV.y) * (1.0 - smoothstep(0.82, 0.99, SCREEN_UV.y));
	image += scratch * 0.075;

	vec2 vignette_uv = SCREEN_UV - vec2(0.5);
	vignette_uv.x *= aspect;
	float vignette = 1.0 - vignette_strength * smoothstep(0.32, 0.76, length(vignette_uv));
	image *= vignette;

	vec3 silver = vec3(image * 0.965, image * 0.985, image * 1.015);
	COLOR = vec4(clamp(silver, vec3(0.0), vec3(1.0)), 1.0);
}
