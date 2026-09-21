shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float r = length(world.xz);
	float n = noise(world.xz * 0.28) * 0.6 + noise(world.xz * 1.7) * 0.28;
	vec3 packed_dirt = vec3(0.38, 0.24, 0.16) * (0.72 + n);
	vec3 dust = vec3(0.66, 0.48, 0.30);
	vec3 lot = mix(packed_dirt, dust, noise(world.xz * 0.07));
	float inner = 1.0 - smoothstep(15.4, 16.8, r);
	vec3 sand = vec3(0.90, 0.74, 0.48);
	lot = mix(lot, sand, inner * 0.62);
	float paint = 1.0 - smoothstep(0.28, 0.95, abs(r - 16.6));
	lot = mix(lot, vec3(0.78, 0.16, 0.12), paint);
	float gold = 1.0 - smoothstep(0.10, 0.28, abs(r - 8.2));
	lot = mix(lot, vec3(0.92, 0.74, 0.28), gold * 0.55);
	float boards = smoothstep(0.02, 0.08, abs(sin(world.x * 1.7) * sin(world.z * 0.2)));
	lot *= 0.92 + boards * 0.08;
	ALBEDO = lot;
	ROUGHNESS = 0.86 - paint * 0.25;
	SPECULAR = 0.12;
}
