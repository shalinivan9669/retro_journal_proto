shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 dirt_color : source_color = vec4(0.040, 0.037, 0.034, 1.0);
uniform vec4 flash_tint : source_color = vec4(0.72, 0.78, 0.88, 1.0);
uniform float flash_energy = 0.0;

float hash11(float value) {
	return fract(sin(value * 127.1) * 43758.5453);
}

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float stream_cell = floor(UV.x * 19.0);
	float width_noise = mix(0.58, 1.0, hash11(stream_cell + COLOR.g * 113.0));
	float soft_edge = 1.0 - smoothstep(width_noise * 0.34, width_noise, across);
	float tail_fade = smoothstep(0.0, 0.18, UV.x);
	float head_fade = 1.0 - smoothstep(0.93, 1.0, UV.x);
	float breakup = mix(0.38, 1.0, hash11(stream_cell + COLOR.g * 97.0));
	float stream_opacity = COLOR.a * soft_edge * tail_fade * head_fade * breakup;
	float clod_distance = length(UV * 2.0 - 1.0);
	float clod_opacity = COLOR.a * (1.0 - smoothstep(0.46, 1.0, clod_distance));
	float opacity = mix(stream_opacity, clod_opacity, step(0.5, COLOR.b));

	ALBEDO = dirt_color.rgb * mix(0.62, 1.28, clamp(COLOR.r, 0.0, 1.0));
	ROUGHNESS = 0.96;
	SPECULAR = 0.14;
	METALLIC = 0.0;
	// Transparency already weights the final radiance. Multiplying emission by
	// opacity here as well would dim thin wet streams twice.
	EMISSION = flash_tint.rgb * flash_energy * COLOR.r;
	ALPHA = opacity;
}
