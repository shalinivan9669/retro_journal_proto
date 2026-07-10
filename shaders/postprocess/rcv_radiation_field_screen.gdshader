shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0) = 0.54;
uniform float radial_strength : hint_range(0.0, 2.0) = 0.62;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.22;
uniform float rust_stain : hint_range(0.0, 1.0) = 0.22;
uniform float chroma : hint_range(0.0, 0.05) = 0.008;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.7;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 ion_tint : source_color = vec4(0.95, 0.78, 0.42, 1.0);
uniform vec4 rust_tint : source_color = vec4(0.55, 0.24, 0.09, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 17.17);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - center;
	float dist = length(dir);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float ring = sin(dist * 92.0 - TIME * 6.0 + noise(uv * 8.0) * 2.2) * 0.5 + 0.5;
	ring = smoothstep(0.62, 1.0, ring);
	float rays = pow(max(0.0, sin(atan(dir.y, dir.x) * 19.0 + TIME * 0.7 + noise(uv * 3.0) * 4.0)), 5.0);
	float contam = (ring * 0.65 + rays * 0.35) * (1.0 - smoothstep(0.12, 1.0, dist)) * radial_strength;

	vec2 jitter = normalize(dir + 0.0001) * contam * 0.006 * opacity;
	float r = texture(screen_texture, uv + jitter + vec2(chroma, 0.0)).r;
	float g = texture(screen_texture, uv + jitter).g;
	float b = texture(screen_texture, uv + jitter - vec2(chroma, 0.0)).b;
	vec3 col = vec3(r, g, b);

	float grain = hash(uv * vec2(1200.0, 700.0) + floor(TIME * 30.0));
	float rusty = noise(uv * vec2(7.0, 4.0) + vec2(TIME * 0.035, -TIME * 0.02));
	col += ion_tint.rgb * contam * opacity * (0.38 + pulse * 0.28);
	col = mix(col, col * rust_tint.rgb * 1.22, rusty * rust_stain * opacity);
	col += (grain - 0.5) * grain_strength * opacity;
	COLOR = vec4(col, 1.0);
}
