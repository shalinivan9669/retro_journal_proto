shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D hero_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hero_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hero_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hero_ao : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hero_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_pockets_mask : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D dry_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_ao : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_ao : filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms Scale;
uniform float hero_physical_size_m : hint_range(1.0, 8.0, 0.1) = 3.0;
uniform float dry_physical_size_m : hint_range(1.0, 8.0, 0.1) = 3.0;
uniform float mud_physical_size_m : hint_range(1.0, 8.0, 0.1) = 2.3;

group_uniforms Art_direction;
uniform float dry_amount : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float mud_amount : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform float wet_amount : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float wet_roughness : hint_range(0.70, 1.0, 0.01) = 0.88;
uniform float normal_strength : hint_range(0.0, 2.0, 0.01) = 0.78;
uniform float macro_contrast : hint_range(0.0, 0.4, 0.01) = 0.13;
uniform float vertex_displacement_m : hint_range(0.0, 0.12, 0.001) = 0.0;

group_uniforms Matte_finish;
uniform float matte_roughness_floor : hint_range(0.75, 1.0, 0.01) = 0.90;
uniform float matte_roughness_ceiling : hint_range(0.80, 1.0, 0.01) = 0.98;
uniform float residual_specular : hint_range(0.0, 0.3, 0.01) = 0.10;
uniform float cool_neutrality : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float dry_micro_contrast : hint_range(0.0, 0.12, 0.005) = 0.055;

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p = r * p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (vertex_displacement_m > 0.0001) {
		float h = textureLod(hero_height, wp.xz / hero_physical_size_m, 0.0).r;
		VERTEX += NORMAL * ((h - 0.5) * vertex_displacement_m);
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 hero_uv = world_position.xz / hero_physical_size_m;
	vec2 dry_uv = world_position.xz / dry_physical_size_m + vec2(0.173, 0.619);
	vec2 mud_uv = world_position.xz / mud_physical_size_m + vec2(0.731, 0.287);

	float macro_a = fbm(world_position.xz * 0.038);
	float macro_b = fbm(world_position.xz * 0.082 + vec2(31.7, -12.4));
	float dry_mask = smoothstep(0.43, 0.76, macro_a) * dry_amount;
	float mud_mask = smoothstep(0.67, 0.88, macro_b) * mud_amount;

	vec3 albedo = texture(hero_albedo, hero_uv).rgb;
	vec3 normal_tex = texture(hero_normal, hero_uv).rgb;
	float roughness = texture(hero_roughness, hero_uv).r;
	float ao = texture(hero_ao, hero_uv).r;

	albedo = mix(albedo, texture(dry_albedo, dry_uv).rgb, dry_mask);
	normal_tex = mix(normal_tex, texture(dry_normal, dry_uv).rgb, dry_mask);
	roughness = mix(roughness, texture(dry_roughness, dry_uv).r, dry_mask);
	ao = mix(ao, texture(dry_ao, dry_uv).r, dry_mask);

	albedo = mix(albedo, texture(mud_albedo, mud_uv).rgb, mud_mask);
	normal_tex = mix(normal_tex, texture(mud_normal, mud_uv).rgb, mud_mask);
	roughness = mix(roughness, texture(mud_roughness, mud_uv).r, mud_mask);
	ao = mix(ao, texture(mud_ao, mud_uv).r, mud_mask);

	float pocket = texture(wet_pockets_mask, hero_uv).r;
	float wetness = clamp((pocket * 0.72 + mud_mask * 1.7) * wet_amount, 0.0, 1.0);
	// Damp pockets remain tonally darker, but never become mirror-like.  The
	// scene needs dry steppe and bomb-churned soil, not a polished wet floor.
	albedo *= mix(1.0, 0.79, wetness);
	roughness = mix(roughness, max(wet_roughness, matte_roughness_floor), wetness);

	// Broad cool-neutral mottling breaks up the repeated texture without adding
	// a warm dirt tint.  The fine terms are intentionally subtle so mipmapped
	// source normals remain responsible for the actual small-scale relief.
	float dry_grain_a = value_noise(world_position.xz * 2.65 + vec2(8.7, -19.4));
	float dry_grain_b = value_noise(world_position.xz * 7.90 + vec2(-37.2, 11.6));
	float grain = mix(dry_grain_a, dry_grain_b, 0.34);
	float material_luma = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	vec3 cool_neutral = vec3(material_luma) * vec3(0.965, 0.995, 1.025);
	albedo = mix(albedo, cool_neutral, cool_neutrality);
	albedo *= 1.0 + (grain - 0.5) * dry_micro_contrast;

	// A high roughness floor removes the broad moon/explosion glare, while the
	// PBR normal maps, AO and Burley diffuse response still describe every slope.
	float roughness_variation = mix(
		matte_roughness_floor,
		max(matte_roughness_floor, matte_roughness_ceiling),
		clamp(grain * 0.72 + macro_b * 0.28, 0.0, 1.0)
	);
	roughness = max(roughness, roughness_variation);

	float broad_tone = mix(1.0 - macro_contrast, 1.0 + macro_contrast * 0.45, macro_a);
	ALBEDO = albedo * broad_tone;
	NORMAL_MAP = normal_tex;
	NORMAL_MAP_DEPTH = normal_strength * mix(0.94, 1.06, dry_grain_a);
	ROUGHNESS = clamp(roughness, matte_roughness_floor, 1.0);
	AO = ao;
	AO_LIGHT_AFFECT = 0.58;
	METALLIC = 0.0;
	SPECULAR = residual_specular;
}
