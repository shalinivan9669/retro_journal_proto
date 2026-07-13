shader_type fog;

uniform sampler3D density_noise;
uniform float density_scale = 0.065;
uniform float flash_energy = 0.0;
uniform vec3 wind_direction = vec3(0.12, 0.0, 0.04);

void fog() {
	vec3 center = UVW - vec3(0.5, 0.0, 0.5);
	float radial = 1.0 - smoothstep(0.12, 0.52, length(center.xz));
	float vertical = smoothstep(0.0, 0.08, UVW.y) * (1.0 - smoothstep(0.68, 1.0, UVW.y));

	vec3 noise_uv = UVW * vec3(2.2, 3.5, 2.2);
	noise_uv += wind_direction * TIME;
	noise_uv.y -= TIME * 0.035;
	float n = smoothstep(0.34, 0.78, texture(density_noise, noise_uv).r);
	float shape = radial * vertical * n;

	DENSITY = shape * density_scale;
	ALBEDO = vec3(0.48);
	EMISSION = vec3(1.0) * shape * flash_energy;
}
