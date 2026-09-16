shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float h = 1.0 - UV.y;
	float sway = sin(h * 11.0 - TIME * 7.0) * 0.08 * h;
	float x = abs(UV.x - 0.5 + sway);
	float width = (1.0 - h) * 0.38 + sin(h * 18.0 + TIME * 9.0) * 0.025;
	float edge = smoothstep(width, width - 0.09, x);
	float base = smoothstep(0.0, 0.16, h);
	ALPHA = edge * base * smoothstep(1.0, 0.82, h);
	ALBEDO = mix(vec3(1.0, 0.14, 0.015), vec3(1.0, 0.83, 0.3), pow(1.0 - h, 2.0));
	EMISSION = ALBEDO * 3.0;
}
