shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D haze_tex : source_color, filter_linear_mipmap;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float day_night = 0.0;
uniform float haze_strength = 0.75;
uniform float layer_opacity = 1.0;
uniform float opacity = 0.45;
uniform float softness = 2.2;
uniform float noise_power = 0.18;
uniform float elapsed_time = 0.0;
uniform vec2 scroll_speed = vec2(0.004, 0.0);
uniform vec2 parallax_uv = vec2(0.0);
uniform vec4 haze_day : source_color = vec4(0.62, 0.61, 0.55, 1.0);
uniform vec4 haze_night : source_color = vec4(0.12, 0.16, 0.22, 1.0);

void fragment() {
    vec2 uv = UV + parallax_uv;
    vec4 painted = texture(haze_tex, uv);
    float n = texture(noise_tex, uv * vec2(4.0, 1.2) + elapsed_time * scroll_speed).r;
    float vertical = 1.0 - abs(uv.y * 2.0 - 1.0);
    vertical = pow(vertical, softness);
    float a = max(painted.a, vertical * opacity);
    a *= mix(1.0 - noise_power, 1.0 + noise_power, n);
    vec3 col = mix(haze_day.rgb, haze_night.rgb, day_night);
    col = mix(col, painted.rgb, painted.a * 0.45);
    ALBEDO = col;
    ALPHA = clamp(a * layer_opacity * haze_strength, 0.0, 1.0);
}
