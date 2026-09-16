shader_type spatial;
render_mode diffuse_burley;
uniform vec4 grass : source_color = vec4(0.19, 0.34, 0.075, 1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float n = sin(world.x * 1.6 + sin(world.z * 2.8)) * sin(world.z * 1.9) * 0.035;
    float path = 1.0 - smoothstep(2.4, 3.5, min(abs(world.x), abs(world.z)));
    float plaza = 1.0 - smoothstep(7.0, 9.0, length(world.xz));
    float grain = fract(sin(dot(floor(world.xz * 110.0), vec2(12.9898, 78.233))) * 43758.5453) * 0.025;
    ALBEDO = vec3(grain) + mix(grass.rgb + n, vec3(0.49, 0.37, 0.20) + n, max(path, plaza));
    ROUGHNESS = 0.92;
}
