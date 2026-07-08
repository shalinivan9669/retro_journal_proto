shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 cloth_color : source_color = vec3(0.075, 0.065, 0.06);
uniform vec3 cloth_shadow : source_color = vec3(0.015, 0.012, 0.014);
uniform float amplitude : hint_range(0.0, 0.2) = 0.028;
uniform float frequency : hint_range(0.0, 80.0) = 26.0;
uniform float speed : hint_range(0.0, 8.0) = 1.8;
uniform float normal_push : hint_range(0.0, 0.1) = 0.015;

void vertex() {
	float weight = COLOR.r;
	float wave = sin((UV.y + VERTEX.x * 0.12 + VERTEX.z * 0.05) * frequency + TIME * speed);
	VERTEX += NORMAL * wave * amplitude * weight;
	VERTEX += NORMAL * normal_push * weight;
}

void fragment() {
	float shade = smoothstep(0.05, 0.95, UV.y);
	ALBEDO = mix(cloth_shadow, cloth_color, shade);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
