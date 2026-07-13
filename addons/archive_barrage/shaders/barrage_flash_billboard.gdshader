shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

uniform sampler2D flare_texture : source_color, filter_linear_mipmap, repeat_disable;

instance uniform vec4 burst_color : source_color = vec4(1.0);
instance uniform float burst_energy = 0.0;
instance uniform float burst_opacity = 0.0;
instance uniform float burst_width = 1.0;
instance uniform float burst_height = 1.0;
instance uniform float burst_rotation = 0.0;
instance uniform float burst_shape = 0.0;
instance uniform float burst_softness = 1.0;


void vertex() {
	vec2 centered_uv = UV - vec2(0.5);
	float sine = sin(burst_rotation);
	float cosine = cos(burst_rotation);
	mat2 rotation = mat2(vec2(cosine, sine), vec2(-sine, cosine));
	vec2 billboard_offset = rotation * (centered_uv * vec2(burst_width, burst_height));
	vec3 center_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX = center_view + vec3(billboard_offset, 0.0);
}


void fragment() {
	vec4 flare_sample = texture(flare_texture, UV);
	float flare_luma = dot(flare_sample.rgb, vec3(0.2126, 0.7152, 0.0722));
	float radial_mask = pow(max(max(flare_luma, flare_sample.a), 0.0001), burst_softness);

	vec2 ray_uv = abs(UV * 2.0 - vec2(1.0));
	float ray_taper = max(1.0 - ray_uv.x, 0.0);
	float ray_half_width = mix(0.13, 0.018, smoothstep(0.0, 1.0, ray_uv.x));
	float ray_cross_section = exp(-pow(ray_uv.y / max(ray_half_width, 0.001), 2.0));
	float ray_mask = ray_cross_section * pow(ray_taper, 0.72);
	ray_mask *= 1.0 - smoothstep(0.84, 1.0, ray_uv.x);

	float shape_mix = step(0.5, burst_shape);
	float mask = mix(radial_mask, ray_mask, shape_mix);
	ALBEDO = vec3(0.0);
	EMISSION = burst_color.rgb * burst_energy;
	ALPHA = clamp(mask * burst_opacity * burst_color.a, 0.0, 1.0);
}
