shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

uniform vec4 dry_color : source_color = vec4(0.43, 0.38, 0.28, 1.0);
uniform vec4 path_color : source_color = vec4(0.34, 0.30, 0.23, 1.0);
uniform vec4 wet_lowland_color : source_color = vec4(0.27, 0.31, 0.25, 1.0);
uniform vec4 salt_dust_color : source_color = vec4(0.60, 0.57, 0.45, 1.0);
uniform vec4 rock_color : source_color = vec4(0.30, 0.30, 0.27, 1.0);
uniform vec4 grass_ground_color : source_color = vec4(0.27, 0.31, 0.19, 1.0);
uniform float world_uv_scale = 0.075;
uniform float texture_uv_scale = 0.085;
uniform float texture_strength = 0.78;
uniform float mottle_strength = 0.105;
uniform float grass_ground_strength = 0.48;
uniform sampler2D dry_ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D salt_ground_texture : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uvw = world_pos.xz * world_uv_scale;
	float broad = sin(uvw.x * 1.7 + uvw.y * 0.9) * 0.5 + 0.5;
	float fine = hash21(floor(uvw * 18.0));
	float mottle = (broad * 0.58 + fine * 0.42 - 0.5) * mottle_strength;
	float meadow_waves = sin(world_pos.x * 0.041 + sin(world_pos.y * 0.5 + world_pos.z * 0.019) * 1.7);
	meadow_waves += sin(world_pos.z * 0.037 - world_pos.x * 0.014) * 0.72;
	float meadow_noise = meadow_waves * 0.25 + hash21(floor(world_pos.xz * 0.055)) * 0.38 + 0.48;
	float playable_steppe = 1.0 - smoothstep(118.0, 245.0, length(world_pos.xz));
	float meadow_exclusion = 1.0 - clamp(max(COLOR.a * 0.94, max(COLOR.r * 0.74, COLOR.b * 0.48)), 0.0, 1.0);
	float meadow_mask = smoothstep(0.34, 0.72, meadow_noise) * playable_steppe * meadow_exclusion;

	vec3 base = dry_color.rgb;
	base = mix(base, salt_dust_color.rgb, clamp(COLOR.r * 0.78, 0.0, 1.0));
	base = mix(base, wet_lowland_color.rgb, clamp(COLOR.g * 0.68, 0.0, 1.0));
	base = mix(base, rock_color.rgb, clamp(COLOR.b * 0.72, 0.0, 1.0));
	base = mix(base, path_color.rgb, clamp(COLOR.a * 0.58, 0.0, 1.0));

	vec2 tex_uv = world_pos.xz * texture_uv_scale;
	vec3 dry_tex = texture(dry_ground_texture, tex_uv).rgb;
	vec3 rock_tex = texture(rock_ground_texture, tex_uv * 0.72 + vec2(0.17, 0.31)).rgb;
	vec3 wet_tex = texture(wet_ground_texture, tex_uv * 0.64 + vec2(0.43, 0.11)).rgb;
	vec3 salt_tex = texture(salt_ground_texture, tex_uv * 0.42 + vec2(0.27, 0.61)).rgb;
	vec3 texture_base = dry_tex;
	texture_base = mix(texture_base, salt_tex, clamp(COLOR.r * 0.82, 0.0, 1.0));
	texture_base = mix(texture_base, wet_tex, clamp(COLOR.g * 0.78, 0.0, 1.0));
	texture_base = mix(texture_base, rock_tex, clamp(max(COLOR.b, COLOR.a * 0.42), 0.0, 1.0));
	texture_base = mix(texture_base, texture_base * path_color.rgb * 1.45, clamp(COLOR.a * 0.5, 0.0, 1.0));

	vec3 surface_color = mix(base, texture_base, texture_strength) + vec3(mottle);
	vec3 grassy_surface = mix(grass_ground_color.rgb, dry_tex * vec3(0.66, 0.78, 0.48), 0.42);
	surface_color = mix(surface_color, grassy_surface, meadow_mask * grass_ground_strength);
	ALBEDO = clamp(surface_color, vec3(0.02), vec3(0.88));
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
}
