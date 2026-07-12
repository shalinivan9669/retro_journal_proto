shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 color_tint : source_color = vec4(0.78, 0.76, 0.70, 0.88);

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	float green_dominance = texel.g - max(texel.r, texel.b);
	float green_strength = smoothstep(0.045, 0.16, green_dominance) * smoothstep(0.25, 0.58, texel.g);
	float alpha = texel.a * (1.0 - green_strength);
	vec3 dusty = mix(texel.rgb, vec3(dot(texel.rgb, vec3(0.299, 0.587, 0.114))), 0.12);
	dusty = mix(dusty, vec3(0.43, 0.42, 0.39), 0.10);
	ALBEDO = dusty * color_tint.rgb;
	ALPHA = alpha * color_tint.a;
	ROUGHNESS = 1.0;
}
