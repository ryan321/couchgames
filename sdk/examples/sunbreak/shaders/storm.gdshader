shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float stripe = pow(max(0.0, sin(world.y * 2.0 - TIME * 1.5)), 12.0);
    float pulse = pow(max(0.0, sin(world.x * 0.45 + world.z * 0.6 + TIME)), 14.0);
    ALBEDO = vec3(0.44, 0.25, 1.0) + stripe * 0.25;
    ALPHA = 0.065 + stripe * 0.16 + pulse * 0.08;
}
