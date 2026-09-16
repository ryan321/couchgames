shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform vec4 hit_color : source_color = vec4(0.6, 0.8, 0.65, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	ALBEDO = hit_color.rgb;
	ALPHA = opacity;
}
