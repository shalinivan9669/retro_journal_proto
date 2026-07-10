shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Each panorama tile is an individual texture, while all tiles share this
// exact material setup. The source PNG alpha is preserved end-to-end.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 color_tint : source_color = vec4(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 1.0;
uniform float fade_left_edge = 0.0;
uniform float fade_right_edge = 0.0;

void fragment() {
	vec4 sampled = texture(albedo_texture, UV);
	float luma = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(luma), sampled.rgb, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	float panorama_edge = 1.0;
	panorama_edge *= mix(1.0, smoothstep(0.0, 0.14, UV.x), fade_left_edge);
	panorama_edge *= mix(1.0, smoothstep(0.0, 0.14, 1.0 - UV.x), fade_right_edge);
	ALBEDO = max(color * brightness * color_tint.rgb, vec3(0.0));
	ALPHA = sampled.a * color_tint.a * panorama_edge;
}
