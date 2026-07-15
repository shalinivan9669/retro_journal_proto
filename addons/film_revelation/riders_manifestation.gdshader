shader_type spatial;

render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.72, 0.76, 0.82, 1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_base_texture = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_metallic_texture = false;
uniform vec4 metallic_channel = vec4(1.0, 0.0, 0.0, 0.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.82;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_roughness_texture = false;
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float specular : hint_range(0.0, 1.0) = 0.35;

uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_texture = false;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform vec3 source_emission : source_color = vec3(0.0);
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_emission_texture = false;

uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.015;
// 0 = hidden, 1 = full weak Fresnel silhouette, 2 = bottom-up PBR fill.
uniform float manifestation_phase : hint_range(0.0, 2.0) = 0.0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float world_bottom_y = 0.0;
uniform float world_top_y = 3.0;
uniform float dither_band : hint_range(0.001, 0.25) = 0.075;
uniform float reveal_edge_width : hint_range(0.001, 0.25) = 0.055;
uniform vec3 cold_rim_color : source_color = vec3(0.36, 0.62, 0.94);
uniform float cold_rim_strength : hint_range(0.0, 2.0) = 0.18;
uniform float reveal_edge_strength : hint_range(0.0, 4.0) = 0.75;

varying float world_height;


float interleaved_gradient_noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}


void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}


void fragment() {
	vec2 source_uv = UV * uv_scale + uv_offset;
	vec4 sampled_base = base_color;
	if (use_base_texture) {
		sampled_base *= texture(base_texture, source_uv);
	}
	if (sampled_base.a < alpha_cutoff) {
		discard;
	}
	if (manifestation_phase < 0.5) {
		discard;
	}

	float view_rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	if (manifestation_phase < 1.5) {
		// A deliberately weak, complete silhouette for roughly 2-3 frames.
		// It is emissive-only, so it does not cast light or bleach the ground.
		ALBEDO = cold_rim_color * 0.018;
		METALLIC = 0.0;
		ROUGHNESS = 0.94;
		SPECULAR = 0.08;
		EMISSION = cold_rim_color * (0.018 + view_rim * 0.38);
	} else {
		float height_span = max(world_top_y - world_bottom_y, 0.001);
		float normalized_height = clamp((world_height - world_bottom_y) / height_span, 0.0, 1.0);
		float noise = interleaved_gradient_noise(FRAGCOORD.xy);
		float noisy_front = reveal_progress + (noise - 0.5) * dither_band;
		if (normalized_height > noisy_front) {
			discard;
		}

		float metallic_sample = 1.0;
		if (use_metallic_texture) {
			metallic_sample = dot(texture(metallic_texture, source_uv), metallic_channel);
		}
		float roughness_sample = 1.0;
		if (use_roughness_texture) {
			roughness_sample = dot(texture(roughness_texture, source_uv), roughness_channel);
		}

		ALBEDO = sampled_base.rgb;
		METALLIC = clamp(metallic * metallic_sample, 0.0, 1.0);
		ROUGHNESS = clamp(roughness * roughness_sample, 0.04, 1.0);
		SPECULAR = specular;
		if (use_normal_texture) {
			NORMAL_MAP = texture(normal_texture, source_uv).rgb;
			NORMAL_MAP_DEPTH = normal_scale;
		}

		vec3 material_emission = source_emission;
		if (use_emission_texture) {
			material_emission *= texture(emission_texture, source_uv).rgb;
		}
		float reveal_edge = 1.0 - smoothstep(
			0.0,
			reveal_edge_width,
			abs(normalized_height - reveal_progress)
		);
		EMISSION = material_emission + cold_rim_color * (
			view_rim * cold_rim_strength + reveal_edge * reveal_edge_strength
		);
	}
}
