shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D cloud_tex : source_color, filter_linear_mipmap;
uniform float day_night = 0.0;
uniform float layer_opacity = 0.45;
uniform float elapsed_time = 0.0;
uniform vec2 parallax_uv = vec2(0.0);
uniform vec2 scroll_speed = vec2(0.006, 0.0);
uniform vec4 day_tint : source_color = vec4(0.45, 0.48, 0.50, 1.0);
uniform vec4 night_tint : source_color = vec4(0.08, 0.11, 0.16, 1.0);

void fragment() {
    vec2 uv = UV + parallax_uv + elapsed_time * scroll_speed;
    vec4 c = texture(cloud_tex, uv);
    vec3 tint = mix(day_tint.rgb, night_tint.rgb, day_night);
    ALBEDO = c.rgb * tint * 1.45;
    ALPHA = c.a * layer_opacity;
}
