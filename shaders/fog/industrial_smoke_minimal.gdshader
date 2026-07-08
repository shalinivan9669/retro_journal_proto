shader_type fog;

uniform vec3 smoke_color : source_color = vec3(0.12, 0.115, 0.105);
uniform float density_multiplier : hint_range(0.0, 3.0) = 0.65;
uniform float speed : hint_range(0.0, 2.0) = 0.18;
uniform float scale : hint_range(0.01, 2.0) = 0.16;
uniform float height_fade : hint_range(0.1, 30.0) = 9.0;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec3(1,0,0));
	float c = hash(i + vec3(0,1,0));
	float d = hash(i + vec3(1,1,0));
	float e = hash(i + vec3(0,0,1));
	float f1 = hash(i + vec3(1,0,1));
	float g = hash(i + vec3(0,1,1));
	float h = hash(i + vec3(1,1,1));
	return mix(mix(mix(a,b,f.x), mix(c,d,f.x), f.y), mix(mix(e,f1,f.x), mix(g,h,f.x), f.y), f.z);
}

void fog() {
	vec3 p = WORLD_POSITION * scale + vec3(TIME * speed * 0.25, TIME * speed, TIME * speed * 0.08);
	float n = noise3(p) * 0.65 + noise3(p * 2.1) * 0.35;
	float up = clamp(WORLD_POSITION.y / height_fade, 0.0, 1.0);
	float soft_top = smoothstep(1.0, 0.2, up);
	DENSITY = density_multiplier * n * soft_top;
	ALBEDO = smoke_color;
}
