shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float split : hint_range(0.0, 0.04) = 0.007;
uniform float wave_strength : hint_range(0.0, 0.04) = 0.006;
uniform float noise_strength : hint_range(0.0, 0.4) = 0.08;
uniform float roll_speed : hint_range(0.0, 8.0) = 1.6;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.12;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = sin((uv.y + TIME * roll_speed * 0.03) * 44.0);
	float tear = step(0.965, rand(vec2(floor(uv.y * 80.0), floor(TIME * 12.0)))) * 0.02;
	uv.x += band * wave_strength + tear;

	vec3 base = texture(screen_texture, SCREEN_UV).rgb;
	float r = texture(screen_texture, uv + vec2(split, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(split, 0.0)).b;
	vec3 glitch = vec3(r, g, b);

	float scan = sin(SCREEN_UV.y * 900.0) * scanline_strength;
	float noise = (rand(SCREEN_UV * TIME * 140.0) - 0.5) * noise_strength;
	glitch += scan + noise;

	COLOR.rgb = mix(base, glitch, opacity);
	COLOR.a = 1.0;
}
