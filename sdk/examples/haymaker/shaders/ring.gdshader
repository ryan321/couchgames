shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

uniform vec3 glow : source_color = vec3(0.35, 1.0, 0.72);
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wave = 0.45 + 0.55 * sin(TIME * 3.2 + world.y * 1.8);
	float rim = pow(1.0 - abs(NORMAL.y), 1.6);
	ALBEDO = glow * wave;
	ALPHA = 0.22 + rim * 0.35;
	EMISSION = glow * (0.8 + wave);
}
