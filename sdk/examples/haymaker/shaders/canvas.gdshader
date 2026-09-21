shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform vec3 stripe_a : source_color = vec3(0.78, 0.16, 0.14);
uniform vec3 stripe_b : source_color = vec3(0.95, 0.90, 0.78);
uniform float width = 0.35;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.6 + world.y * 2.4) * 0.03;
}

void fragment() {
	float stripe = step(0.5, fract((world.y * 1.4 + world.x * 0.15) / max(width, 0.05)));
	vec3 color = mix(stripe_a, stripe_b, stripe);
	ALBEDO = color;
	ROUGHNESS = 0.72;
	EMISSION = color * 0.04;
}
