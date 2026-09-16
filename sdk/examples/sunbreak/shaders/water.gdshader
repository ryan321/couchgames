shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world.x * 0.23 + TIME * 0.9) * 0.15 + cos(world.z * 0.3 + TIME * 0.7) * 0.11;
}
void fragment() {
    float wave = sin(world.x * 0.6 + world.z * 0.4 + TIME) * sin(world.z * 0.7 - TIME * 0.6);
    float foam = smoothstep(0.79, 0.98, wave);
    ALBEDO = mix(vec3(0.025, 0.48, 0.57), vec3(0.48, 0.88, 0.8), foam * 0.55);
    METALLIC = 0.3;
    ROUGHNESS = 0.23;
}
