shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D steppe_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steppe_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steppe_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steppe_wet_mask : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steppe_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steppe_height : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_displacement : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float steppe_tiling = 88.0;
uniform float rock_tiling = 270.0;
uniform float rock_coverage = 0.26;
uniform float night_albedo_scale = 0.42;

mat2 rotation_2d(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
	vec2 uv_ground = UV * steppe_tiling;
	vec2 uv_rock_a = UV * rock_tiling;
	vec2 uv_rock_b = rotation_2d(0.73) * (UV - vec2(0.5)) * (rock_tiling * 0.61);

	vec3 ground_color = texture(steppe_albedo, uv_ground).rgb;
	vec3 ground_normal = texture(steppe_normal, uv_ground).rgb;
	float ground_rough = texture(steppe_roughness, uv_ground).r;
	float wet = texture(steppe_wet_mask, uv_ground * 0.23).r;
	float ground_ao = texture(steppe_ao, uv_ground).r;
	float micro_height = texture(steppe_height, uv_ground).r;

	vec3 rock_a = texture(rock_albedo, uv_rock_a).rgb;
	vec3 rock_b = texture(rock_albedo, uv_rock_b).rgb;
	vec3 rock_color = mix(rock_a, rock_b, 0.34);
	vec3 rock_n = texture(rock_normal, uv_rock_a).rgb;
	float rock_rough = texture(rock_roughness, uv_rock_a).r;
	float rock_height = texture(rock_displacement, UV * 11.0).r;

	float patch_noise = texture(rock_displacement, UV * 4.7 + vec2(0.17, 0.31)).r;
	float coverage = clamp(rock_coverage, 0.0, 0.35);
	float patch_threshold = mix(0.92, 0.54, coverage / 0.35);
	float rock_mask = smoothstep(
		patch_threshold,
		patch_threshold + 0.12,
		patch_noise + rock_height * 0.18
	);
	rock_mask *= 1.0 - wet * 0.74;

	vec3 color = mix(ground_color, rock_color, rock_mask);
	color *= mix(0.91, 1.045, micro_height);
	color *= night_albedo_scale;
	color *= mix(1.0, 0.58, wet);

	ALBEDO = color;
	NORMAL_MAP = mix(ground_normal, rock_n, rock_mask);
	NORMAL_MAP_DEPTH = mix(0.46, 0.82, rock_mask);
	ROUGHNESS = mix(mix(ground_rough, rock_rough, rock_mask), 0.075, wet);
	SPECULAR = mix(0.28, 0.82, wet);
	METALLIC = 0.0;
	AO = mix(ground_ao, min(ground_ao, 0.78), rock_mask);
	AO_LIGHT_AFFECT = 0.72;
}
