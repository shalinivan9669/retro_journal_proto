shader_type fog;

uniform vec3 fog_color : source_color = vec3(0.56, 0.45, 0.32);
uniform float density_multiplier : hint_range(0.0, 3.0) = 0.28;
uniform float noise_scale : hint_range(0.01, 2.0) = 0.14;
uniform float vertical_fade : hint_range(0.1, 12.0) = 5.0;
uniform float speed : hint_range(0.0, 2.0) = 0.22;
uniform float contrast : hint_range(0.1, 4.0) = 1.18;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i + vec3(0,0,0));
	float n100 = hash(i + vec3(1,0,0));
	float n010 = hash(i + vec3(0,1,0));
	float n110 = hash(i + vec3(1,1,0));
	float n001 = hash(i + vec3(0,0,1));
	float n101 = hash(i + vec3(1,0,1));
	float n011 = hash(i + vec3(0,1,1));
	float n111 = hash(i + vec3(1,1,1));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

void fog() {
	vec3 p = WORLD_POSITION * noise_scale + vec3(TIME * speed * 1.35, 0.0, TIME * speed * 0.62);
	float n = pow(noise3(p), contrast);
	float low_roll = noise3(p * vec3(0.55, 1.8, 0.55) + vec3(TIME * speed * 0.25, 0.0, 0.0));
	float h = clamp(1.0 - max(WORLD_POSITION.y, 0.0) / vertical_fade, 0.0, 1.0);
	DENSITY = density_multiplier * mix(0.42, 1.25, n) * mix(0.7, 1.25, low_roll) * h;
	ALBEDO = fog_color;
}
