shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform vec4 health_color : source_color = vec4(0.6, 0.8, 0.65, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
void vertex() {
	// Face the camera while keeping the bar at the enemy's world-space position.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float inner = step(0.025, UV.x) * step(UV.x, 0.975) * step(0.19, UV.y) * step(UV.y, 0.81);
	float filled = step(UV.x, 0.025 + health * 0.95) * inner;
	ALBEDO = mix(vec3(0.045, 0.065, 0.075), health_color.rgb, filled);
	ALPHA = fade * 0.92;
}
