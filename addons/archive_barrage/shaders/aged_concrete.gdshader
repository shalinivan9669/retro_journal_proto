shader_type spatial;

uniform sampler2D plaster_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float plaster_tiling = 1.4;
uniform float detail_tiling = 7.0;
uniform float night_scale = 1.0;

void fragment() {
	vec3 plaster = texture(plaster_albedo, UV * plaster_tiling).rgb;
	vec3 detail = texture(detail_albedo, UV * detail_tiling).rgb;
	vec3 normal_a = texture(plaster_normal, UV * plaster_tiling).rgb;
	vec3 normal_b = texture(detail_normal, UV * detail_tiling).rgb;

	float stains = smoothstep(0.16, 0.38, detail.r);
	vec3 color = plaster * mix(0.52, 0.82, stains);
	color = mix(color, detail, 0.24) * night_scale;

	ALBEDO = color;
	NORMAL_MAP = mix(normal_a, normal_b, 0.38);
	NORMAL_MAP_DEPTH = 0.72;
	ROUGHNESS = clamp(texture(plaster_roughness, UV * plaster_tiling).r + 0.08, 0.72, 1.0);
	SPECULAR = 0.22;
}
