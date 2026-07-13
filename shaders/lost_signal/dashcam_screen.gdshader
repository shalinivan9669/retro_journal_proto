shader_type canvas_item;

uniform float distortion = 0.025;
uniform float noise_amount : hint_range(0.0, 0.2) = 0.035;
uniform float scanline_amount : hint_range(0.0, 0.3) = 0.09;
uniform vec3 tint = vec3(0.82, 0.94, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius2 = dot(centered, centered);
	vec2 warped_uv = UV + centered * radius2 * distortion * 0.25;
	vec4 feed = texture(TEXTURE, warped_uv);
	float noise = hash21(FRAGCOORD.xy + floor(TIME * 18.0)) - 0.5;
	float scanline = sin(UV.y * 720.0) * 0.5 + 0.5;
	vec3 color = feed.rgb * tint + noise * noise_amount;
	color *= 1.0 - scanline * scanline_amount;
	COLOR = vec4(max(color, vec3(0.0)), feed.a);
}
