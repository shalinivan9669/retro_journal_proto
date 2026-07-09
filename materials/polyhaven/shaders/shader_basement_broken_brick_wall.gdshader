shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.62, 0.58, 0.53, 1.0);
uniform float world_uv_scale = 0.48;
uniform float normal_strength = 0.42;
uniform float floor_dampening = 0.22;

varying vec3 world_pos;
varying vec3 world_normal;
varying float local_y;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL).xyz);
	local_y = VERTEX.y;
}

vec3 triplanar_rgb(sampler2D source, vec3 position, vec3 normal, float scale) {
	vec3 weights = pow(abs(normal), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 x_sample = texture(source, position.zy * scale).rgb;
	vec3 y_sample = texture(source, position.xz * scale).rgb;
	vec3 z_sample = texture(source, position.xy * scale).rgb;
	return x_sample * weights.x + y_sample * weights.y + z_sample * weights.z;
}

void fragment() {
	vec3 base = triplanar_rgb(albedo_texture, world_pos, world_normal, world_uv_scale) * tint.rgb;
	vec3 arm = triplanar_rgb(arm_texture, world_pos, world_normal, world_uv_scale);
	vec3 normal_sample = triplanar_rgb(normal_texture, world_pos, world_normal, world_uv_scale);
	float floor_shadow = smoothstep(1.1, 0.0, local_y) * floor_dampening;

	ALBEDO = clamp(base * (1.0 - floor_shadow), vec3(0.015), vec3(0.82));
	AO = clamp(arm.r * (1.0 - floor_shadow * 0.4), 0.0, 1.0);
	ROUGHNESS = clamp(max(arm.g, 0.82), 0.0, 1.0);
	METALLIC = 0.0;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), normal_sample, normal_strength);
}
