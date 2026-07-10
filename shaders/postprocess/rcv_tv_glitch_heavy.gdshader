shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float opacity : hint_range(0.0, 1.0) = 0.78;
uniform float split : hint_range(0.0, 0.08) = 0.018;
uniform float horizontal_tear : hint_range(0.0, 0.12) = 0.035;
uniform float wave_strength : hint_range(0.0, 0.08) = 0.018;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.32;
uniform float roll_speed : hint_range(0.0, 14.0) = 4.8;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.34;
uniform float blackout_chance : hint_range(0.0, 1.0) = 0.18;
uniform vec4 phosphor_tint : source_color = vec4(0.62, 0.95, 0.86, 1.0);

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float band_noise(float y, float t) {
	float cell = floor(y * 62.0 + t * 8.0);
	return rand(vec2(cell, floor(t * 11.0)));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float band = sin((uv.y + t * roll_speed * 0.018) * 86.0);
	float coarse = band_noise(uv.y, t);
	float tear_gate = step(0.82, coarse);
	float tear = (coarse - 0.5) * horizontal_tear * tear_gate;
	uv.x += band * wave_strength + tear;
	uv.y += sin(uv.x * 22.0 + t * 3.0) * wave_strength * 0.25;

	vec3 base = texture(screen_texture, SCREEN_UV).rgb;
	float r = texture(screen_texture, uv + vec2(split * (1.0 + tear_gate), 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(split * 0.72, 0.0)).b;
	vec3 glitch = vec3(r, g, b);

	float scan = sin(SCREEN_UV.y * 1250.0) * scanline_strength;
	float static_noise = (rand(SCREEN_UV * vec2(1280.0, 720.0) + floor(t * 40.0)) - 0.5) * noise_strength;
	float white_spark = step(0.992, rand(SCREEN_UV * vec2(420.0, 260.0) + floor(t * 18.0))) * 0.85;
	float blackout = step(1.0 - blackout_chance * 0.13, rand(vec2(floor(t * 7.0), 19.0)));
	glitch += static_noise + scan + white_spark;
	glitch *= mix(1.0, 0.22, blackout);
	glitch = mix(glitch, glitch * phosphor_tint.rgb, 0.26);

	COLOR.rgb = mix(base, glitch, opacity);
	COLOR.a = 1.0;
}
