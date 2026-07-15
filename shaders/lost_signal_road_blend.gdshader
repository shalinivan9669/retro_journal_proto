shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_displacement : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D damage_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D damage_mask : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

// Asphalt 02 is calibrated by Poly Haven to cover three metres.
// On an 8.6 x 120 m chunk this keeps aggregate at its photographed scale.
uniform vec2 fine_tiling = vec2(2.8667, 40.0);
uniform vec2 repair_tiling = vec2(0.31, 3.2);
uniform vec2 repair_offset = vec2(0.0);
uniform float wave_phase = 0.0;

float lane_mask(float x, float centre) {
	return 1.0 - smoothstep(0.055, 0.125, abs(x - centre));
}

void vertex() {
	float across = UV.x * 2.0 - 1.0;
	float crown = (1.0 - abs(across)) * 0.052;
	float left_rut = exp(-pow((across + 0.48) / 0.075, 2.0));
	float right_rut = exp(-pow((across - 0.48) / 0.075, 2.0));
	float ruts = -(left_rut + right_rut) * 0.012;
	float edge_settle = -smoothstep(0.78, 1.0, abs(across)) * 0.025;
	float seam_taper = pow(sin(UV.y * PI), 2.0);
	float long_wave = (
		sin(UV.y * PI * 2.0 + wave_phase) * 0.014
		+ sin(UV.y * PI * 6.0 + wave_phase * 1.73) * 0.005
	) * seam_taper;
	float scan_height = texture(asphalt_displacement, UV * fine_tiling).r - 0.5;
	VERTEX.y += crown + ruts + edge_settle + long_wave + scan_height * 0.004;
}

void fragment() {
	vec2 fine_uv = UV * fine_tiling;
	vec2 repair_uv = UV * repair_tiling + repair_offset;
	vec3 scanned_albedo = texture(asphalt_albedo, fine_uv).rgb;
	float scanned_ao = texture(asphalt_ao, fine_uv).r;
	float repair_noise = texture(damage_mask, repair_uv).r;

	float tire_wear = max(lane_mask(UV.x, 0.265), lane_mask(UV.x, 0.735));
	float dusty_edge = smoothstep(0.34, 0.49, abs(UV.x - 0.5));
	float repair_patch = smoothstep(0.58, 0.78, repair_noise) * 0.42;

	vec3 road_color = scanned_albedo * mix(1.0, 0.86, tire_wear);
	road_color = mix(road_color, road_color * vec3(0.69, 0.64, 0.58), dusty_edge * 0.42);
	road_color = mix(road_color, road_color * vec3(0.72, 0.75, 0.78), repair_patch);

	// Paint is part of the road shader: no raised toy-like boxes or z-fighting.
	float centre_line = 1.0 - smoothstep(0.006, 0.011, abs(UV.x - 0.5));
	float dash = 1.0 - step(0.41, fract(UV.y * 12.0));
	centre_line *= dash;
	float left_edge_line = 1.0 - smoothstep(0.0045, 0.0085, abs(UV.x - 0.045));
	float right_edge_line = 1.0 - smoothstep(0.0045, 0.0085, abs(UV.x - 0.955));
	float paint_wear = mix(0.34, 0.93, smoothstep(0.18, 0.82, repair_noise));
	float paint = clamp((centre_line + left_edge_line + right_edge_line) * paint_wear, 0.0, 1.0);
	road_color = mix(road_color, vec3(0.54, 0.53, 0.47), paint * 0.78);

	ALBEDO = road_color * vec3(0.66, 0.69, 0.72);
	vec3 base_normal = texture(asphalt_normal, fine_uv).rgb;
	vec3 repair_normal = texture(damage_normal, repair_uv).rgb;
	NORMAL_MAP = mix(base_normal, repair_normal, repair_patch * 0.36);
	NORMAL_MAP_DEPTH = mix(0.72, 0.34, paint);
	float scanned_roughness = texture(asphalt_roughness, fine_uv).r;
	ROUGHNESS = clamp(scanned_roughness - tire_wear * 0.10 + dusty_edge * 0.08 - repair_patch * 0.04, 0.58, 0.98);
	ROUGHNESS = mix(ROUGHNESS, 0.76, paint);
	AO = mix(1.0, scanned_ao, 0.62);
	AO_LIGHT_AFFECT = 0.55;
}
