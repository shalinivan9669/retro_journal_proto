shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 rust_color : source_color = vec4(0.42, 0.18, 0.06, 1.0);
uniform vec4 ash_color : source_color = vec4(0.08, 0.075, 0.065, 1.0);
uniform vec4 salt_color : source_color = vec4(0.86, 0.82, 0.70, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.52;
uniform float rust_scale : hint_range(0.1, 80.0) = 12.0;
uniform float edge_bias : hint_range(0.0, 1.0) = 0.34;
uniform float emission_leak : hint_range(0.0, 1.0) = 0.08;
uniform float crawl_speed : hint_range(0.0, 2.0) = 0.06;

float hash(vec2 p) {
	p = fract(p * vec2(43.13, 311.9));
	p += dot(p, p + 19.19);
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
	vec3 nrm = normalize(NORMAL);
	float vertical_edge = pow(1.0 - abs(nrm.y), 1.6);
	float n1 = noise(UV * rust_scale + vec2(TIME * crawl_speed, -TIME * crawl_speed * 0.37));
	float n2 = noise(UV * rust_scale * 2.7 + vec2(-TIME * 0.011, TIME * 0.023));
	float rust_mask = smoothstep(0.38, 0.92, n1 * 0.78 + n2 * 0.42 + vertical_edge * edge_bias);
	float salt_mask = smoothstep(0.64, 0.98, noise(UV * rust_scale * 0.55 + vec2(7.7, 2.4))) * (1.0 - rust_mask * 0.55);
	vec3 col = mix(ash_color.rgb, rust_color.rgb, rust_mask);
	col = mix(col, salt_color.rgb, salt_mask * 0.42);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	EMISSION = rust_color.rgb * emission_leak * rust_mask;
	ALPHA = clamp(opacity * max(rust_mask, salt_mask * 0.58), 0.0, 0.86);
}
