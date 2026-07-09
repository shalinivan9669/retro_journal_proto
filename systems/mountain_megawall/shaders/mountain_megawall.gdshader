shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D day_tex : source_color, filter_linear_mipmap;
uniform sampler2D night_tex : source_color, filter_linear_mipmap;
uniform sampler2D alpha_tex : filter_linear_mipmap;
uniform sampler2D depth_mask : filter_linear_mipmap;
uniform sampler2D cloud_shadow_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_mask : filter_linear_mipmap;
uniform sampler2D emission_mask : source_color, filter_linear_mipmap;

uniform float day_night = 0.0;
uniform float haze_strength = 0.75;
uniform float layer_opacity = 1.0;
uniform float night_only_alpha = 0.0;
uniform float contrast = 0.88;
uniform float cloud_shadow_strength = 0.16;
uniform float snow_day_strength = 0.20;
uniform float snow_night_strength = 0.42;
uniform float emission_strength = 0.80;
uniform float elapsed_time = 0.0;
uniform vec2 parallax_uv = vec2(0.0);
uniform vec2 cloud_shadow_speed = vec2(0.003, 0.0);
uniform vec4 haze_day : source_color = vec4(0.55, 0.58, 0.55, 1.0);
uniform vec4 haze_night : source_color = vec4(0.08, 0.11, 0.17, 1.0);
uniform vec4 moon_light : source_color = vec4(0.35, 0.48, 0.70, 1.0);

void fragment() {
    vec2 uv = UV + parallax_uv;
    vec4 day_col = texture(day_tex, uv);
    vec4 night_col = texture(night_tex, uv);
    float alpha = texture(alpha_tex, uv).r;
    float depth = texture(depth_mask, uv).r;
    float snow = texture(snow_mask, uv).r;

    vec3 col = mix(day_col.rgb, night_col.rgb, day_night);
    float haze_amount = pow(1.0 - depth, 1.4) * haze_strength;
    vec3 haze_col = mix(haze_day.rgb, haze_night.rgb, day_night);
    col = mix(col, haze_col, haze_amount);

    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma), col, contrast);

    float shadow = texture(cloud_shadow_tex, uv + elapsed_time * cloud_shadow_speed).r;
    col *= 1.0 - shadow * cloud_shadow_strength;

    col += vec3(0.65, 0.70, 0.74) * snow * snow_day_strength * (1.0 - day_night);
    col += moon_light.rgb * snow * snow_night_strength * day_night;

    vec3 emission = texture(emission_mask, uv).rgb;
    col += emission * emission_strength * day_night;

    float night_gate = mix(1.0, smoothstep(0.32, 0.88, day_night), clamp(night_only_alpha, 0.0, 1.0));
    ALBEDO = col;
    ALPHA = alpha * layer_opacity * night_gate;
}
