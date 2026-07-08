shader_type sky;

uniform sampler2D source_panorama;
uniform vec3 fallback_low : source_color = vec3(0.30, 0.28, 0.26);
uniform vec3 fallback_high : source_color = vec3(0.07, 0.075, 0.09);
uniform vec3 blood_tint : source_color = vec3(0.45, 0.08, 0.045);
uniform float panorama_strength : hint_range(0.0, 1.0) = 0.75;
uniform float blood_amount : hint_range(0.0, 1.0) = 0.18;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.38;
uniform float cloud_scale : hint_range(0.1, 20.0) = 4.0;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.015;
uniform float lightning_flash : hint_range(0.0, 1.0) = 0.0;
uniform float exposure : hint_range(0.1, 5.0) = 1.05;

const float PI_CONST = 3.14159265359;
const float TAU_CONST = 6.28318530718;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec2 uv = vec2(atan(dir.x, dir.z) / TAU_CONST + 0.5, asin(clamp(dir.y, -1.0, 1.0)) / PI_CONST + 0.5);
	vec3 grad = mix(fallback_low, fallback_high, smoothstep(0.0, 1.0, uv.y));
	vec3 pano = texture(source_panorama, uv).rgb;
	vec3 col = mix(grad, pano, panorama_strength);

	vec2 cloud_uv = uv * vec2(cloud_scale, cloud_scale * 0.55) + vec2(TIME * cloud_speed, 0.0);
	float c = noise2(cloud_uv) * 0.55 + noise2(cloud_uv * 2.3 + 4.1) * 0.30 + noise2(cloud_uv * 5.4 + 1.7) * 0.15;
	float clouds = smoothstep(0.46, 0.82, c) * cloud_amount;
	col = mix(col, col * 0.55 + vec3(0.08, 0.075, 0.07), clouds);

	col = mix(col, blood_tint, blood_amount * smoothstep(0.15, 0.95, uv.y));
	col += vec3(0.65, 0.72, 0.9) * lightning_flash;
	COLOR = col * exposure;
}
