shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float clock = 0.0;
uniform vec2 centers[16];
uniform int player_count = 0;
uniform float clear_radius = 7.0;
uniform float outer_radius = 10.0;
uniform vec2 ground_origin;
uniform vec2 ground_dx;
uniform vec2 ground_dy;
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth)*2.0-1.0;
#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0, depth);
#endif
	vec4 position = INV_VIEW_MATRIX*INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	vec2 world = position.xz/position.w;
	vec2 mist_at = ground_origin+SCREEN_UV.x*ground_dx+SCREEN_UV.y*ground_dy;
	float nearest = 10000.0;
	for (int i=0;i<16;i++) {
		if (i>=player_count) { break; }
		nearest = min(nearest,distance(world,centers[i]));
	}
	float sight = depth>0.000001 ? 1.0-smoothstep(clear_radius,outer_radius,nearest) : 0.0;
	float grain = sin(mist_at.x*.71+sin(mist_at.y*.48)+clock*.12)*sin(mist_at.y*.63-clock*.08)*.5+.5;
	ALBEDO = mix(vec3(.0006,.0010,.0017),vec3(.0012,.0024,.0038),grain*.55);
	ALPHA = 1.0-sight;
}
